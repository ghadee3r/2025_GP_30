import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rikazapp/pages/subscreens/SetSession.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart' as sb; 

// These enums help us keep track of which view mode the user has selected
enum ScheduleView { all, rikaz }
enum CalendarFormatView { list, month }

// =============================================================================
// THEME COLORS - All the colors we use throughout the app
// =============================================================================

// Our main color palette
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

// Primary colors used across the app
const Color primaryThemeColor = dfDeepBlue;      
const Color accentThemeColor = dfTealCyan;      
const Color lightestAccentColor = dfLightSeafoam; 

// Background colors
const Color primaryBackground = Color(0xFFF7F7F7); 
const Color cardBackground = Color(0xFFFFFFFF);  

// Text colors
const Color primaryTextDark = dfNavyIndigo;      
const Color secondaryTextGrey = Color(0xFF6B6B78); 

// Error/alert color
const Color errorIndicatorRed = Color(0xFFE57373); 

// Standard border radius for cards
const double cardBorderRadius = 16.0; 

// Standard shadow for elevated cards
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08), 
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

// Colors we use to mark importance levels in the app
Map<String, Color> importanceColors = {
  'High': const Color(0xFFEA4335),        // Red 
  'Medium': const Color(0xFFFBBC04),      // Yellow
  'Low': const Color(0xFF34A853),         // Green 
  'Default': const Color(0xFF4285F4),     // Blue 
};

// Google Calendar uses numbered color IDs, so we map our importance levels to those
// This ensures the colors in Google Calendar match what we show in the app
Map<String, String> googleColorMap = {
  'High': '11',   // Red in Google Calendar
  'Medium': '5',  // Yellow in Google Calendar (FIXED from '6' which was orange)
  'Low': '10',    // Green in Google Calendar
  'Default': '9', // Blue in Google Calendar
};

// -----------------------------------------------------------------------------
// GOOGLE CALENDAR API CLIENT
// This class handles all communication with Google Calendar
// -----------------------------------------------------------------------------

// We need these permissions to read and write calendar events
const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/calendar',
  'email',
];

