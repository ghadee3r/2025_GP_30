import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; 

// -----------------------------------------------------------------------------
// 1. API Client Setup (The brain for all Calendar interactions)
// -----------------------------------------------------------------------------

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
    final thirtyDaysFromNow = now.add(const Duration(days: 30)).toUtc(); // FIX: Define the end date

    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 20, // Increased results for better schedule visibility
        timeMin: now, // Start time: Now
        timeMax: thirtyDaysFromNow, // FIX: End time: 30 days from now
        singleEvents: true,
        orderBy: 'startTime',
      );
      
      // Filter events to only show those with titles and valid start times
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
  }) async {
    if (calendarApi == null) return null;

    final event = calendar.Event(
      summary: title,
      start: calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
      end: calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC'),
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
// 2. Main Page Widget (HomePage)
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

  // Calendar UI State for table_calendar
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); 

  // Existing Focus State
  String selectedPreset = 'Choose Preset';
  int? selectedModeIndex; // Changed to nullable int for initial unselected state
  
  bool isRikazToolConnected = false; 
  bool isLoading = false; 

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 

    // Attempt silent sign-in to restore previous session on app launch
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

  // FIX 4: Override didChangeAppLifecycleState (Handles external changes, e.g., deleting from Google Calendar app)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isCalendarConnected) {
      // When the app comes back to the foreground, fetch the latest schedule
      debugPrint('App resumed from background, fetching schedule...');
      _fetchSchedule();
    }
  }

  // FIX: This method forces the schedule to refresh every time the tab/route is entered (Handles internal tab switching).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use a flag to prevent fetch on initial load, but ensure it runs on route changes.
    // If we're connected and the route changed, fetch.
    if (_isCalendarConnected) {
      _fetchSchedule();
    }
  }

  // Refreshes the event list from Google Calendar (Two-way sync: Read)
  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) {
      if (mounted) setState(() => _events = []);
      return;
    }
    
    final fetchedEvents = await _client.fetchUpcomingEvents();
    if (mounted) {
        setState(() {
          _events = fetchedEvents;
        });
    }
  }

  // Handles Google Calendar Sign-in
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
  
  // Handles Google Calendar Sign-out
  Future<void> _handleCalendarSignOut() async {
    await _client.signOut();
    setState(() {
      _isCalendarConnected = false;
      _events = [];
    });
    _showSnackbar('Disconnected from Google.', Colors.blueGrey);
  }

  // Placeholder for Rikaz Tool Connect (using SlideAction)
  Future<void> handleConnect() async {
    setState(() => isLoading = true); 
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      isRikazToolConnected = true;
      isLoading = false;
    });
  }

  // Existing session logic
  void handleSetSession() {
    // Only proceed if a mode is selected
    if (selectedModeIndex == null) return;
    
    final selectedTitle = modes[selectedModeIndex!]['title']!;
    final routeName = (selectedTitle == 'Pomodoro Mode') ? '/pomodoro' : '/custom';
    Navigator.of(context).pushNamed(routeName);
  }

  void handlePresetSelect(String preset) {
    setState(() => selectedPreset = preset);
    Navigator.of(context).pop(); 
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
            initialDate: selectedDate, // FIX: Pass the selected date here
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Using fixed colors from the second code block for theme consistency
    const accentBlue = Color(0xFF6E5DE7);
    const lavender = Color.fromARGB(255, 174, 165, 255);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color.fromARGB(148, 197, 201, 253),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage:
                        const AssetImage('assets/images/RikazLogo.png'),
                    backgroundColor: Colors.transparent,
                  )),
                const SizedBox(height: 20),
                const Text(
                  'Welcome back, User!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(221, 29, 29, 29)),
                ),
                const SizedBox(height: 6),
                const Text(
                  ' Ready for a productive day?',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 25),

                // RIKAZ TOOL CONNECT SECTION (Glass)
                _buildGlassSection(_buildRikazConnect(lavender)),
                const SizedBox(height: 20),

                // START FOCUS SESSION SECTION (Glass)
                _buildGlassSection(_buildFocusSection(lavender, accentBlue)),
                const SizedBox(height: 20),

                // ---------------------------------------------------
                // GOOGLE CALENDAR CONNECT SECTION (MOVED TO BOTTOM)
                // ---------------------------------------------------
                _buildGlassSection(_buildGoogleConnectSection(cs)),
                const SizedBox(height: 20),


                // ---------------------------------------------------
                // SCHEDULE SECTION (Calendar View & List)
                // ---------------------------------------------------
                _buildGlassSection(_buildScheduleSection(cs)),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Glass Section Helper
  // ---------------------------------------------------------------------------
  Widget _buildGlassSection(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Sections Implementation
  // ---------------------------------------------------------------------------
  Widget _buildRikazConnect(Color lavender) {
    return isRikazToolConnected
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rikaz Tools Connected',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 80, 80, 80))),
              const SizedBox(height: 8),
              const Text('Custom presets and features unlocked.',
                  style: TextStyle(color: Colors.grey)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Connect Rikaz Tools',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                  'Connect to unlock custom presets and advanced features',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 10),
              SlideAction(
                text: "Slide to Connect",
                textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                innerColor: Colors.white,
                outerColor: lavender,
                sliderButtonIcon:
                    const Icon(Icons.wifi, color: Colors.black, size: 15),
                height: 42,
                onSubmit: () async {
                  await handleConnect();
                  return null;
                },
              ),
            ],
          );
  }

  Widget _buildFocusSection(Color lavender, Color accentBlue) {
    final hasSelectedMode = selectedModeIndex != null; // Use local variable for readability
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Start Focus Session',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        // Preset Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...presets
                      .map((p) => ListTile(
                            title: Text(p),
                            onTap: () => handlePresetSelect(p),
                          ))
                      .toList(),
                  ListTile(
                    title: const Text('Custom Session', style: TextStyle(fontStyle: FontStyle.italic)),
                    onTap: () => handlePresetSelect('Custom Session'),
                  ),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedPreset, style: const TextStyle(fontSize: 16, color: Colors.black)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Mode Selection Cards
        Row(
          children: List.generate(modes.length, (i) {
            final mode = modes[i];
            final selected = selectedModeIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedModeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? lavender : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected ? lavender : Colors.grey.shade300,
                        width: 2),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: lavender.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mode['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: selected ? Colors.white : Colors.black)),
                      const SizedBox(height: 6),
                      Text(mode['desc']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Set Session Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedModeIndex != null ? handleSetSession : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedModeIndex != null ? accentBlue : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Set Session',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: selectedModeIndex != null ? Colors.white : Colors.white.withOpacity(0.7))),
          ),
        ),
      ],
    );
  }

  // Widget for Google Connection Status Card
  Widget _buildGoogleConnectSection(ColorScheme cs) {
    // Determine softer, non-aggressive status colors
    final statusColor = cs.tertiary; // Use soft theme color for connection status
    final statusBackground = cs.tertiaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusBackground.withOpacity(0.5), // Softer background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1.5),
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
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
                Text(
                  _isCalendarConnected 
                    ? 'Sessions are synced successfully!' 
                    : 'Connect to sync your sessions and manage them directly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _isCalendarConnected
              ? ElevatedButton.icon(
                  onPressed: _handleCalendarSignOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade400, // Neutral color for disconnect
                    foregroundColor: Colors.white,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isSigningIn ? null : _handleCalendarSignIn,
                  icon: _isSigningIn ? 
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(_isSigningIn ? 'Connecting...' : 'Connect Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
        ],
      ),
    );
  }

  // New Widget: Schedule Display Section
  Widget _buildScheduleSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NEW HEADER: Calendar
        const Text(
          'Calendar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        // NEW: Small Calendar View (TableCalendar)
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: TableCalendar(
            locale: 'en_US',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary),
            ),
            calendarFormat: CalendarFormat.month, // Month View
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: cs.primary.withOpacity(0.6), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: cs.error),
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
        const SizedBox(height: 20),

        // UPCOMING SESSIONS HEADER
        const Text(
          'Upcoming Sessions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Add Session Button
            TextButton.icon(
              // FIX: Pass the currently selected day to the overlay
              onPressed: () => _showEventOverlay(selectedDate: _selectedDay), 
              icon: Icon(Icons.add_circle, color: cs.primary),
              label: Text('Add Session', style: TextStyle(color: cs.primary)),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        // Events List from Google Calendar
        _events.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    _client.isConnected
                        ? 'No upcoming sessions found.'
                        : 'Connect Google Calendar to see your schedule.',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final startTime = event.start?.dateTime?.toLocal() ?? event.start?.date;
                  final endTime = event.end?.dateTime?.toLocal() ?? event.end?.date;

                  if (startTime == null) return const SizedBox.shrink();

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: cs.surfaceContainerHighest,
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withOpacity(0.8),
                        child: Text(
                          DateFormat('d').format(startTime), 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        event.summary ?? 'Untitled Session',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        // Format for timed vs all-day events
                        endTime != null
                          ? '${DateFormat('MMM d, h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
                          : DateFormat('MMM d, yyyy').format(startTime), // All day event
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        // Opens the management overlay for deletion
                        onPressed: () => _showEventOverlay(eventToEdit: event),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Cute Overlay (Modal Bottom Sheet Widget for Add/Delete)
// -----------------------------------------------------------------------------

class _EventManagementOverlay extends StatefulWidget {
  final CalendarClient client;
  final calendar.Event? eventToEdit;
  final VoidCallback onEventUpdated;
  final DateTime? initialDate; // FIX: New field to receive selected date

  const _EventManagementOverlay({
    super.key,
    required this.client,
    required this.onEventUpdated,
    this.eventToEdit,
    this.initialDate, // FIX: Receive initial date
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
      // FIX: Use the date passed from the calendar, defaulting to today if null.
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
    
    // We start the loading state before the conflict check
    setState(() => _isLoading = true);
    
    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime = _combineDateTime(_startDate, _endTime);
    
    if (endDateTime.isBefore(startDateTime)) {
      _showSnackbar('End time cannot be before start time.', Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    if (isEditing) {
        // Block editing for simplicity and security. User must delete and re-add.
        _showSnackbar('Please use the delete button below to remove this session.', Colors.orange);
        setState(() => _isLoading = false);
        return;
    }
    
    // -----------------------------------------------------
    // CONFLICT CHECK IMPLEMENTATION
    // -----------------------------------------------------
    final hasConflict = await widget.client.checkConflicts(
      startTime: startDateTime, 
      endTime: endDateTime,
    );

    if (hasConflict) {
      // Conflict found, show confirmation dialog and wait for user response
      final confirmOverride = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scheduling Conflict'),
          content: Text(
            'You already have a meeting scheduled between ${DateFormat('h:mm a').format(startDateTime)} and ${DateFormat('h:mm a').format(endDateTime)}.\n\nAre you sure you want to schedule this session anyway?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text('No, Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Yes, Override
              child: const Text('Yes, Continue'),
            ),
          ],
        ),
      );

      // If the user selects No/Cancel, stop the process and stop loading.
      if (confirmOverride != true) {
        setState(() => _isLoading = false);
        return;
      }
    }
    // -----------------------------------------------------
    
    // Proceed to create the event (either because there was no conflict or user confirmed)
    final result = await widget.client.createEvent(
        title: _title,
        startTime: startDateTime,
        endTime: endDateTime,
    );
    
    if (result != null) {
      widget.onEventUpdated(); 
      Navigator.pop(context);
      _showSnackbar('Event added to Google Calendar!', Colors.green);
    } else {
      _showSnackbar('Add failed. Check console for details.', Colors.red);
    }
    
    setState(() => _isLoading = false);
  }
  
  // Handles the Delete action (Two-way sync: Write)
  Future<void> _handleDelete() async {
    if (!isEditing || widget.eventToEdit!.id == null) return;
    
    // -----------------------------------------------------
    // NEW: CONFIRMATION DIALOG FOR DELETE
    // -----------------------------------------------------
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

    // If the user cancels deletion, stop here.
    if (confirmDelete != true) {
      return;
    }
    // -----------------------------------------------------

    setState(() => _isLoading = true);

    final success = await widget.client.deleteEvent(widget.eventToEdit!.id!);
    
    if (success) {
      widget.onEventUpdated(); 
      Navigator.pop(context);
      _showSnackbar('Event deleted from Google Calendar! ', Colors.green);
    } else {
      _showSnackbar('Deletion failed. Check console for details.', Colors.red);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
                const SizedBox(width: 40), // Placeholder for balance
                Text(
                  isEditing ? 'Delete Session' : 'Add New Session',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  textAlign: TextAlign.center,
                ),
                // The explicit "arrow" / close button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            // --- END: HEADER AND CLOSE BUTTON ---

            const Divider(height: 20),
            
            // Title Field
            TextFormField(
              initialValue: isEditing ? _title : null,
              decoration: InputDecoration(
                labelText: 'Session Title',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
                enabled: !isEditing,
              ),
              validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
              onSaved: (value) => _title = value!,
              readOnly: isEditing,
            ),
            const SizedBox(height: 15),

            // Date Picker (Disabled when editing/deleting)
            ListTile(
              title: const Text('Date'),
              trailing: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              leading: const Icon(Icons.calendar_today, color: Color(0xFF6E5DE7)),
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

            // Time Pickers (Disabled when editing/deleting)
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start Time'),
                    trailing: Text(_startTime.format(context)),
                    leading: const Icon(Icons.schedule, color: Color(0xFF4f46e5)),
                    onTap: isEditing ? null : () async {
                      final time = await showTimePicker(context: context, initialTime: _startTime);
                      if (time != null) setState(() => _startTime = time);
                    },
                    enabled: !isEditing,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('End Time'),
                    trailing: Text(_endTime.format(context)),
                    leading: const Icon(Icons.schedule, color: Color(0xFF4f46e5)),
                    onTap: isEditing ? null : () async {
                      final time = await showTimePicker(context: context, initialTime: _endTime);
                      if (time != null) setState(() => _endTime = time);
                    },
                    enabled: !isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: CircularProgressIndicator()))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Add Button (Only visible when NOT editing)
                      if (!isEditing)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleSave,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      
                      // Delete Button (Only visible when editing an existing event)
                      if (isEditing)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleDelete,
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: const Text('Delete Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      
                      if (isEditing) const SizedBox(width: 10),

                      // Cancel/Close Button
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isEditing ? 'Close' : 'Cancel', style: TextStyle(color: Colors.grey.shade600)),
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
