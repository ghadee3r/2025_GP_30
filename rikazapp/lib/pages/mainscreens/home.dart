import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rikazapp/pages/subscreens/SetSession.dart';
// Enum to manage the user's schedule view preference
enum ScheduleView { all, rikaz }

// =============================================================================
// 1. FINAL REFINED THEME DEFINITIONS - Minimalist Soft UI with Cute Pastels
// =============================================================================

// Base Colors
const Color primaryThemePurple = Color(0xFF7A68FF); // Main action color
const Color secondaryThemeBlue = Color(0xFF8DC0FF); // Header end color (soft gradient)
const Color softAccentHighlight = Color(0xFFE9E5FF); // Lightest purple for selections/backgrounds

// Custom Colors based on the HP Image
const Color hpDeepBlue = Color.fromARGB(255, 24, 114, 150); // Exact shade for "Good Evening" and key text
const Color hpThinBlack = Color(0xFF1E1E1E); // Thin black for names

const Color primaryTextDark = Color(0xFF30304D);
const Color secondaryTextGrey = Color(0xFF8C8C99);

// Soft Pastel Accent Colors for diversity
const Color softLavender = Color(0xFFE9E5FF); // Used for Google Connect background
const Color softCyan = Color(0xFFE8F8FF); // Used for Mode Selection backgrounds (light cyan)

const Color primaryBackground = Color(0xFFFFFFFF); // Pure white background
const Color cardBackground = Color(0xFFFFFFFF); // Pure white for card surfaces


const double cardBorderRadius = 24.0; // Highly rounded corners
// Note: globalHorizontalPadding removed from constants, replaced with proportional calculation in build method.
// Subtle shadow for the floating effect (Purple-tinted)
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: const Color.fromARGB(255, 155, 141, 255).withOpacity(0.4),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];


// -----------------------------------------------------------------------------
// 2. API Client Setup (Functionality Unchanged)
// -----------------------------------------------------------------------------
// ... (CalendarClient class is fully preserved - contents omitted for brevity)
const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/calendar',
  'email',
];

class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  calendar.CalendarApi? calendarApi;

  bool get isConnected => calendarApi != null;

  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final authenticatedClient = await _googleSignIn.authenticatedClient();

      if (authenticatedClient != null) {
        calendarApi = calendar.CalendarApi(authenticatedClient);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    calendarApi = null;
  }

  // Checks for conflicting events (Free/Busy API)
  Future<bool> checkConflicts({
    required DateTime startTime,
    required DateTime endTime
  }) async {
    if (calendarApi == null) return false;

    final query = calendar.FreeBusyRequest(
      timeMin: startTime.toUtc(),
      timeMax: endTime.toUtc(),
      items: [
        calendar.FreeBusyRequestItem(id: 'primary'),
      ],
    );

    try {
      final response = await calendarApi!.freebusy.query(query);

      final busyTimes = response.calendars?['primary']?.busy;
      return busyTimes != null && busyTimes.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking calendar conflicts: $e');
      return false;
    }
  }


  // Fetches upcoming events from the user's primary calendar
  Future<List<calendar.Event>> fetchUpcomingEvents() async {
    if (calendarApi == null) return [];

    final now = DateTime.now().toUtc();
    final thirtyDaysFromNow = now.add(const Duration(days: 30)).toUtc();

    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 20,
        timeMin: now,
        timeMax: thirtyDaysFromNow,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items?.where((e) => e.summary != null && e.start != null).toList() ?? [];
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  // Creates a new calendar event (Two-way sync: Write)
  Future<calendar.Event?> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    bool isRikazSession = false,
  }) async {
    if (calendarApi == null) return null;

    final event = calendar.Event(
      summary: title,
      start: calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
      end: calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC'),
      extendedProperties: isRikazSession
          ? calendar.EventExtendedProperties(private: {'isRikazSession': 'true'})
          : null,
    );

    try {
      final createdEvent = await calendarApi!.events.insert(event, 'primary');
      return createdEvent;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return null;
    }
  }

  // Deletes an event by its ID (Two-way sync: Write)
  Future<bool> deleteEvent(String eventId) async {
    if (calendarApi == null) return false;

    try {
      await calendarApi!.events.delete('primary', eventId);
      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }
}