class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes); 
  calendar.CalendarApi? calendarApi;

  // Check if we're currently connected to Google Calendar
  bool get isConnected => calendarApi != null;

  // Sign in to Google and get calendar access
  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false; // User cancelled the sign-in

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

  // Sign out and disconnect from Google Calendar
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    calendarApi = null;
  }

  // Fetch all events from Google Calendar for the next 30 days
  Future<List<calendar.Event>> fetchUpcomingEvents() async {
    if (calendarApi == null) return []; 

    final now = DateTime.now().toUtc();
    final thirtyDaysFromNow = now.add(const Duration(days: 30)).toUtc(); 

    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 250, 
        timeMin: now,
        timeMax: thirtyDaysFromNow, 
        singleEvents: true,
        orderBy: 'startTime',
      );

      // Only return events that have a title and start time
      return events.items?.where((e) => e.summary != null && e.start != null).toList() ?? [];
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  // Update an existing event in Google Calendar
  Future<calendar.Event?> updateEvent({
    required calendar.Event originalEvent,
    required DateTime startTime,
    required DateTime endTime,
    required String title,
  }) async {
    if (calendarApi == null || originalEvent.id == null) return null;

    // Create a copy of the event with updated information
    final updatedEvent = calendar.Event.fromJson(originalEvent.toJson());
    
    updatedEvent.summary = title;
    updatedEvent.start = calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC');
    updatedEvent.end = calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC');

    try {
      final result = await calendarApi!.events.update(
        updatedEvent, 
        'primary', 
        originalEvent.id!,
      );
      return result;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return null;
    }
  }

  // Create one or more events in Google Calendar
  // Can handle single events, multiple individual events, or recurring events
  Future<List<calendar.Event?>> createEvents({
    required String title,
    required List<DateTime> startTimes,
    required Duration duration,
    String? recurrenceRule,
    DateTime? recurrenceUntil, 
    required String importanceKey, 
    bool isRikazSession = false,
  }) async {
    if (calendarApi == null) return List.generate(startTimes.length, (index) => null);

    List<calendar.Event?> createdEvents = [];
    
    // Get the correct Google Calendar color ID for this importance level
    final googleColorId = googleColorMap[importanceKey] ?? googleColorMap['Default']!;

    // If user wants a recurring event (daily, weekly, monthly)
    if (recurrenceRule != null && startTimes.isNotEmpty) {
      final startTime = startTimes.first;
      final endTime = startTime.add(duration);
      
      // Build the recurrence rule with an end date if provided
      String rrule = recurrenceRule;
      if (recurrenceUntil != null) {
          final untilUtc = recurrenceUntil.toUtc();
          rrule += ';UNTIL=${DateFormat('yyyyMMdd').format(untilUtc)}T${DateFormat('HHmmss').format(untilUtc)}Z';
      }

      final event = calendar.Event(
        summary: title,
        start: calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
        end: calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC'),
        recurrence: [rrule],
        colorId: googleColorId,
        extendedProperties: calendar.EventExtendedProperties(
            private: {
              'isRikazSession': isRikazSession.toString(),
              'importance': importanceKey, 
            }
        ),
      );
      try {
        final createdEvent = await calendarApi!.events.insert(event, 'primary');
        createdEvents.add(createdEvent);
      } catch (e) {
        debugPrint('Error creating recurring event: $e');
      }
      return createdEvents;
    }

    // If user wants multiple individual sessions (not recurring)
    for (var startTime in startTimes) {
      final endTime = startTime.add(duration);
      final event = calendar.Event(
        summary: title,
        start: calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
        end: calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC'),
        colorId: googleColorId,
        extendedProperties: calendar.EventExtendedProperties(
            private: {
              'isRikazSession': isRikazSession.toString(),
              'importance': importanceKey, 
            }
        ),
      );
      try {
        final createdEvent = await calendarApi!.events.insert(event, 'primary');
        createdEvents.add(createdEvent);
      } catch (e) {
        debugPrint('Error creating event for date ${DateFormat('yyyy-MM-dd').format(startTime)}: $e');
        createdEvents.add(null);
      }
    }
    return createdEvents;
  }

  // Delete an event from Google Calendar
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
// MAIN HOME PAGE
// This is the main screen users see when they open the app
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  
  // Our Google Calendar API client
  final CalendarClient _client = CalendarClient();
  
  // Connection and loading states
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;
  
  // Event lists
  List<calendar.Event> _events = [];  // All events from Google Calendar
  List<calendar.Event> _displayedEvents = [];  // Events after filtering
  
  // View preferences
  ScheduleView _scheduleView = ScheduleView.all;
  CalendarFormatView _calendarFormatView = CalendarFormatView.list; 

  // User information
  final supabase = sb.Supabase.instance.client; 
  String _userName = 'User Name'; 

  // Calendar navigation
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); 

  // Focus session mode selection
  int? selectedModeIndex;
  
  // Bulk deletion
  Set<String> _selectedEventsToDelete = {}; 
  bool _isBulkDeleting = false; 

  // Available focus modes
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
    // Listen for app lifecycle changes (like coming back from background)
    WidgetsBinding.instance.addObserver(this);
    
    // Get the user's name from Supabase
    _fetchUserName(); 

    // Listen for changes in Google sign-in status
    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      final wasConnected = _isCalendarConnected;
      if (account != null) {
        // User just signed in
        _client.signIn().then((success) {
          if (success) {
            _fetchSchedule();
          }
          setState(() {
            _isCalendarConnected = success;
          });
        });
      } else if (wasConnected) {
        // User just signed out
         setState(() {
            _isCalendarConnected = false;
            _events = [];
            _displayedEvents = [];
            _selectedEventsToDelete.clear();
          });
          _filterEvents(); 
      }
    });
    
    // Try to sign in silently if user was previously signed in
    _client._googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user comes back to the app, refresh the calendar
    if (state == AppLifecycleState.resumed && _client.isConnected) { 
      debugPrint('App resumed from background, fetching schedule...');
      _fetchSchedule();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch schedule when dependencies change
    if (_client.isConnected) { 
      _fetchSchedule();
    }
  }
  
  // Get the user's name from Supabase
  Future<void> _fetchUserName() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      String fetchedName = 'User';
      
      // Try to get full name from metadata
      final metadataName = metadata?['full_name'] as String?;
      if (metadataName != null && metadataName.isNotEmpty) {
          fetchedName = metadataName;
      } else {
        // Fallback to email username
        fetchedName = user.email?.split('@')[0] ?? 'User';
      }
      
      // Capitalize first letter of each word
      final formattedName = fetchedName.split(' ').map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');

      if (mounted) {
        setState(() {
          _userName = formattedName;
        });
      }
    } else {
        if (mounted) setState(() => _userName = 'Guest');
    }
  }


  // Filter events based on current view settings (All vs Rikaz only)
  void _filterEvents() {
    List<calendar.Event> sourceEvents;
    
    if (_isCalendarConnected) {
      sourceEvents = _events.toList(); 
    } else {
      sourceEvents = [];
    }
    
    // Remove events that already happened
    sourceEvents = sourceEvents.where((e) => e.start?.dateTime?.toLocal()?.isAfter(DateTime.now().subtract(const Duration(minutes: 1))) ?? false).toList();

    // Apply the All vs Rikaz filter
    if (_scheduleView == ScheduleView.all) {
      _displayedEvents = sourceEvents;
    } else {
      // Only show sessions created in Rikaz app
      _displayedEvents = sourceEvents.where((event) {
        return event.extendedProperties?.private?['isRikazSession'] == 'true';
      }).toList();
    }
    
    // Sort events by time (earliest first)
    _displayedEvents.sort((a, b) {
      final timeA = a.start?.dateTime?.toLocal() ?? a.start?.date;
      final timeB = b.start?.dateTime?.toLocal() ?? b.start?.date;
      if (timeA == null || timeB == null) return 0;
      return timeA.compareTo(timeB);
    });
  }

  // Toggle selection of an event for bulk deletion
  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedEventsToDelete.contains(eventId)) {
        _selectedEventsToDelete.remove(eventId);
      } else {
        _selectedEventsToDelete.add(eventId);
      }
    });
  }
  
  // Delete all selected events
  Future<void> _handleBulkDelete() async {
    if (_selectedEventsToDelete.isEmpty || !_client.isConnected) return;

    final count = _selectedEventsToDelete.length;

    // Ask user to confirm deletion
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Delete Selected Sessions?',
        content: 'You are about to permanently delete $count session${count > 1 ? 's' : ''} from your Google Calendar. This action cannot be undone.',
        cancelText: 'Cancel',
        confirmText: 'Delete $count Session${count > 1 ? 's' : ''}',
        isDestructive: true,
      ),
    );

    if (confirmDelete == true) {
      setState(() {
        _isBulkDeleting = true;
      });

      // Delete each selected event
      int successfulDeletes = 0;
      for (var id in _selectedEventsToDelete) {
        final success = await _client.deleteEvent(id);
        if (success) {
          successfulDeletes++;
        }
      }
      
      // Clear selection and refresh
      _selectedEventsToDelete.clear();
      await _fetchSchedule();

      if (mounted) {
        setState(() {
          _isBulkDeleting = false;
        });
        _showSnackbar('$successfulDeletes of $count sessions deleted.', Colors.green);
      }
    }
  }


  // Change between All Sessions and Rikaz Focus views
  void _setScheduleView(ScheduleView view) {
    setState(() {
      _scheduleView = view;
      _filterEvents(); 
      _selectedEventsToDelete.clear(); 
    });
  }
  
  // Change between List and Month calendar views
  void _setCalendarFormatView(CalendarFormatView view) {
    setState(() {
      _calendarFormatView = view;
      if (view == CalendarFormatView.list) {
        _filterEvents();
      }
      _selectedEventsToDelete.clear(); 
    });
  }

  // Fetch all events from Google Calendar
  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) { 
      if (mounted) {
        setState(() {
        _events = [];
        _filterEvents();
      });
      }
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

  // Handle Google Calendar sign-in
  Future<void> _handleCalendarSignIn() async {
    if (_isCalendarConnected) return;

    setState(() { _isSigningIn = true; });

    final success = await _client.signIn();
    
    if (!mounted) return; 

    setState(() {
      _isCalendarConnected = success;
      _isSigningIn = false;
    });

    if (success) {
      await _fetchSchedule();
      if (mounted) {
        _showSnackbar('Successfully connected to Google Calendar!', Colors.green);
      }
    } else {
      if (mounted) {
        _showSnackbar('Connection failed or cancelled. Check permissions.', errorIndicatorRed);
      }
    }
  }

  // Handle Google Calendar sign-out
  Future<void> _handleCalendarSignOut() async {
    await _client.signOut();
    setState(() {
      _isCalendarConnected = false;
      _events = [];
      _displayedEvents = [];
      _selectedEventsToDelete.clear();
    });
    _showSnackbar('Disconnected from Google.', primaryThemeColor);
    _filterEvents();
  }

  // Navigate to the Set Session screen
  void handleSetSession() {
    if (selectedModeIndex == null) return;

    final initialMode = selectedModeIndex == 0 ? SessionMode.pomodoro : SessionMode.custom;

    Navigator.of(context).pushNamed(
      '/SetSession',
      arguments: initialMode, 
    );
  }


  // Show a snackbar message at the bottom of the screen
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

  // Handle when user taps a day in the month view
  void _onMonthDayTapped(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
    _showEventOverlay(selectedDate: day);
  }

  // Show the add/edit session overlay
  void _showEventOverlay({calendar.Event? eventToEdit, DateTime? selectedDate}) {
    // FIXED: Alert user if not connected instead of saying "stored locally"
    if (!_client.isConnected && eventToEdit == null) { 
        _showSnackbar('Please connect to Google Calendar first to add sessions.', errorIndicatorRed);
      return;
    }
    
    if (_client.isConnected || eventToEdit != null) { 
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
                onEventUpdated: () {
                  _fetchSchedule(); 
                },
                initialDate: selectedDate,
              ),
            );
          },
        );
    }
  }
  
  // Calculate font size that adapts to screen size and user's text scaling
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Reduce the effect of extreme text scaling
    final mitigationFactor = 0.9; 
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }
  
  // Get the color to display for an event based on its importance
  Color _getEventColor(calendar.Event event) {
    final importanceKey = event.extendedProperties?.private?['importance'];
    return importanceColors[importanceKey] ?? importanceColors['Default']!;
  }
  
  // Get all the importance colors for events on a specific day (for month view markers)
  List<Color> _getEventColorsForDay(DateTime day) {
    if (!_isCalendarConnected) return []; 
    
    final eventsOnDay = _events.where((event) {
      final start = event.start?.dateTime?.toLocal() ?? event.start?.date;
      return start != null && isSameDay(day, start);
    }).toList();
    
    // Get unique importance levels for this day
    final uniqueImportanceKeys = eventsOnDay
        .map((e) => e.extendedProperties?.private?['importance'] ?? 'Default')
        .toSet();

    return uniqueImportanceKeys
        .map((key) => importanceColors[key] ?? importanceColors['Default']!)
        .toList();
  }
  
  // Build the info note that explains what the current view shows
  Widget _buildSessionInfoNote(double screenWidth) {
      String message;

      if (_isCalendarConnected) {
          if (_scheduleView == ScheduleView.all) {
              message = "All Sessions: Displays every event from Google Calendar and the Rikaz App.";
          } else {
              message = "Rikaz Focus: Only shows sessions explicitly created in the Rikaz App.";
          }
      } else {
           if (_scheduleView == ScheduleView.all) {
              message = "All Sessions: Shows only sessions created in the Rikaz App (Connect Google to see more).";
          } else {
              message = "Rikaz Focus: Shows sessions created in the Rikaz App (Pure local mode).";
          }
      }

      return Padding(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
          child: Text(
              message,
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.027),
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w500,
              ),
          ),
      );
  }

  // Build a themed dialog with consistent styling
  Widget _buildThemedDialog({
    required String title,
    required String content,
    required String cancelText,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.045),
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Text(
              content,
              style: TextStyle(
                fontSize: _adaptiveFontSize(0.035),
                color: secondaryTextGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryTextGrey,
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.015,
                    ),
                  ),
                  child: Text(cancelText, style: TextStyle(fontSize: _adaptiveFontSize(0.035))),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? errorIndicatorRed : primaryThemeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.015,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(confirmText, style: TextStyle(fontSize: _adaptiveFontSize(0.035))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // UI BUILDING METHODS
  // ---------------------------------------------------------------------------

  // Build the focus session panel at the top of the screen
  Widget buildFocusSessionPanel() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasSelectedMode = selectedModeIndex != null;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer, color: primaryThemeColor, size: _adaptiveFontSize(0.055)),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Start Focus Session',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045),
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Text(
            'Select a mode to begin your productive session',
            style: TextStyle(
              fontSize: _adaptiveFontSize(0.032),
              color: secondaryTextGrey,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          // Mode selection cards
          Column(
            children: List.generate(modes.length, (i) {
              final mode = modes[i];
              final selected = selectedModeIndex == i;

              return GestureDetector(
                onTap: () => setState(() => selectedModeIndex = i),
                child: Container(
                  margin: EdgeInsets.only(bottom: screenHeight * 0.015),
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: selected ? primaryThemeColor.withOpacity(0.1) : primaryBackground,
                    borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                    border: Border.all(
                      color: selected ? primaryThemeColor : secondaryTextGrey.withOpacity(0.3),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Radio indicator
                      Container(
                        width: screenWidth * 0.06,
                        height: screenWidth * 0.06,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? primaryThemeColor : secondaryTextGrey,
                            width: 2,
                          ),
                          color: selected ? primaryThemeColor : Colors.transparent,
                        ),
                        child: selected
                            ? Icon(Icons.check, color: Colors.white, size: screenWidth * 0.04)
                            : null,
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      // Icon
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.025),
                        decoration: BoxDecoration(
                          color: selected ? primaryThemeColor : accentThemeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          i == 0 ? Icons.access_time : Icons.tune,
                          color: selected ? Colors.white : accentThemeColor,
                          size: _adaptiveFontSize(0.055),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.04),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode['title']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _adaptiveFontSize(0.04),
                                color: primaryTextDark,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              mode['desc']!,
                              style: TextStyle(
                                fontSize: _adaptiveFontSize(0.03),
                                color: secondaryTextGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          SizedBox(height: screenHeight * 0.01),

          // Set Session Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedModeIndex != null ? handleSetSession : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedMode ? primaryThemeColor : primaryThemeColor.withOpacity(0.5),
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                ),
                elevation: hasSelectedMode ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'Set Session',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _adaptiveFontSize(0.04),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the schedule container (calendar/list view)
  Widget buildScheduleContainer() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.event_note, color: primaryThemeColor, size: _adaptiveFontSize(0.055)),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'My Schedule',
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.045),
                  fontWeight: FontWeight.bold,
                  color: primaryTextDark,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),

          // View toggle buttons
          _buildViewToggle(),
          SizedBox(height: screenHeight * 0.02),

          // Google connection status
          _buildGoogleConnectPanel(screenWidth),
          SizedBox(height: screenHeight * 0.02),

          // Show either month view or list view
          if (_calendarFormatView == CalendarFormatView.month)
            _buildMonthCalendarView(screenHeight, screenWidth)
          else 
            _buildListView(screenHeight, screenWidth),
        ],
      ),
    );
  }

  // Build the toggle between List and Month views
  Widget _buildViewToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final activeColor = primaryThemeColor;

    Widget button({required CalendarFormatView view, required String label}) {
      final isSelected = _calendarFormatView == view;
      return Expanded(
        child: ElevatedButton(
          onPressed: () => _setCalendarFormatView(view),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? activeColor : primaryBackground,
            foregroundColor: isSelected ? Colors.white : primaryTextDark,
            elevation: isSelected ? 3 : 0,
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardBorderRadius / 2),
              side: BorderSide(color: isSelected ? activeColor : secondaryTextGrey.withOpacity(0.3), width: 1),
            ),
          ),
          child: Text(label, style: TextStyle(
            fontSize: _adaptiveFontSize(0.035), 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
          )),
        ),
      );
    }

    return Row(
      children: [
        button(view: CalendarFormatView.list, label: 'List'),
        SizedBox(width: screenWidth * 0.02),
        button(view: CalendarFormatView.month, label: 'Month'),
      ],
    );
  }

  // Build the month calendar view
  Widget _buildMonthCalendarView(double screenHeight, double screenWidth) {
    final calendarAccent = accentThemeColor;

    if (!_isCalendarConnected) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
        child: Center(
          child: Text(
            'Connect Google Calendar to see priority color markers on a full Month View.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: secondaryTextGrey),
          ),
        ),
      );
    }

    return Column(
      children: [
        TableCalendar(
          locale: 'en_US',
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          currentDay: DateTime.now(),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
          ),
          calendarFormat: CalendarFormat.month,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: calendarAccent.withOpacity(0.3), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle),
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: errorIndicatorRed),
          ),
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            _onMonthDayTapped(selectedDay);
          },
          eventLoader: _getEventColorsForDay,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, colors) {
              if (colors.isEmpty) return const SizedBox.shrink();
              
              return Positioned(
                bottom: screenHeight * 0.005,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    colors.length, 
                    (index) => Container(
                      width: screenWidth * 0.015,
                      height: screenWidth * 0.015,
                      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.005),
                      decoration: BoxDecoration(
                        color: colors[index] as Color, 
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Build the list view of upcoming sessions
  Widget _buildListView(double screenHeight, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal date selector
        _DateRibbon(
          selectedDay: _selectedDay,
          onDaySelected: (day) {
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
            });
          },
        ),
        SizedBox(height: screenHeight * 0.015),

        // Section header
        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: secondaryTextGrey.withOpacity(0.2), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text( 
                'Upcoming Sessions',
                style: TextStyle(fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),

        // Filter toggle (All vs Rikaz)
        _buildScheduleToggle(screenWidth),
        SizedBox(height: screenHeight * 0.015),
        
        // Info note about current view
        _buildSessionInfoNote(screenWidth),
        SizedBox(height: screenHeight * 0.015),
        
        // Help text for selection
        if (_isCalendarConnected && _selectedEventsToDelete.isEmpty)
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: lightestAccentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentThemeColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: accentThemeColor, size: _adaptiveFontSize(0.04)),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    'Tap any session to select it for deletion. Tap the three-dot menu to edit or delete individual sessions.',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.028),
                      color: primaryTextDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        if (_isCalendarConnected && _selectedEventsToDelete.isEmpty)
          SizedBox(height: screenHeight * 0.015),
        
        // Action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bulk delete button (only show when items are selected)
            if (_isCalendarConnected && _selectedEventsToDelete.isNotEmpty)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBulkDeleting ? null : _handleBulkDelete,
                  icon: _isBulkDeleting
                      ? SizedBox(
                          width: screenWidth * 0.04,
                          height: screenWidth * 0.04,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.delete_forever, color: Colors.white),
                  label: Text(
                    _isBulkDeleting ? 'Deleting...' : 'Delete (${_selectedEventsToDelete.length})', 
                    style: TextStyle(color: Colors.white, fontSize: _adaptiveFontSize(0.032))
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorIndicatorRed,
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                  ),
                ),
              ),
            
            if (_isCalendarConnected && _selectedEventsToDelete.isNotEmpty)
              SizedBox(width: screenWidth * 0.02),

            // Add session button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showEventOverlay(selectedDate: _selectedDay),
                icon: Icon(Icons.add_circle, color: Colors.white),
                label: Text('Add Session', style: TextStyle(color: Colors.white, fontSize: _adaptiveFontSize(0.032))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryThemeColor,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),

        // List of sessions
        _displayedEvents.isEmpty
            ? Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03),
            child: Text(
              'No upcoming sessions found in the selected view.',
              style: TextStyle(fontStyle: FontStyle.italic, color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.032)),
            ),
          ),
        )
            : ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _displayedEvents.length,
          itemBuilder: (context, index) {
            final event = _displayedEvents[index];
            final eventId = event.id;
            final eventColor = _getEventColor(event); 
            final startTime = event.start?.dateTime?.toLocal() ?? event.start?.date;
            final endTime = event.end?.dateTime?.toLocal() ?? event.end?.date;
            
            final isSelected = eventId != null && _selectedEventsToDelete.contains(eventId);
            final canSelect = _isCalendarConnected && eventId != null;

            if (startTime == null) return const SizedBox.shrink();

            return _buildSessionCard(
              event: event,
              color: eventColor,
              startTime: startTime,
              endTime: endTime,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              isSelected: isSelected,
              onTap: canSelect 
                  ? () => _toggleEventSelection(eventId)
                  : null, 
            );
          },
        ),
      ],
    );
  }
  
  // Build a single session card
  Widget _buildSessionCard({
    required calendar.Event event,
    required Color color,
    required DateTime startTime,
    DateTime? endTime,
    required double screenWidth,
    required double screenHeight,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.01),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : cardBackground,
            borderRadius: BorderRadius.circular(cardBorderRadius/2),
            border: isSelected ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Selection indicator or color strip
              if (isSelected) 
                Padding(
                  padding: EdgeInsets.only(left: screenWidth * 0.02),
                  child: Icon(Icons.check_circle, color: color, size: screenWidth * 0.05),
                )
              else 
                Container(
                  width: screenWidth * 0.02,
                  height: screenHeight * 0.08, 
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(cardBorderRadius/2)),
                  ),
                ),
              
              // Session details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.summary ?? 'Untitled Session',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark, fontSize: _adaptiveFontSize(0.036)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        endTime != null
                            ? '${DateFormat('MMM d, h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
                            : DateFormat('MMM d, yyyy').format(startTime),
                        style: TextStyle(color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.028)),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Three-dot menu
              if (!isSelected && _isCalendarConnected && event.id != null) 
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: secondaryTextGrey, size: screenWidth * 0.055),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEventOverlay(eventToEdit: event);
                    } else if (value == 'delete') {
                      final confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => _buildThemedDialog(
                          title: 'Delete This Session?',
                          content: 'Are you sure you want to permanently delete "${event.summary ?? 'Untitled'}"? This action cannot be undone.',
                          cancelText: 'Cancel',
                          confirmText: 'Delete Session',
                          isDestructive: true,
                        ),
                      );
                      
                      if (confirmDelete == true && event.id != null) {
                        final success = await _client.deleteEvent(event.id!);
                        if (success) {
                          _fetchSchedule();
                          _showSnackbar('Session deleted successfully!', Colors.green);
                        } else {
                          _showSnackbar('Failed to delete session.', errorIndicatorRed);
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              else if (!isSelected)
                 Icon(Icons.lock, color: secondaryTextGrey.withOpacity(0.5), size: screenWidth * 0.055),
            ],
          ),
        ),
      ),
    );
  }

  // Build the toggle between All Sessions and Rikaz Focus
  Widget _buildScheduleToggle(double screenWidth) {
    final activeColor = primaryThemeColor;
    final inactiveColor = secondaryTextGrey;

    Widget buildButton(ScheduleView view, String text) {
      final isSelected = _scheduleView == view;
      return Expanded(
        child: InkWell(
          onTap: () => _setScheduleView(view),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
            padding: EdgeInsets.symmetric(vertical: screenWidth * 0.015),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? activeColor : secondaryTextGrey.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: _adaptiveFontSize(0.03),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : inactiveColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildButton(ScheduleView.all, 'All Sessions'),
        buildButton(ScheduleView.rikaz, 'Rikaz Focus'),
      ],
    );
  }
  
  // Build the Google Calendar connection panel
  Widget _buildGoogleConnectPanel(double screenWidth) {
    final statusColor = _isCalendarConnected ? accentThemeColor : errorIndicatorRed;
    final statusText = _isCalendarConnected ? 'Google Calendar Connected' : 'Google Calendar Disconnected';
    final actionText = _isCalendarConnected ? 'Disconnect' : 'Connect';
    final actionIcon = _isCalendarConnected ? Icons.logout : Icons.person_add_alt_1;

    return Padding(
      padding: EdgeInsets.only(bottom: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( 
            child: Row(
              children: [
                  Icon(
                      _isCalendarConnected ? Icons.cloud_done : Icons.cloud_off, 
                      color: statusColor,
                      size: screenWidth * 0.045,
                  ),
                  SizedBox(width: screenWidth * 0.01),
                  Expanded(
                    child: Text(
                        statusText,
                        style: TextStyle(
                            fontSize: _adaptiveFontSize(0.033),
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          
          TextButton.icon(
              onPressed: _isSigningIn ? null : (_isCalendarConnected ? _handleCalendarSignOut : _handleCalendarSignIn),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01, vertical: 0),
                  foregroundColor: primaryThemeColor,
              ),
              icon: _isSigningIn 
                  ? SizedBox(
                      width: screenWidth * 0.04, 
                      height: screenWidth * 0.04, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryThemeColor)
                    )
                  : Icon(
                      actionIcon,
                      size: screenWidth * 0.04,
                      color: primaryThemeColor,
                    ),
              label: Text(
                  actionText,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.033),
                      fontWeight: FontWeight.bold,
                      color: primaryThemeColor,
                  ),
              ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final proportionalHorizontalPadding = screenWidth * 0.05; 

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false, 
      backgroundColor: primaryBackground,
      
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
              left: proportionalHorizontalPadding,
              right: proportionalHorizontalPadding,
              top: screenHeight * 0.02,
              bottom: screenHeight * 0.05
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Evening,',
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.035), 
                      fontWeight: FontWeight.w500,
                      color: secondaryTextGrey,
                    ),
                  ),
                  Text(
                    '$_userName !', 
                    style: TextStyle(
                      fontSize: _adaptiveFontSize(0.05), 
                      fontWeight: FontWeight.w800,
                      color: primaryTextDark,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
              
              // Focus session panel
              buildFocusSessionPanel(),
              
              // Schedule container
              buildScheduleContainer(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DATE RIBBON - Horizontal scrolling date selector
// =============================================================================

class _DateRibbon extends StatelessWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _DateRibbon({
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final today = DateTime.now();
    final startDay = today.subtract(const Duration(days: 3));
    final endDay = today.add(const Duration(days: 10));

    return SizedBox(
      height: screenWidth * 0.2,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: endDay.difference(startDay).inDays,
        itemBuilder: (context, index) {
          final day = startDay.add(Duration(days: index));
          final isSelected = isSameDay(selectedDay, day);
          final isToday = isSameDay(today, day);
          
          return GestureDetector(
            onTap: () => onDaySelected(day),
            child: Container(
              width: screenWidth * 0.14,
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryThemeColor 
                    : isToday 
                        ? lightestAccentColor.withOpacity(0.5) 
                        : cardBackground,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected ? subtleShadow : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : primaryTextDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(day),
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : primaryTextDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// EVENT MANAGEMENT OVERLAY - Add or edit sessions
// -----------------------------------------------------------------------------

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
  
  String _selectedImportance = 'Default'; 
  
  String? _selectedRecurrence; 
  List<DateTime> _selectedDates = []; 
  
  DateTime? _recurrenceEndDate; 

  // Check if we're editing an existing event
  bool get isEditing => widget.eventToEdit != null;
  
  // Check which mode we're in for creating events
  bool get isRecurringMode => _selectedRecurrence != null && !isEditing;
  bool get isMultiDateMode => _selectedRecurrence == null && !isEditing;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (isEditing) {
      // Pre-fill form with existing event data
      _title = widget.eventToEdit!.summary ?? 'Untitled Session';
      final start = widget.eventToEdit!.start!.dateTime?.toLocal() ?? now;
      final end = widget.eventToEdit!.end!.dateTime?.toLocal() ?? now.add(const Duration(hours: 1));

      _startDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(end);
      
      _selectedImportance = widget.eventToEdit!.extendedProperties?.private?['importance'] ?? 'Default';
      
      _selectedRecurrence = null;
      _selectedDates = [_startDate];
    } else {
      // Set up form for new event
      final selectedDate = widget.initialDate ?? now;

      _title = '';
      _startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      _startTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
      _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
      _selectedDates = [_startDate];
      _recurrenceEndDate = _startDate.add(const Duration(days: 7));
    }
  }

  // Combine a date and time into a single DateTime
  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // Handle saving the session
  Future<void> _handleSave() async {
    // Hide keyboard
    FocusScope.of(context).unfocus(); 
    
    // Validate form
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime = _combineDateTime(_startDate, _endTime);
    final duration = endDateTime.difference(startDateTime);

    // Check if end time is before start time
    if (duration.isNegative) {
      _showErrorDialog('Time Error', 'The session end time cannot be before the start time.');
      setState(() => _isLoading = false);
      return;
    }
    
    // Check if start and end times are the same
    if (duration.inMinutes == 0) {
      _showErrorDialog('Time Error', 'Start and end times cannot be identical. Please set a valid duration.');
      setState(() => _isLoading = false);
      return;
    }
    
    // FIXED: Check if user is trying to edit an event to a past date
    if (isEditing && startDateTime.isBefore(DateTime.now())) {
      _showErrorDialog('Date Error', 'Cannot schedule sessions in the past. Please select a future date and time.');
      setState(() => _isLoading = false);
      return;
    }
    
    // Check if user is trying to create a new event in the past
    if (!isEditing && startDateTime.isBefore(DateTime.now())) {
      _showErrorDialog('Date Error', 'Cannot add sessions in the past. Please select a future date and time.');
      setState(() => _isLoading = false);
      return;
    }
    
    // Check if recurrence end date is before start date
    if (isRecurringMode && _recurrenceEndDate != null && _recurrenceEndDate!.isBefore(_startDate)) {
         _showErrorDialog('Frequency Error', 'The recurrence end date must be on or after the start date.');
         setState(() => _isLoading = false);
         return;
    }

    if (isEditing) {
      // Update existing event
      final updatedEvent = await widget.client.updateEvent(
        originalEvent: widget.eventToEdit!,
        title: _title,
        startTime: startDateTime,
        endTime: endDateTime,
      );

      if (updatedEvent != null) {
        widget.onEventUpdated();
        Navigator.pop(context);
        _showSnackbar('Session updated successfully!', Colors.green);
      } else {
        _showSnackbar('Update failed. Check connection or event details.', errorIndicatorRed);
      }
      setState(() => _isLoading = false);
      return;
    }

    // Create new event(s)
    final List<DateTime> finalStartTimes = isRecurringMode
        ? [_combineDateTime(_startDate, _startTime)] 
        : _selectedDates.map((date) => _combineDateTime(date, _startTime)).toList();
    
    // Make sure we have at least one date selected
    if (finalStartTimes.isEmpty) {
        _showErrorDialog('Date Error', 'Please select at least one date for the session(s).');
        setState(() => _isLoading = false);
        return;
    }

    // Create the event(s) in Google Calendar
    final results = await widget.client.createEvents(
      title: _title,
      startTimes: finalStartTimes,
      duration: duration,
      recurrenceRule: _selectedRecurrence,
      recurrenceUntil: isRecurringMode ? _recurrenceEndDate : null,
      importanceKey: _selectedImportance, 
      isRikazSession: true,
    );

    if (results.any((r) => r != null)) {
      widget.onEventUpdated();
      Navigator.pop(context);
      _showSnackbar('Session(s) added to Google Calendar!', Colors.green);
    } else {
      _showSnackbar('Add failed. Check connection or console for details.', errorIndicatorRed);
    }

    setState(() => _isLoading = false);
  }

  // Show a snackbar message
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
  
  // Show an error dialog
  Future<void> _showErrorDialog(String title, String content) async {
     return showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          backgroundColor: cardBackground,
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.045),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: _adaptiveFontSize(0.035),
                    color: secondaryTextGrey,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryThemeColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.04,
                        vertical: MediaQuery.of(context).size.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('OK', style: TextStyle(fontSize: _adaptiveFontSize(0.035))),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  // Calculate adaptive font size
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    final mitigationFactor = 0.95;
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }

  // Build input decoration for form fields
  InputDecoration _inputDecoration({required String label, required IconData icon, bool enabled = true}) {
    final accent = primaryThemeColor;
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
      labelStyle: TextStyle(color: enabled ? primaryTextDark : secondaryTextGrey, fontSize: _adaptiveFontSize(0.032)),
      prefixIcon: Icon(icon, color: enabled ? accent : secondaryTextGrey, size: _adaptiveFontSize(0.045)),
      fillColor: enabled ? cardBackground : Colors.grey.shade100,
      filled: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = primaryThemeColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Recurrence options for dropdown
    final recurrenceOptions = {
      'One-time': null,
      'Daily': 'RRULE:FREQ=DAILY',
      'Weekly': 'RRULE:FREQ=WEEKLY',
      'Monthly': 'RRULE:FREQ=MONTHLY',
    };

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(cardBorderRadius)),
        boxShadow: subtleShadow,
      ),
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05, 
        screenHeight * 0.025, 
        screenWidth * 0.05, 
        MediaQuery.of(context).viewInsets.bottom + screenHeight * 0.025
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: screenWidth * 0.08),
                  Text(
                    isEditing ? 'Edit Session' : 'Add New Session',
                    style: TextStyle(fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
                    textAlign: TextAlign.center,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: secondaryTextGrey),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),

             Divider(height: screenHeight * 0.02, color: Colors.grey), 

              // Title input field
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                child: TextFormField(
                  initialValue: isEditing ? _title : null,
                  decoration: _inputDecoration(
                    label: 'Session Title',
                    icon: Icons.title,
                    enabled: true,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
                  onSaved: (value) => _title = value!,
                ),
              ),
              SizedBox(height: screenHeight * 0.01), 
              
              // Importance dropdown (only when creating)
              if (!isEditing)
                DropdownButtonFormField<String>(
                  value: _selectedImportance,
                  decoration: _inputDecoration(label: 'Importance', icon: Icons.flag),
                  items: importanceColors.keys.where((key) => key != 'Info').map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: importanceColors[key], shape: BoxShape.circle)),
                          SizedBox(width: 8),
                          Text(key, style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedImportance = newValue!;
                    });
                  },
                ),
              SizedBox(height: screenHeight * 0.01), 
              
              // Recurrence dropdown (only when creating)
              if (!isEditing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: recurrenceOptions.keys.firstWhere((k) => recurrenceOptions[k] == _selectedRecurrence, orElse: () => 'One-time'),
                      decoration: _inputDecoration(label: 'Repeat', icon: Icons.repeat),
                      items: recurrenceOptions.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key, style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                        );
                      }).toList(),
                      onChanged: (String? key) {
                        setState(() {
                          _selectedRecurrence = recurrenceOptions[key];
                          // Reset dates when changing mode
                          if (_selectedRecurrence != null) {
                            _selectedDates = [_startDate];
                          }
                        });
                      },
                    ),
                    // FIXED: Updated hint text for one-time mode
                    if (isRecurringMode)
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.01, left: screenWidth * 0.03),
                        child: Text(
                          'Pick one date - this session will repeat ${_selectedRecurrence!.contains('DAILY') ? 'daily' : _selectedRecurrence!.contains('WEEKLY') ? 'weekly' : 'monthly'}',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.028),
                            color: accentThemeColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else if (isMultiDateMode)
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.01, left: screenWidth * 0.03),
                        child: Text(
                          'Pick one or more dates for individual sessions',
                          style: TextStyle(
                            fontSize: _adaptiveFontSize(0.028),
                            color: accentThemeColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              SizedBox(height: screenHeight * 0.015),
              
              // Date pickers
              Row(
                  children: [
                      // Main date picker (changes based on mode)
                      Expanded(
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isRecurringMode ? 'Start Date' : (isMultiDateMode ? 'Session Dates' : 'Start Date'),
                                style: TextStyle(fontSize: _adaptiveFontSize(0.032))
                              ),
                              subtitle: Text(
                                  isMultiDateMode && _selectedDates.length > 1
                                      ? '${_selectedDates.length} Dates Selected'
                                      : DateFormat('MMM dd, yyyy').format(_startDate),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.032))), 
                              leading: Icon(
                                isMultiDateMode && _selectedDates.length > 1 ? Icons.date_range : Icons.calendar_today,
                                color: accent,
                                size: _adaptiveFontSize(0.045)
                              ),
                              onTap: isMultiDateMode ? () async { 
                                  // Multi-date picker dialog
                                  final dates = await showDialog<List<DateTime>>(
                                      context: context,
                                      builder: (context) => _MultiDatePickerDialog(
                                          initialDates: _selectedDates,
                                      ),
                                  );
                                  if (dates != null && dates.isNotEmpty) {
                                      setState(() {
                                          _selectedDates = dates;
                                          _startDate = dates.first;
                                      });
                                  }
                              } : () async {
                                  // Single date picker
                                  final date = await _showThemedDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                  );
                                  if (date != null) setState(() => _startDate = date);
                              },
                          ),
                      ),
                      
                      // Recurrence end date (only for recurring events)
                      if (isRecurringMode)
                          Expanded(
                              child: ListTile(
                                  contentPadding: EdgeInsets.only(left: screenWidth * 0.01), 
                                  title: Text('Repeat Until', style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                                  subtitle: Text(DateFormat('MMM dd').format(_recurrenceEndDate!),
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.032))), 
                                  onTap: () async {
                                      final date = await _showThemedDatePicker(
                                        context: context,
                                        initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 7)),
                                        firstDate: _startDate,
                                        lastDate: _startDate.add(const Duration(days: 365)),
                                      );
                                      if (date != null) setState(() => _recurrenceEndDate = date);
                                  },
                              ),
                          ),
                  ],
              ),
              const Divider(), 

              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Start Time', style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                      subtitle: Text(_startTime.format(context), style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.034))),
                      leading: Icon(Icons.schedule, color: accent, size: _adaptiveFontSize(0.045)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context, 
                          initialTime: _startTime,
                          builder: (context, child) {
                            return Theme(
                                data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                        primary: primaryThemeColor,
                                        onPrimary: Colors.white,
                                        surface: cardBackground,
                                        onSurface: primaryTextDark,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(foregroundColor: primaryThemeColor),
                                    ),
                                ),
                                child: child!,
                            );
                          },
                        );
                        if (time != null) setState(() => _startTime = time);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('End Time', style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                      subtitle: Text(_endTime.format(context), style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.034))),
                      leading: Icon(Icons.schedule, color: accent, size: _adaptiveFontSize(0.045)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context, 
                          initialTime: _endTime,
                          builder: (context, child) {
                            return Theme(
                                data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                        primary: primaryThemeColor, 
                                        onPrimary: Colors.white,
                                        surface: cardBackground, 
                                        onSurface: primaryTextDark, 
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(foregroundColor: primaryThemeColor),
                                    ),
                                ),
                                child: child!,
                            );
                          },
                        );
                        if (time != null) setState(() => _endTime = time);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.035),

              // Action buttons
              _isLoading
                  ? Center(child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.025),
                  child: CircularProgressIndicator(color: accent)))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Save or Add button
                  if (isEditing)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSave, 
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text('Save Changes', style: TextStyle(fontSize: _adaptiveFontSize(0.034))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSave, 
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text('Add Session', style: TextStyle(fontSize: _adaptiveFontSize(0.034))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.025),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.034))),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show a themed date picker
  Future<DateTime?> _showThemedDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryThemeColor,
              onPrimary: Colors.white,
              surface: cardBackground,
              onSurface: primaryTextDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryThemeColor),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