// -----------------------------------------------------------------------------
// 3. Main Page Widget (HomePage)
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Calendar API State and Client
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;
  List<calendar.Event> _events = [];
  List<calendar.Event> _displayedEvents = [];
  ScheduleView _scheduleView = ScheduleView.all;

  // Calendar UI State for table_calendar
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Existing Focus State
  String selectedPreset = 'Choose Preset';
  int? selectedModeIndex;

  // REMOVED: bool isRikazToolConnected = false;
  // REMOVED: bool isLoading = false;

  static const List<String> presets = [
    'Deep Work',
    'Morning Focus',
    'Study Session',
  ];

  final List<Map<String, String>> modes = const [
    {
      'title': 'Pomodoro Mode',
      'desc': 'Structured focus and break sessions',
    },
    {
      'title': 'Custom Mode',
      'desc': 'Set your own duration',
    },
  ];

  // Class-level fields for theme constants
  final Color localPrimaryThemePurple = primaryThemePurple;
  final Color localSecondaryThemeBlue = secondaryThemeBlue;
  final Color localSoftAccentHighlight = softAccentHighlight;
  final Color localPrimaryTextDark = primaryTextDark;
  final Color localSecondaryTextGrey = secondaryTextGrey;
  final Color localPrimaryBackground = primaryBackground;
  final Color localCardBackground = cardBackground;
  final Color localSoftLavender = softLavender;
  final Color localSoftCyan = softCyan;
  final Color localSoftPeach = const Color(0xFFFFEEEA);


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _client.signIn().then((success) {
          if (success) {
            _fetchSchedule();
          }
          setState(() {
            _isCalendarConnected = success;
          });
        });
      }
    });
    _client._googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isCalendarConnected) {
      debugPrint('App resumed from background, fetching schedule...');
      _fetchSchedule();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isCalendarConnected) {
      _fetchSchedule();
    }
  }

  void _filterEvents() {
    if (_scheduleView == ScheduleView.all) {
      _displayedEvents = _events;
    } else {
      _displayedEvents = _events.where((event) {
        return event.extendedProperties?.private?['isRikazSession'] == 'true';
      }).toList();
    }
  }

  void _setScheduleView(ScheduleView view) {
    setState(() {
      _scheduleView = view;
    });
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) {
      if (mounted) setState(() {
        _events = [];
        _displayedEvents = [];
      });
      return;
    }

    final fetchedEvents = await _client.fetchUpcomingEvents();
    if (mounted) {
      setState(() {
        _events = fetchedEvents;
        _filterEvents();
      });
    }
  }

  Future<void> _handleCalendarSignIn() async {
    if (_isCalendarConnected) return;

    setState(() { _isSigningIn = true; });

    final success = await _client.signIn();

    setState(() {
      _isCalendarConnected = success;
      _isSigningIn = false;
    });

    if (success) {
      await _fetchSchedule();
      _showSnackbar('Successfully connected to Google Calendar!', Colors.green);
    } else {
      _showSnackbar('Connection failed or cancelled. Check network.', Colors.red);
    }
  }

  Future<void> _handleCalendarSignOut() async {
    await _client.signOut();
    setState(() {
      _isCalendarConnected = false;
      _events = [];
      _displayedEvents = [];
    });
    _showSnackbar('Disconnected from Google.', Colors.blueGrey);
  }

  // REMOVED: handleConnect method
  // Future<void> handleConnect() async { ... }

// MODIFIED: handleSetSession to pass the selected mode
  void handleSetSession() {
    if (selectedModeIndex == null) return;

    // Determine the selected mode based on the index
    final initialMode = selectedModeIndex == 0 ? SessionMode.pomodoro : SessionMode.custom;

    // Navigate to SetSessionPage and pass the initialMode as an argument
    Navigator.of(context).pushNamed(
      '/SetSession',
      arguments: initialMode, // Pass the SessionMode enum value directly
    );
  }


  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEventOverlay({calendar.Event? eventToEdit, DateTime? selectedDate}) {
    if (!_client.isConnected) {
      _showSnackbar('Please connect to Google Calendar first.', Colors.red);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _EventManagementOverlay(
            client: _client,
            eventToEdit: eventToEdit,
            onEventUpdated: _fetchSchedule,
            initialDate: selectedDate,
          ),
        );
      },
    );
  }

  // NEW HELPER: Adaptive Font Size function
  // Adjusts the proportional font size based on the system's text scale factor to prevent overflow
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Use a compensatory factor: e.g., if scale is 2.0, reduce effective size by (2.0 - 1.0) * a mitigation factor.
    // Use a factor of 0.8 for mitigation, meaning only 80% of the excessive scale is compensated for.
    final mitigationFactor = 0.8;
    
    // The resulting size is reduced relative to the base size by the excessive text scale
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

  // ---------------------------------------------------------------------------
  // THEMED UI SECTIONS (MADE FLEXIBLE)
  // ---------------------------------------------------------------------------

  Widget buildWelcomeHeaderLocal() {
    // Get screen dimensions for proportional sizing
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Good Evening,',
              style: TextStyle(
                // MODIFIED: Use _adaptiveFontSize
                fontSize: _adaptiveFontSize(0.085), // Proportional to screen width
                fontWeight: FontWeight.w700,
                color: hpDeepBlue,
              ),
            ),
          ],
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.005),
        Text(
          'UserName !',
          style: TextStyle(
            // MODIFIED: Use _adaptiveFontSize
            fontSize: _adaptiveFontSize(0.075), // Proportional to screen width
            fontWeight: FontWeight.w400,
            color: hpThinBlack,
          ),
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.01), // slightly smaller gap
        Text(
          'Are you ready for a productive day?',
          style: TextStyle(
            // MODIFIED: Use _adaptiveFontSize
            fontSize: _adaptiveFontSize(0.035),
            fontWeight: FontWeight.w400,
            color: const Color.fromARGB(255, 129, 129, 129),

          ),
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.025),
      ],
    );
  }

  // REMOVED: buildRikazConnectLocal widget

  Widget buildFocusSessionLocal() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasSelectedMode = selectedModeIndex != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Focus Session',
          style: TextStyle(
            // MODIFIED: Use _adaptiveFontSize
            fontSize: _adaptiveFontSize(0.045),
            fontWeight: FontWeight.bold,
            color: localPrimaryTextDark,
          ),
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.02),

        // Mode Selection Cards - Refactored to use Flexible sizing
        Row(
          children: List.generate(modes.length, (i) {
            final mode = modes[i];
            final selected = selectedModeIndex == i;

            final Color modeBgColor = localSoftCyan;
            final Color selectedTextColor = hpDeepBlue;
            final Color defaultTextColor = hpDeepBlue;

            return Expanded( // Ensures cards share horizontal space
              child: GestureDetector(
                onTap: () => setState(() => selectedModeIndex = i),
                child: AnimatedScale(
                  scale: selected ? 1.08 : 1.0, // Slight enlargement when selected
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    // FLEXIBLE MARGIN
                    margin: EdgeInsets.only(
                      right: i == 0 ? screenWidth * 0.03 : 0,
                      left: i == 1 ? screenWidth * 0.03 : 0,
                    ),
                    // REMOVED FIXED HEIGHT TO PREVENT OVERFLOW

                    // FLEXIBLE PADDING
                    padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02, 
                        horizontal: screenWidth * 0.03
                    ),
                    constraints: BoxConstraints(
                        minHeight: screenHeight * 0.12, 
                    ),
                    decoration: BoxDecoration(
                      color: selected ? modeBgColor : localCardBackground,
                      borderRadius:
                      BorderRadius.circular(cardBorderRadius / 2),
                      border: Border.all(color: Colors.transparent, width: 0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 176, 163, 247).withOpacity(0.8),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],

                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // Ensure minimal height usage
                      children: [
                        Text(
                          mode['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            // MODIFIED: Use _adaptiveFontSize
                            fontSize: _adaptiveFontSize(0.04),
                            color: selected
                                ? selectedTextColor
                                : defaultTextColor,
                          ),
                        ),
                        // FLEXIBLE HEIGHT
                        SizedBox(height: screenHeight * 0.008),
                        Text(
                          mode['desc']!,
                          textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis, // Added fallback
                            maxLines: 2, // Added fallback
                          style: TextStyle(
                            // MODIFIED: Use _adaptiveFontSize
                            fontSize: _adaptiveFontSize(0.03),
                            color: selected
                                ? selectedTextColor.withOpacity(0.7)
                                : localSecondaryTextGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ));
          }),
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.03),

        // Set Session Button - unchanged logic, made padding flexible
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedModeIndex != null ? handleSetSession : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelectedMode
                  ? localPrimaryThemePurple
                  : localPrimaryThemePurple.withOpacity(0.5),
              // FLEXIBLE PADDING
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cardBorderRadius / 2),
              ),
              elevation: hasSelectedMode ? 4 : 0,
            ),
            child: Text(
              'Set Session',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                // MODIFIED: Use _adaptiveFontSize
                fontSize: _adaptiveFontSize(0.04),
                color: hasSelectedMode
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildGoogleConnectSectionLocal(ColorScheme cs) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final activeColor = primaryThemePurple;

    final statusColor = _isCalendarConnected ? Colors.green.shade600 : activeColor;
    final statusTextColor = _isCalendarConnected ? Colors.green.shade800 : primaryTextDark;

    // Use softLavender for the background
    final statusBackground = localSoftLavender.withOpacity(0.9);

    return Container(
      // FLEXIBLE PADDING
      padding: EdgeInsets.all(screenWidth * 0.04),
      // FLEXIBLE MARGIN
      margin: EdgeInsets.only(top: screenHeight * 0.02, bottom: screenHeight * 0.025),
      decoration: BoxDecoration(
        color: statusBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: subtleShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCalendarConnected
                      ? 'Google Calendar Sync'
                      : 'Google Calendar Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    // MODIFIED: Use _adaptiveFontSize
                    fontSize: _adaptiveFontSize(0.04),
                    color: statusTextColor,
                  ),
                ),
                Text(
                  _isCalendarConnected
                      ? 'Sessions are synced successfully!'
                      : 'Connect to sync your sessions and manage them directly.',
                  style: TextStyle(
                    // MODIFIED: Use _adaptiveFontSize
                    fontSize: _adaptiveFontSize(0.033),
                    color: localSecondaryTextGrey,
                  ),
                ),
              ],
            ),
          ),
          // FLEXIBLE WIDTH
          SizedBox(width: screenWidth * 0.025),
          _isCalendarConnected
              ? ElevatedButton.icon(
            onPressed: _handleCalendarSignOut,
            // FLEXIBLE ICON SIZE
            icon: Icon(Icons.logout, size: screenWidth * 0.045),
            label: Text('Disconnect', style: TextStyle(fontSize: _adaptiveFontSize(0.03))), // MODIFIED
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade400,
              foregroundColor: Colors.white,
              // FLEXIBLE PADDING
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.015),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius/2)),
            ),
          )
              : ElevatedButton.icon(
            onPressed: _isSigningIn ? null : _handleCalendarSignIn,
            icon: _isSigningIn ?
            SizedBox(width: screenWidth * 0.045, height: screenWidth * 0.045, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.person_add_alt_1, size: screenWidth * 0.045),
            label: Text(_isSigningIn ? 'Connecting...' : 'Connect Google', style: TextStyle(fontSize: _adaptiveFontSize(0.03))), // MODIFIED
            style: ElevatedButton.styleFrom(
              backgroundColor: localPrimaryThemePurple,
              foregroundColor: Colors.white,
              // FLEXIBLE PADDING
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.015),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius/2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildScheduleSectionLocal(ColorScheme cs) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final calendarAccent = localPrimaryThemePurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SCHEDULE SESSIONS SECTION HEADER
        Text(
          'Scheduled Sessions',
          style: TextStyle(
              // MODIFIED: Use _adaptiveFontSize
              fontSize: _adaptiveFontSize(0.055), fontWeight: FontWeight.bold, color: localPrimaryTextDark),
        ),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.025),

        // CALENDAR CONTAINER
        Container(
          // FLEXIBLE MARGIN
          margin: EdgeInsets.only(bottom: screenHeight * 0.025),
          // FLEXIBLE PADDING
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: localCardBackground,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            boxShadow: subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: TextStyle(
                    // MODIFIED: Use _adaptiveFontSize
                    fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: localPrimaryTextDark),
              ),
              // FLEXIBLE HEIGHT
              SizedBox(height: screenHeight * 0.02),
              // Table Calendar Widget
              Container(
                decoration: BoxDecoration(
                  color: localCardBackground,
                  borderRadius: BorderRadius.circular(cardBorderRadius/2),
                  boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)],
                ),
                child: TableCalendar(
                  locale: 'en_US',
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  currentDay: DateTime.now(),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                        // MODIFIED: Use _adaptiveFontSize
                        fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: localPrimaryTextDark),
                  ),
                  calendarFormat: CalendarFormat.month,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: calendarAccent.withOpacity(0.2), shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: calendarAccent, shape: BoxShape.circle),
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(color: Colors.red.shade600),
                  ),
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                ),
              ),
            ],
          ),
        ), // END Calendar Container

        // UPCOMING SESSIONS LIST
        Text(
          'Upcoming Sessions',
          style: TextStyle(
              // MODIFIED: Use _adaptiveFontSize
              fontSize: _adaptiveFontSize(0.045), fontWeight: FontWeight.bold, color: localPrimaryTextDark),
        ),

        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.015),
        _buildScheduleToggle(cs),
        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.02),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _showEventOverlay(selectedDate: _selectedDay),
              icon: Icon(Icons.add_circle, color: calendarAccent),
              label: Text('Add Session', style: TextStyle(color: calendarAccent, fontSize: _adaptiveFontSize(0.035))), // MODIFIED
            ),
          ],
        ),

        // FLEXIBLE HEIGHT
        SizedBox(height: screenHeight * 0.015),

        _displayedEvents.isEmpty
            ? Center(
          child: Padding(
            // FLEXIBLE PADDING
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03),
            child: Text(
              _client.isConnected
                  ? (_scheduleView == ScheduleView.rikaz
                  ? 'No upcoming Rikaz Focus Sessions found.'
                  : 'No upcoming sessions found.')
                  : 'Connect Google Calendar to see your schedule.',
              style: TextStyle(fontStyle: FontStyle.italic, color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.035)), // MODIFIED
            ),
          ),
        )
            : ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _displayedEvents.length,
          itemBuilder: (context, index) {
            final event = _displayedEvents[index];
            final startTime = event.start?.dateTime?.toLocal() ?? event.start?.date;
            final endTime = event.end?.dateTime?.toLocal() ?? event.end?.date;

            if (startTime == null) return const SizedBox.shrink();

            return Padding(
              // FLEXIBLE PADDING
              padding: EdgeInsets.only(bottom: screenHeight * 0.01),
              child: Container(
                // FLEXIBLE PADDING
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
                decoration: BoxDecoration(
                  color: localCardBackground,
                  borderRadius: BorderRadius.circular(cardBorderRadius/2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    // FLEXIBLE SIZE
                    width: screenWidth * 0.1,
                    height: screenWidth * 0.1,
                    decoration: BoxDecoration(
                      color: softLavender.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat('d').format(startTime),
                        style: TextStyle(color: calendarAccent, fontWeight: FontWeight.bold, fontSize: _adaptiveFontSize(0.04)), // MODIFIED
                      ),
                    ),
                  ),
                  title: Text(
                    event.summary ?? 'Untitled Session',
                    style: TextStyle(fontWeight: FontWeight.bold, color: localPrimaryTextDark, fontSize: _adaptiveFontSize(0.04)), // MODIFIED
                  ),
                  subtitle: Text(
                    endTime != null
                        ? '${DateFormat('MMM d, h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
                        : DateFormat('MMM d, yyyy').format(startTime),
                    style: TextStyle(color: localSecondaryTextGrey, fontSize: _adaptiveFontSize(0.03)), // MODIFIED
                  ),
                  trailing: IconButton(
                    // FLEXIBLE ICON SIZE
                    icon: Icon(Icons.delete_forever, color: Colors.red, size: screenWidth * 0.055),
                    onPressed: () => _showEventOverlay(eventToEdit: event),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Schedule Toggle Buttons (Themed)
  Widget _buildScheduleToggle(ColorScheme cs) {
    final screenWidth = MediaQuery.of(context).size.width;
    final activeColor = primaryThemePurple;
    final inactiveColor = secondaryTextGrey;

    Widget _buildButton(ScheduleView view, String text, IconData icon) {
      final isSelected = _scheduleView == view;
      return Expanded(
        child: InkWell(
          onTap: () => _setScheduleView(view),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            // FLEXIBLE MARGIN
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
            // FLEXIBLE PADDING
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : cardBackground.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // FLEXIBLE ICON SIZE
                Icon(icon, size: screenWidth * 0.045, color: isSelected ? Colors.white : inactiveColor),
                // FLEXIBLE WIDTH
                SizedBox(width: screenWidth * 0.02),
                Text(
                  text,
                  style: TextStyle(
                    // MODIFIED: Use _adaptiveFontSize
                    fontSize: _adaptiveFontSize(0.033),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        _buildButton(ScheduleView.all, 'All Calendar', Icons.calendar_month),
        // FLEXIBLE WIDTH
        SizedBox(width: screenWidth * 0.02),
        _buildButton(ScheduleView.rikaz, 'Rikaz Focus', Icons.auto_awesome),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define proportional horizontal padding
    final proportionalHorizontalPadding = screenWidth * 0.1; // roughly 10% of screen width

    return Scaffold(
      extendBody: true,
      // MODIFIED: Added resizeToAvoidBottomInset: false as requested
      resizeToAvoidBottomInset: false, 
      backgroundColor: localPrimaryBackground,
      body: Container(
        decoration: BoxDecoration(
          // Subtle purple glow on the white background
          gradient: LinearGradient(
            colors: [
              localPrimaryBackground,
              localSoftAccentHighlight.withOpacity(0.3),
              localPrimaryBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // APPLIED PROPORTIONAL HORIZONTAL AND TOP MARGINS
            padding: EdgeInsets.only(
                left: proportionalHorizontalPadding,
                right: proportionalHorizontalPadding,
                // FLEXIBLE TOP PADDING
                top: screenHeight * 0.1,
                // FLEXIBLE BOTTOM PADDING
                bottom: screenHeight * 0.025
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 1. WELCOME HEADER
                buildWelcomeHeaderLocal(),
                // FLEXIBLE HEIGHT
                SizedBox(height: screenHeight * 0.03), // Space after greeting

                // 2. RIKAZ TOOL CONNECT SECTION - REMOVED

                // 3. START FOCUS SESSION SECTION
                buildFocusSessionLocal(),
                // FLEXIBLE HEIGHT
                SizedBox(height: screenHeight * 0.025),

                // 4. GOOGLE CALENDAR CONNECT SECTION
                buildGoogleConnectSectionLocal(cs),
                // FLEXIBLE HEIGHT
                SizedBox(height: screenHeight * 0.025),


                // 5. SCHEDULE SESSIONS SECTION
                buildScheduleSectionLocal(cs),

                // FLEXIBLE HEIGHT
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Cute Overlay (Modal Bottom Sheet Widget for Add/Delete) - THEMED AND FLEXIBLE
// -----------------------------------------------------------------------------
// (The _EventManagementOverlay class has its own separate logic for keyboard resizing via Padding and viewInsets, which is unaffected.)

class _EventManagementOverlay extends StatefulWidget {
  final CalendarClient client;
  final calendar.Event? eventToEdit;
  final VoidCallback onEventUpdated;
  final DateTime? initialDate;

  const _EventManagementOverlay({
    required this.client,
    required this.onEventUpdated,
    this.eventToEdit,
    this.initialDate,
  });

  @override
  __EventManagementOverlayState createState() => __EventManagementOverlayState();
}

class __EventManagementOverlayState extends State<_EventManagementOverlay> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;

  bool get isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (isEditing) {
      _title = widget.eventToEdit!.summary ?? 'Untitled Session';
      final start = widget.eventToEdit!.start!.dateTime?.toLocal() ?? now;
      final end = widget.eventToEdit!.end!.dateTime?.toLocal() ?? now.add(const Duration(hours: 1));

      _startDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(end);
    } else {
      final selectedDate = widget.initialDate ?? now;

      _title = '';
      _startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      _startTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
      _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Handles the Add action (Two-way sync: Write)
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime = _combineDateTime(_startDate, _endTime);

    // NEW: Get the start of today for comparison.
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    // -----------------------------------------------------
    // NEW: BLOCKED PAST DATE SCHEDULING VALIDATION
    // -----------------------------------------------------
    // Only perform this check for new events.
    if (!isEditing && startDateTime.isBefore(startOfToday)) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scheduling Error'),
          content: const Text('You cannot schedule a new focus session on a date before today.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => _isLoading = false);
      return;
    }
    // -----------------------------------------------------

    if (endDateTime.isBefore(startDateTime)) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Time Error'),
          content: const Text('The session end time cannot be before the start time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please use the delete button below to remove this session.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    // CONFLICT CHECK IMPLEMENTATION
    final hasConflict = await widget.client.checkConflicts(
      startTime: startDateTime,
      endTime: endDateTime,
    );

    if (hasConflict) {
      final confirmOverride = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scheduling Conflict'),
          content: Text(
              'You already have a meeting scheduled between ${DateFormat('h:mm a').format(startDateTime)} and ${DateFormat('h:mm a').format(endDateTime)}.\n\nAre you sure you want to schedule this session anyway?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Continue'),
            ),
          ],
        ),
      );

      if (confirmOverride != true) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Proceed to create the event
    final result = await widget.client.createEvent(
      title: _title,
      startTime: startDateTime,
      endTime: endDateTime,
      isRikazSession: true,
    );

    if (result != null) {
      widget.onEventUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event added to Google Calendar!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add failed. Check console for details.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  // Handles the Delete action (Two-way sync: Write)
  Future<void> _handleDelete() async {
    if (!isEditing || widget.eventToEdit!.id == null) return;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
            'Are you sure you want to permanently delete the session "${widget.eventToEdit!.summary ?? 'Untitled'}" from your Google Calendar? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await widget.client.deleteEvent(widget.eventToEdit!.id!);

    if (success) {
      widget.onEventUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event deleted from Google Calendar! '),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deletion failed. Check console for details.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // NEW HELPER: Adaptive Font Size function for the overlay
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Apply a compensatory factor. Using a slightly higher mitigation here (0.85)
    // as space is more constrained in a modal.
    final mitigationFactor = 0.85;
    
    // Size = BaseSize / (1.0 + (ScaleFactor - 1.0) * MitigationFactor)
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

  // Custom Themed Input Decoration
  InputDecoration _inputDecoration({required String label, required IconData icon, bool enabled = true}) {
    final accent = primaryThemePurple;
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: enabled ? accent.withOpacity(0.5) : Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      prefixIcon: Icon(icon, color: enabled ? accent : secondaryTextGrey),
      fillColor: enabled ? cardBackground : Colors.grey.shade100,
      filled: true,
      labelStyle: TextStyle(color: enabled ? primaryTextDark : secondaryTextGrey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = primaryThemePurple;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: const BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardBorderRadius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      // FLEXIBLE PADDING
      padding: EdgeInsets.fromLTRB(screenWidth * 0.05, screenHeight * 0.025, screenWidth * 0.05, MediaQuery.of(context).viewInsets.bottom + screenHeight * 0.025),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- START: HEADER AND CLOSE BUTTON ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // FLEXIBLE SPACE
                SizedBox(width: screenWidth * 0.08),
                Text(
                  isEditing ? 'Delete Session' : 'Add New Session',
                  style: TextStyle(
                      // MODIFIED: Use _adaptiveFontSize
                      fontSize: _adaptiveFontSize(0.055), fontWeight: FontWeight.bold, color: primaryTextDark),
                  textAlign: TextAlign.center,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: secondaryTextGrey),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            // --- END: HEADER AND CLOSE BUTTON ---

            // FLEXIBLE HEIGHT DIVIDER
            Divider(height: screenHeight * 0.025, color: Colors.grey),

            // Title Field - uses flexible input decoration
            TextFormField(
              initialValue: isEditing ? _title : null,
              decoration: _inputDecoration(
                label: 'Session Title',
                icon: Icons.title,
                enabled: !isEditing,
              ),
              validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
              onSaved: (value) => _title = value!,
              readOnly: isEditing,
            ),
            // FLEXIBLE HEIGHT
            SizedBox(height: screenHeight * 0.015),

            // Date Picker (Disabled when editing/deleting)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date', style: TextStyle(fontSize: _adaptiveFontSize(0.04))), // MODIFIED
              trailing: Text(DateFormat('MMM dd, yyyy').format(_startDate), style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.04))), // MODIFIED
              leading: Icon(Icons.calendar_today, color: accent),
              onTap: isEditing ? null : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _startDate = date);
              },
              enabled: !isEditing,
            ),
            const Divider(),

            // Time Pickers (Disabled when editing/deleting)
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start Time', style: TextStyle(fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                    trailing: Text(_startTime.format(context), style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                    leading: Icon(Icons.schedule, color: accent),
                    onTap: isEditing ? null : () async {
                      final time = await showTimePicker(context: context, initialTime: _startTime);
                      if (time != null) setState(() => _startTime = time);
                    },
                    enabled: !isEditing,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('End Time', style: TextStyle(fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                    trailing: Text(_endTime.format(context), style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.04))), // MODIFIED
                    leading: Icon(Icons.schedule, color: accent),
                    onTap: isEditing ? null : () async {
                      final time = await showTimePicker(context: context, initialTime: _endTime);
                      if (time != null) setState(() => _endTime = time);
                    },
                    enabled: !isEditing,
                  ),
                ),
              ],
            ),
            // FLEXIBLE HEIGHT
            SizedBox(height: screenHeight * 0.035),

            // Action Buttons
            _isLoading
                ? Center(child: Padding(
                // FLEXIBLE PADDING
                padding: EdgeInsets.all(screenWidth * 0.025),
                child: CircularProgressIndicator(color: accent)))
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Add Button (Only visible when NOT editing)
                if (!isEditing)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text('Add Session', style: TextStyle(fontSize: _adaptiveFontSize(0.038))), // MODIFIED
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        // FLEXIBLE PADDING
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                // Delete Button (Only visible when editing an existing event)
                if (isEditing)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleDelete,
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: Text('Delete Session', style: TextStyle(color: Colors.white, fontSize: _adaptiveFontSize(0.038))), // MODIFIED
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        // FLEXIBLE PADDING
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                if (isEditing) SizedBox(width: screenWidth * 0.025),

                // Cancel/Close Button
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isEditing ? 'Close' : 'Cancel', style: TextStyle(color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.038))), // MODIFIED
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}