// =============================================================================
// MULTI-DATE PICKER DIALOG
// Allows selecting multiple dates at once
// =============================================================================

class _MultiDatePickerDialog extends StatefulWidget {
  final List<DateTime> initialDates;

  const _MultiDatePickerDialog({required this.initialDates});

  @override
  _MultiDatePickerDialogState createState() => _MultiDatePickerDialogState();
}

class _MultiDatePickerDialogState extends State<_MultiDatePickerDialog> {
  late List<DateTime> _selectedDates;

  @override
  void initState() {
    super.initState();
    // Normalize dates to remove time component
    _selectedDates = widget.initialDates.map((d) => DateTime(d.year, d.month, d.day)).toList();
  }

  // Toggle date selection
  void _onDaySelected(DateTime day, DateTime focusedDay) {
    setState(() {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      if (_selectedDates.contains(normalizedDay)) {
        _selectedDates.remove(normalizedDay);
      } else {
        _selectedDates.add(normalizedDay);
        _selectedDates.sort();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select One or More Dates',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.045,
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            SizedBox(
              width: double.maxFinite,
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
                focusedDay: _selectedDates.isNotEmpty ? _selectedDates.first : DateTime.now(),
                selectedDayPredicate: (day) {
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  return _selectedDates.contains(normalizedDay);
                },
                onDaySelected: _onDaySelected,
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: primaryThemeColor.withOpacity(0.3), shape: BoxShape.circle),
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(foregroundColor: secondaryTextGrey),
                  child: const Text('Cancel'),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDates),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryThemeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('OK (${_selectedDates.length})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}