import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dart:async';
// Ensure SessionMode is imported from your file
import 'package:rikazapp/pages/subscreens/SetSession.dart'; 

// These enums help us keep track of which view mode the user has selected
enum ScheduleView { all, rikaz }
enum CalendarFormatView { list, month }

// =============================================================================
// THEME COLORS (matching SetSession.dart teal/cyan theme)
// =============================================================================

const Color dfDeepTeal = Color(0xFF175B73);
const Color dfTealCyan = Color(0xFF287C85);
const Color dfLightSeafoam = Color(0xFF87ACA3);
const Color dfDeepBlue = Color(0xFF162893);
const Color dfNavyIndigo = Color(0xFF0C1446);

// Primary theme colors - NOW USING TEAL
const Color primaryThemeColor = dfDeepTeal;      // Changed to teal
const Color accentThemeColor = dfTealCyan;       // Teal cyan accent
const Color lightestAccentColor = dfLightSeafoam;

const Color primaryBackground = Color(0xFFFFFFFF); // White background
const Color cardBackground = Color(0xFFFFFFFF);    // White cards

const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);

const Color errorIndicatorRed = Color(0xFFE57373);

const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

List<BoxShadow> get cardShadow => [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 5),
        blurRadius: 10,
      ),
    ];

Map<String, Color> importanceColors = {
  'High': const Color(0xFFEA4335),        
  'Medium': const Color(0xFFFBBC04),      
  'Low': const Color(0xFF34A853),         
  'Default': const Color(0xFF4285F4),     
};

Map<String, String> googleColorMap = {
  'High': '11',
  'Medium': '5',
  'Low': '10',
  'Default': '9',
};

// -----------------------------------------------------------------------------
// GOOGLE CALENDAR API CLIENT
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

  Future<List<calendar.Event>> fetchUpcomingEvents() async {
    if (calendarApi == null) return [];

    // Fetch wider range to support Month View navigation
    final now = DateTime.now().subtract(const Duration(days: 60)).toUtc();
    final future = DateTime.now().add(const Duration(days: 120)).toUtc();

    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 500,
        timeMin: now,
        timeMax: future,
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items?.where((e) => e.summary != null && e.start != null).toList() ?? [];
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<calendar.Event?> fetchEventById(String eventId) async {
    if (calendarApi == null) return null;
    
    try {
      final event = await calendarApi!.events.get('primary', eventId);
      return event;
    } catch (e) {
      debugPrint('Error fetching event by ID: $e');
      return null;
    }
  }

  Future<calendar.Event?> getRecurringEventMaster(String recurringEventId) async {
    if (calendarApi == null) return null;
    
    try {
      // Fetch the master recurring event (without instance ID)
      final event = await calendarApi!.events.get('primary', recurringEventId);
      return event;
    } catch (e) {
      debugPrint('Error fetching recurring event master: $e');
      return null;
    }
  }

  Future<List<calendar.Event>> checkForConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeEventId,
  }) async {
    if (calendarApi == null) return [];

    try {
      final events = await calendarApi!.events.list(
        'primary',
        timeMin: startTime.toUtc(),
        timeMax: endTime.toUtc(),
        singleEvents: true,
      );

      return events.items?.where((event) {
        if (event.id == excludeEventId) return false;
        if (event.start?.dateTime == null || event.end?.dateTime == null) return false;
        
        final eventStart = event.start!.dateTime!.toLocal();
        final eventEnd = event.end!.dateTime!.toLocal();
        
        return (startTime.isBefore(eventEnd) && endTime.isAfter(eventStart));
      }).toList() ?? [];
    } catch (e) {
      debugPrint('Error checking conflicts: $e');
      return [];
    }
  }

  Future<calendar.Event?> updateEvent({
    required String eventId,
    required DateTime startTime,
    required DateTime endTime,
    required String title,
    required String importanceKey,
    String? recurrenceRule,
    DateTime? recurrenceUntil,
    bool isRikazSession = true,
    bool updateAllOccurrences = true,
  }) async {
    if (calendarApi == null) return null;

    try {
      // Create a fresh event object instead of copying from existing
      final updatedEvent = calendar.Event();
      
      updatedEvent.summary = title;
      updatedEvent.start = calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC');
      updatedEvent.end = calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC');
      
      final googleColorId = googleColorMap[importanceKey] ?? googleColorMap['Default']!;
      updatedEvent.colorId = googleColorId;
      
      updatedEvent.extendedProperties = calendar.EventExtendedProperties(
        private: {
          'isRikazSession': isRikazSession.toString(),
          'importance': importanceKey,
        }
      );
      
      if (recurrenceRule != null) {
        String rrule = recurrenceRule;
        if (recurrenceUntil != null) {
          final untilUtc = recurrenceUntil.toUtc();
          rrule += ';UNTIL=${DateFormat('yyyyMMdd').format(untilUtc)}T${DateFormat('HHmmss').format(untilUtc)}Z';
        }
        updatedEvent.recurrence = [rrule];
      } else {
        updatedEvent.recurrence = [];
      }

      final result = await calendarApi!.events.update(
        updatedEvent, 
        'primary', 
        eventId,
      );
      return result;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return null;
    }
  }

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
    final googleColorId = googleColorMap[importanceKey] ?? googleColorMap['Default']!;

    if (recurrenceRule != null && startTimes.isNotEmpty) {
      final startTime = startTimes.first;
      final endTime = startTime.add(duration);
      
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

  Future<bool> deleteEvent(String eventId, {bool deleteAllFuture = false}) async {
    if (calendarApi == null) return false;
    try {
      if (deleteAllFuture) {
        // Delete all future occurrences by deleting the master event
        await calendarApi!.events.delete('primary', eventId);
      } else {
        // Delete just this instance
        await calendarApi!.events.delete('primary', eventId);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<bool> deleteRecurringEventFromDate(String recurringEventId, DateTime fromDate) async {
    if (calendarApi == null) return false;
    
    try {
      // Fetch the master event
      final masterEvent = await calendarApi!.events.get('primary', recurringEventId);
      
      if (masterEvent.recurrence == null || masterEvent.recurrence!.isEmpty) {
        return false;
      }
      
      // Update the UNTIL date to end recurrence at the day before this date
      String rrule = masterEvent.recurrence!.first;
      
      // Remove existing UNTIL if present
      if (rrule.contains('UNTIL=')) {
        rrule = rrule.split(';UNTIL=')[0];
      }
      
      // Set UNTIL to the day before fromDate to exclude fromDate and all future
      final untilDate = fromDate.subtract(const Duration(days: 1)).toUtc();
      rrule += ';UNTIL=${DateFormat('yyyyMMdd').format(untilDate)}T235959Z';
      
      masterEvent.recurrence = [rrule];
      
      await calendarApi!.events.update(masterEvent, 'primary', recurringEventId);
      return true;
    } catch (e) {
      debugPrint('Error deleting from date: $e');
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// MAIN HOME PAGE
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  
  final CalendarClient _client = CalendarClient();
  
  bool _isCalendarConnected = false;
  // ignore: unused_field
  bool _isSigningIn = false;
  
  List<calendar.Event> _events = [];
  List<calendar.Event> _displayedEvents = [];
  
  ScheduleView _scheduleView = ScheduleView.all;
  CalendarFormatView _calendarFormatView = CalendarFormatView.list; 

  final supabase = sb.Supabase.instance.client; 
  String _userName = 'User Name'; 

  // Initialize to Today
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); 

  int? selectedModeIndex;
  
  // -- Selection Mode State --
  Set<String> _selectedEventsToDelete = {}; 
  bool _isSelectionMode = false;
  bool _isBulkDeleting = false; 

  // -- Auto-refresh timer --
  Timer? _autoRefreshTimer;

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
    _fetchUserName(); 

    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      final wasConnected = _isCalendarConnected;
      if (account != null) {
        _client.signIn().then((success) {
          if (success) {
            _fetchSchedule();
            _startAutoRefresh();
          }
          setState(() {
            _isCalendarConnected = success;
          });
        });
      } else if (wasConnected) {
          _stopAutoRefresh();
          setState(() {
            _isCalendarConnected = false;
            _events = [];
            _displayedEvents = [];
            _selectedEventsToDelete.clear();
            _isSelectionMode = false;
          });
          _filterEvents(); 
      }
    });
    
    _client._googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_client.isConnected) {
        _fetchSchedule();
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _client.isConnected) { 
      _fetchSchedule();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client.isConnected) { 
      _fetchSchedule();
    }
  }
  
  Future<void> _fetchUserName() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      String fetchedName = 'User';
      final metadataName = metadata?['full_name'] as String?;
      if (metadataName != null && metadataName.isNotEmpty) {
          fetchedName = metadataName;
      } else {
        fetchedName = user.email?.split('@')[0] ?? 'User';
      }
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

  // --- Strict Filtering Logic ---
  void _filterEvents() {
    List<calendar.Event> sourceEvents;
    
    if (_isCalendarConnected) {
      sourceEvents = _events.toList(); 
    } else {
      sourceEvents = [];
    }
    
    // Strict date filter: Only show events for _selectedDay
    sourceEvents = sourceEvents.where((e) {
      final start = e.start?.dateTime?.toLocal() ?? e.start?.date;
      if (start == null) return false;
      return isSameDay(start, _selectedDay);
    }).toList();

    if (_scheduleView == ScheduleView.rikaz) {
      sourceEvents = sourceEvents.where((event) {
        return event.extendedProperties?.private?['isRikazSession'] == 'true';
      }).toList();
    }
    
    _displayedEvents = sourceEvents;
    
    _displayedEvents.sort((a, b) {
      final timeA = a.start?.dateTime?.toLocal() ?? a.start?.date;
      final timeB = b.start?.dateTime?.toLocal() ?? b.start?.date;
      if (timeA == null || timeB == null) return 0;
      return timeA.compareTo(timeB);
    });
  }

  // --- Selection / Deletion Logic ---

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedEventsToDelete.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedEventsToDelete.clear();
    });
  }

  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedEventsToDelete.contains(eventId)) {
        _selectedEventsToDelete.remove(eventId);
        if (_selectedEventsToDelete.isEmpty) {
           // Optional behavior: could auto-exit mode
        }
      } else {
        _selectedEventsToDelete.add(eventId);
      }
    });
  }
  
  Future<void> _handleBulkDelete() async {
    if (_selectedEventsToDelete.isEmpty || !_client.isConnected) return;

    // Check if any selected event is a recurring instance
    final selectedEvents = _displayedEvents.where((e) => 
      e.id != null && _selectedEventsToDelete.contains(e.id)
    ).toList();
    
    final hasRecurring = selectedEvents.any((e) => e.recurringEventId != null);

    String? recurringChoice;
    if (hasRecurring) {
      // Ask user about recurring events
      recurringChoice = await showDialog<String>(
        context: context,
        builder: (context) => _buildRecurringDeleteDialog(),
      );
      
      if (recurringChoice == null) return; // User cancelled
    }

    final count = _selectedEventsToDelete.length;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _buildThemedDialog(
        title: 'Delete Selected?',
        content: 'Are you sure you want to delete $count session${count > 1 ? 's' : ''}?',
        cancelText: 'Cancel',
        confirmText: 'Delete',
        isDestructive: true,
      ),
    );

    if (confirmDelete == true) {
      setState(() {
        _isBulkDeleting = true;
      });

      for (var id in _selectedEventsToDelete) {
        final event = _displayedEvents.firstWhere((e) => e.id == id, orElse: () => _displayedEvents.first);
        
        if (event.recurringEventId != null && recurringChoice != null) {
          // Handle recurring event based on choice
          if (recurringChoice == 'this') {
            await _client.deleteEvent(id);
          } else if (recurringChoice == 'future') {
            final eventDate = event.start!.dateTime!.toLocal();
            await _client.deleteRecurringEventFromDate(event.recurringEventId!, eventDate);
          } else if (recurringChoice == 'all') {
            await _client.deleteEvent(event.recurringEventId!);
          }
        } else {
          // Regular event
          await _client.deleteEvent(id);
        }
      }
      
      await _fetchSchedule();
      
      if (mounted) {
        setState(() {
          _isBulkDeleting = false;
          _isSelectionMode = false;
          _selectedEventsToDelete.clear();
        });
        _showSnackbar('Deleted successfully.', Colors.green);
      }
    }
  }

  void _setScheduleView(ScheduleView view) {
    setState(() {
      _scheduleView = view;
      _filterEvents(); 
      _selectedEventsToDelete.clear(); 
      _isSelectionMode = false;
    });
  }
  
  void _setCalendarFormatView(CalendarFormatView view) {
    setState(() {
      _calendarFormatView = view;
      if (view == CalendarFormatView.list) {
        _filterEvents();
      }
    });
  }

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
      _startAutoRefresh();
      if (mounted) _showSnackbar('Connected!', Colors.green);
    } else {
      if (mounted) _showSnackbar('Connection failed.', errorIndicatorRed);
    }
  }

  Future<void> _handleCalendarSignOut() async {
    _stopAutoRefresh();
    await _client.signOut();
    setState(() {
      _isCalendarConnected = false;
      _events = [];
      _displayedEvents = [];
      _selectedEventsToDelete.clear();
      _isSelectionMode = false;
    });
    _showSnackbar('Disconnected.', primaryThemeColor);
    _filterEvents();
  }

  void handleSetSession() {
    if (selectedModeIndex == null) return;
    final initialMode = selectedModeIndex == 0 ? SessionMode.pomodoro : SessionMode.custom;
    
    Navigator.of(context).pushNamed(
      '/SetSession',
      arguments: initialMode, 
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

  void _onMonthDayTapped(DateTime day) {
    // Prevent selection of past days (older than today's date)
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (day.isBefore(today)) {
        _showSnackbar('Cannot select past dates.', errorIndicatorRed);
        return;
    }

    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
    _filterEvents();
  }

  void _showEventOverlay({calendar.Event? eventToEdit, DateTime? selectedDate}) {
    if (!_client.isConnected && eventToEdit == null) { 
       _showSnackbar('Please connect to Google Calendar first.', errorIndicatorRed);
      return;
    }
    
    if (_client.isConnected || eventToEdit != null) { 
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false, 
          enableDrag: true,
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
                allEvents: _events,
              ),
            );
          },
        );
    }
  }
  
  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseSize = screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final mitigationFactor = 0.9; 
    return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
  }
  
  Color _getEventColor(calendar.Event event) {
    final importanceKey = event.extendedProperties?.private?['importance'];
    return importanceColors[importanceKey] ?? importanceColors['Default']!;
  }
  
  List<Color> _getEventColorsForDay(DateTime day) {
    if (!_isCalendarConnected) return []; 
    
    final eventsOnDay = _events.where((event) {
      final start = event.start?.dateTime?.toLocal() ?? event.start?.date;
      return start != null && isSameDay(day, start);
    }).toList();
    
    final uniqueImportanceKeys = eventsOnDay
        .map((e) => e.extendedProperties?.private?['importance'] ?? 'Default')
        .toSet();

    return uniqueImportanceKeys
        .map((key) => importanceColors[key] ?? importanceColors['Default']!)
        .toList();
  }
  
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
                  child: Text(cancelText, style: TextStyle(fontSize: _adaptiveFontSize(0.035), color: secondaryTextGrey)),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? errorIndicatorRed : primaryThemeColor,
                    foregroundColor: Colors.white,
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

  Widget _buildRecurringDeleteDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: errorIndicatorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: errorIndicatorRed,
                size: 28,
              ),
            ),
            SizedBox(height: 16),
            
            // Title
            Text(
              'Delete Recurring Session',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            
            // Description
            Text(
              'Choose which occurrences to remove',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextGrey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Options
            _buildDeleteDialogOption(
              title: 'Only This Session',
              subtitle: 'Remove just this one',
              icon: Icons.event,
              color: primaryThemeColor,
              onTap: () => Navigator.of(context).pop('this'),
            ),
            SizedBox(height: 10),
            _buildDeleteDialogOption(
              title: 'This & Future Sessions',
              subtitle: 'Remove this and upcoming',
              icon: Icons.event_repeat,
              color: Colors.orange[700]!,
              onTap: () => Navigator.of(context).pop('future'),
            ),
            SizedBox(height: 10),
            _buildDeleteDialogOption(
              title: 'All Sessions',
              subtitle: 'Remove entire series',
              icon: Icons.calendar_month,
              color: errorIndicatorRed,
              onTap: () => Navigator.of(context).pop('all'),
            ),
            SizedBox(height: 16),
            
            // Cancel
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteDialogOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryTextDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: secondaryTextGrey),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILDING METHODS
  // ---------------------------------------------------------------------------

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
            style: TextStyle(fontSize: _adaptiveFontSize(0.032), color: secondaryTextGrey),
          ),
          SizedBox(height: screenHeight * 0.02),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedModeIndex != null ? handleSetSession : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedMode ? primaryThemeColor : primaryThemeColor.withOpacity(0.5),
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
                elevation: hasSelectedMode ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'Set Session',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: _adaptiveFontSize(0.04), color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          _buildViewToggle(),
          SizedBox(height: screenHeight * 0.02),
          _buildGoogleConnectPanel(screenWidth),
          SizedBox(height: screenHeight * 0.02),
          if (_calendarFormatView == CalendarFormatView.month)
            _buildMonthCalendarView(screenHeight, screenWidth)
          else 
            _buildListView(screenHeight, screenWidth),
        ],
      ),
    );
  }

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

  Widget _buildMonthCalendarView(double screenHeight, double screenWidth) {
    if (!_isCalendarConnected) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
        child: Center(
          child: Text(
            'Connect Google Calendar to see your schedule.',
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
          firstDay: DateTime(DateTime.now().year, DateTime.now().month, 1), // Disable months before current
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          currentDay: DateTime.now(),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
          ),
          calendarFormat: CalendarFormat.month,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: accentThemeColor.withOpacity(0.3), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle),
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: errorIndicatorRed),
            disabledTextStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          ),
          // Disable selection of past days
          enabledDayPredicate: (day) {
            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            return !day.isBefore(today);
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                      decoration: BoxDecoration(color: colors[index] as Color, shape: BoxShape.circle),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        // Consistent Add Session Button in Month View
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showEventOverlay(selectedDate: _selectedDay),
            icon: Icon(Icons.add_circle, color: Colors.white),
            label: Text('Add Session', style: TextStyle(color: Colors.white, fontSize: _adaptiveFontSize(0.032))),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryThemeColor,
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        
        // Schedule toggle in month view
        _buildScheduleToggle(screenWidth),
        SizedBox(height: screenHeight * 0.015),
        
        // Month view strictly filtered list
        if (_displayedEvents.isNotEmpty)
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _displayedEvents.length,
            itemBuilder: (context, index) {
              final event = _displayedEvents[index];
              return _buildSessionCard(
                event: event,
                color: _getEventColor(event),
                startTime: event.start!.dateTime!.toLocal(),
                endTime: event.end?.dateTime?.toLocal(),
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                isSelected: _selectedEventsToDelete.contains(event.id),
                onTap: null,
              );
            },
          )
        else
            Center(
                child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No sessions on this day.', style: TextStyle(color: secondaryTextGrey)),
            )),
      ],
    );
  }

  Widget _buildListView(double screenHeight, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateRibbon(
          selectedDay: _selectedDay,
          onDaySelected: (day) {
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
            });
            _filterEvents(); // Strict filter
          },
        ),
        SizedBox(height: screenHeight * 0.015),

        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: secondaryTextGrey.withOpacity(0.2), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text( 
                'Sessions',
                style: TextStyle(fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),

        _buildScheduleToggle(screenWidth),
        SizedBox(height: screenHeight * 0.015),
        
        // Only show Add button if not selecting items
        if (!_isSelectionMode)
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEventOverlay(selectedDate: _selectedDay),
              icon: Icon(Icons.add_circle, color: Colors.white),
              label: Text('Add Session', style: TextStyle(color: Colors.white, fontSize: _adaptiveFontSize(0.032))),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryThemeColor,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
              ),
            ),
          ),
        
        SizedBox(height: screenHeight * 0.015),

        _displayedEvents.isEmpty
            ? Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03),
            child: Text(
              'No sessions found for selected date.',
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

            if (startTime == null) return const SizedBox.shrink();

            return _buildSessionCard(
              event: event,
              color: eventColor,
              startTime: startTime,
              endTime: endTime,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              isSelected: isSelected,
              onTap: null, // Logic handled inside card
            );
          },
        ),
      ],
    );
  }
  
  // WHATSAPP STYLE SELECTION CARD
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
        onTap: () {
            if (_isSelectionMode && event.id != null) {
                _toggleEventSelection(event.id!);
            }
        },
        onLongPress: () {
            if (event.id != null) {
                _enterSelectionMode(event.id!);
            }
        },
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
              // Checkbox if in selection mode
              if (_isSelectionMode)
                 Padding(
                   padding: EdgeInsets.symmetric(horizontal: 12),
                   child: Icon(
                       isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                       color: isSelected ? color : secondaryTextGrey,
                   ),
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
                            ? '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
                            : DateFormat('MMM d, yyyy').format(startTime),
                        style: TextStyle(color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.028)),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (!_isSelectionMode && _isCalendarConnected && event.id != null) 
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: secondaryTextGrey, size: screenWidth * 0.055),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEventOverlay(eventToEdit: event);
                    } else if (value == 'select_delete') {
                      // Enter selection mode for delete
                      _enterSelectionMode(event.id!);
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
                      value: 'select_delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Select to Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

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
        buildButton(ScheduleView.all, 'All Calendar'),
        buildButton(ScheduleView.rikaz, 'Rikaz Focus'),
      ],
    );
  }
  
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
      resizeToAvoidBottomInset: true,
      backgroundColor: primaryBackground,
      
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        left: proportionalHorizontalPadding,
                        right: proportionalHorizontalPadding,
                        top: screenHeight * 0.02,
                        bottom: _isSelectionMode ? screenHeight * 0.12 : 100 
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome
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
                        
                        buildFocusSessionPanel(),
                        buildScheduleContainer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Floating action bar for selection mode - positioned better
            if (_isSelectionMode)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _exitSelectionMode,
                        icon: Icon(Icons.close, color: secondaryTextGrey, size: 20),
                        label: Text(
                          "Cancel",
                          style: TextStyle(
                            color: secondaryTextGrey, 
                            fontSize: 15, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryThemeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${_selectedEventsToDelete.length} selected",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryThemeColor,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isBulkDeleting ? null : _handleBulkDelete,
                        icon: _isBulkDeleting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.delete_outline, color: Colors.white, size: 20),
                        label: Text(
                          "Delete",
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 15, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorIndicatorRed,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATE RIBBON (Fix: Opens at Today's Week)
// =============================================================================

class _DateRibbon extends StatefulWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _DateRibbon({
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<_DateRibbon> createState() => _DateRibbonState();
}

class _DateRibbonState extends State<_DateRibbon> {
  late ScrollController _scrollController;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final today = DateTime.now();
    _startDate = today.subtract(const Duration(days: 3)); 
    _endDate = today.add(const Duration(days: 60));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return SizedBox(
      height: screenWidth * 0.2,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _endDate.difference(_startDate).inDays + 1,
        itemBuilder: (context, index) {
          final day = _startDate.add(Duration(days: index));
          
          final bool isSelected = isSameDay(widget.selectedDay, day);
          final bool isToday = isSameDay(DateTime.now(), day);
          
          final bool isPast = day.isBefore(today);

          return GestureDetector(
            onTap: isPast ? null : () => widget.onDaySelected(day),
            child: Container(
              width: screenWidth * 0.14,
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryThemeColor 
                    : isToday 
                        ? lightestAccentColor.withOpacity(0.5) 
                        : isPast ? Colors.grey[200] : cardBackground,
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
                      color: isPast ? Colors.grey : (isSelected ? Colors.white : primaryTextDark),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(day),
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.w900,
                      color: isPast ? Colors.grey : (isSelected ? Colors.white : primaryTextDark),
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
// EVENT MANAGEMENT OVERLAY (COMPLETELY FIXED)
// -----------------------------------------------------------------------------

class _EventManagementOverlay extends StatefulWidget {
  final CalendarClient client;
  final calendar.Event? eventToEdit;
  final VoidCallback onEventUpdated;
  final DateTime? initialDate;
  final List<calendar.Event> allEvents;

  const _EventManagementOverlay({
    required this.client,
    required this.onEventUpdated,
    this.eventToEdit,
    this.initialDate,
    required this.allEvents,
  });

  @override
  __EventManagementOverlayState createState() => __EventManagementOverlayState();
}

class __EventManagementOverlayState extends State<_EventManagementOverlay> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  late String _title;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;
  
  late String _selectedImportance; 
  String? _selectedRecurrence; 
  List<DateTime> _selectedDates = []; 
  DateTime? _recurrenceEndDate; 
  
  String? _initialRecurrence;
  bool _wasRecurring = false;
  bool _isFormDirty = false;
  
  // NEW: Track if this is a recurring instance
  bool _isRecurringInstance = false;
  String? _masterEventId;

  bool get isEditing => widget.eventToEdit != null;
  bool get isRecurringMode => _selectedRecurrence != null && !isEditing;
  bool get isMultiDateMode => _selectedRecurrence == null && !isEditing;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    final now = DateTime.now();

    if (isEditing) {
      _title = widget.eventToEdit!.summary ?? 'Untitled Session';
      final start = widget.eventToEdit!.start!.dateTime?.toLocal() ?? now;
      final end = widget.eventToEdit!.end!.dateTime?.toLocal() ?? now.add(const Duration(hours: 1));

      _startDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(end);
      
      _selectedImportance = widget.eventToEdit!.extendedProperties?.private?['importance'] ?? 'Default';
      
      // Check if this is a recurring event instance
      _isRecurringInstance = widget.eventToEdit!.recurringEventId != null;
      
      if (_isRecurringInstance) {
        // This is an instance - fetch the master event to get recurrence info
        _masterEventId = widget.eventToEdit!.recurringEventId;
        final masterEvent = await widget.client.getRecurringEventMaster(_masterEventId!);
        
        if (masterEvent != null && masterEvent.recurrence != null && masterEvent.recurrence!.isNotEmpty) {
          _wasRecurring = true;
          final rrule = masterEvent.recurrence!.first;
          
          if (rrule.contains('FREQ=DAILY')) {
            _selectedRecurrence = 'RRULE:FREQ=DAILY';
          } else if (rrule.contains('FREQ=WEEKLY')) {
            _selectedRecurrence = 'RRULE:FREQ=WEEKLY';
          } else if (rrule.contains('FREQ=MONTHLY')) {
            _selectedRecurrence = 'RRULE:FREQ=MONTHLY';
          }
          
          if (rrule.contains('UNTIL=')) {
            try {
              final untilStr = rrule.split('UNTIL=')[1].split(';')[0].split('T')[0];
              _recurrenceEndDate = DateTime.parse(
                '${untilStr.substring(0, 4)}-${untilStr.substring(4, 6)}-${untilStr.substring(6, 8)}'
              );
            } catch (e) {
              _recurrenceEndDate = _startDate.add(const Duration(days: 30));
            }
          } else {
            _recurrenceEndDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _wasRecurring = false;
          _selectedRecurrence = null;
          _recurrenceEndDate = _startDate.add(const Duration(days: 30));
        }
      } else {
        // Check the event itself for recurrence
        _wasRecurring = widget.eventToEdit!.recurrence != null && widget.eventToEdit!.recurrence!.isNotEmpty;
        
        if (_wasRecurring) {
          final rrule = widget.eventToEdit!.recurrence!.first;
          if (rrule.contains('FREQ=DAILY')) {
            _selectedRecurrence = 'RRULE:FREQ=DAILY';
          } else if (rrule.contains('FREQ=WEEKLY')) {
            _selectedRecurrence = 'RRULE:FREQ=WEEKLY';
          } else if (rrule.contains('FREQ=MONTHLY')) {
            _selectedRecurrence = 'RRULE:FREQ=MONTHLY';
          }
          
          if (rrule.contains('UNTIL=')) {
            try {
              final untilStr = rrule.split('UNTIL=')[1].split(';')[0].split('T')[0];
              _recurrenceEndDate = DateTime.parse(
                '${untilStr.substring(0, 4)}-${untilStr.substring(4, 6)}-${untilStr.substring(6, 8)}'
              );
            } catch (e) {
              _recurrenceEndDate = _startDate.add(const Duration(days: 30));
            }
          } else {
            _recurrenceEndDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          // Not recurring - this is a one-time or custom event
          // Custom events are just individual one-time events, not recurring
          _selectedRecurrence = null;
          _recurrenceEndDate = _startDate.add(const Duration(days: 30));
        }
      }
      
      _initialRecurrence = _selectedRecurrence;
      _selectedDates = [_startDate];
      
      if (mounted) setState(() {});
    } else {
      final selectedDate = widget.initialDate ?? now;
      _title = '';
      _startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      _startTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
      _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
      _selectedDates = [_startDate];
      _recurrenceEndDate = _startDate.add(const Duration(days: 30));
      _selectedImportance = 'Default';
      _wasRecurring = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _markDirty() {
    if (!_isFormDirty) {
        setState(() => _isFormDirty = true);
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

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus(); 
    
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime = _combineDateTime(_startDate, _endTime);
    final duration = endDateTime.difference(startDateTime);

    if (duration.isNegative) {
      _showErrorDialog('Time Error', 'End time cannot be before start time.');
      setState(() => _isLoading = false);
      return;
    }
    
    if (startDateTime.isBefore(DateTime.now())) {
      _showErrorDialog('Invalid Date', 'You cannot set a session in the past.');
      setState(() => _isLoading = false);
      return;
    }
    
    // Only check conflicts if editing and time/date/frequency changed
    bool shouldCheckConflicts = false;
    if (isEditing) {
      final originalStart = widget.eventToEdit!.start!.dateTime?.toLocal();
      final originalEnd = widget.eventToEdit!.end!.dateTime?.toLocal();
      
      // Check if time or date changed
      final timeChanged = originalStart != null && 
        (originalStart.hour != startDateTime.hour || 
         originalStart.minute != startDateTime.minute ||
         originalEnd?.hour != endDateTime.hour ||
         originalEnd?.minute != endDateTime.minute);
      
      final dateChanged = originalStart != null &&
        (originalStart.year != startDateTime.year ||
         originalStart.month != startDateTime.month ||
         originalStart.day != startDateTime.day);
      
      // Check if frequency changed
      final frequencyChanged = _selectedRecurrence != _initialRecurrence;
      
      shouldCheckConflicts = timeChanged || dateChanged || frequencyChanged;
    } else {
      // Always check conflicts when adding new
      shouldCheckConflicts = true;
    }
    
    if (shouldCheckConflicts) {
      final conflicts = await widget.client.checkForConflicts(
        startTime: startDateTime,
        endTime: endDateTime,
        excludeEventId: isEditing ? (_masterEventId ?? widget.eventToEdit?.id) : null,
      );

      if (conflicts.isNotEmpty && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => _buildThemedDialog(
            title: 'Conflict Detected',
            content: 'This overlaps with another event. ${isEditing ? 'Update' : 'Add'} anyway?',
            cancelText: 'Cancel',
            confirmText: '${isEditing ? 'Update' : 'Add'} Anyway',
          ),
        );
        if (confirm != true) {
            setState(() => _isLoading = false);
            return;
        }
      }
    }

    if (isEditing) {
      // If this is a recurring instance, ask if user wants to edit this or all future
      if (_isRecurringInstance && _wasRecurring) {
        // Special case: Converting to one-time
        if (_selectedRecurrence == null && _initialRecurrence != null) {
          final confirmBreak = await showDialog<bool>(
            context: context,
            builder: (context) => _buildThemedDialog(
              title: "Convert to One-Time?",
              content: "This will keep only this session and delete all other recurring sessions. This action cannot be undone.",
              cancelText: "Cancel",
              confirmText: "Keep This Only",
              isDestructive: true,
            ),
          );
          if (confirmBreak != true) {
            setState(() => _isLoading = false);
            return;
          }
          
          // Delete all future occurrences by updating master event's UNTIL date
          final sessionDate = widget.eventToEdit!.start!.dateTime!.toLocal();
          await widget.client.deleteRecurringEventFromDate(
            widget.eventToEdit!.recurringEventId!,
            sessionDate.add(const Duration(days: 1)), // Delete from tomorrow onwards
          );
          
          // Now update this instance to be standalone
          final updatedEvent = await widget.client.updateEvent(
            eventId: widget.eventToEdit!.id!,
            title: _title,
            startTime: startDateTime,
            endTime: endDateTime,
            importanceKey: _selectedImportance,
            recurrenceRule: null,
            updateAllOccurrences: false,
          );

          if (updatedEvent != null) {
            widget.onEventUpdated();
            if (mounted) Navigator.pop(context);
            _showSnackbar('Converted to one-time session!', Colors.green);
          } else {
            _showSnackbar('Update failed.', errorIndicatorRed);
          }
          setState(() => _isLoading = false);
          return;
        }
        
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => _buildRecurringEditDialog(),
        );
        
        if (choice == null) {
          setState(() => _isLoading = false);
          return;
        }
        
        if (choice == 'this') {
          // Edit only this instance
          final updatedEvent = await widget.client.updateEvent(
            eventId: widget.eventToEdit!.id!,
            title: _title,
            startTime: startDateTime,
            endTime: endDateTime,
            importanceKey: _selectedImportance,
            recurrenceRule: null,
            updateAllOccurrences: false,
          );

          if (updatedEvent != null) {
            widget.onEventUpdated();
            if (mounted) Navigator.pop(context);
            _showSnackbar('Session updated!', Colors.green);
          } else {
            _showSnackbar('Update failed.', errorIndicatorRed);
          }
          setState(() => _isLoading = false);
          return;
        } else if (choice == 'future') {
          // Edit this and all future occurrences
          // We need to end the old recurring series before this date
          // and create a new one starting from this date with the new settings
          
          final sessionDate = widget.eventToEdit!.start!.dateTime!.toLocal();
          
          // Step 1: End the old series the day before this session
          final success = await widget.client.deleteRecurringEventFromDate(
            _masterEventId!,
            sessionDate,
          );
          
          if (!success) {
            _showSnackbar('Update failed.', errorIndicatorRed);
            setState(() => _isLoading = false);
            return;
          }
          
          // Step 2: Create new recurring series starting from this date with new settings
          final recurrenceUntil = (_selectedRecurrence != null && _selectedRecurrence != 'custom') 
              ? _recurrenceEndDate 
              : null;
          
          final results = await widget.client.createEvents(
            title: _title,
            startTimes: [startDateTime],
            duration: duration,
            recurrenceRule: _selectedRecurrence,
            recurrenceUntil: recurrenceUntil,
            importanceKey: _selectedImportance,
            isRikazSession: true,
          );

          if (results.isNotEmpty && results.first != null) {
            widget.onEventUpdated();
            if (mounted) Navigator.pop(context);
            _showSnackbar('This and future sessions updated!', Colors.green);
          } else {
            _showSnackbar('Update failed.', errorIndicatorRed);
          }
          setState(() => _isLoading = false);
          return;
        } else if (choice == 'all') {
          // Edit all occurrences (including past)
          final updatedEvent = await widget.client.updateEvent(
            eventId: _masterEventId!,
            title: _title,
            startTime: startDateTime,
            endTime: endDateTime,
            importanceKey: _selectedImportance,
            recurrenceRule: _selectedRecurrence == 'custom' ? null : _selectedRecurrence,
            recurrenceUntil: (_selectedRecurrence != null && _selectedRecurrence != 'custom') ? _recurrenceEndDate : null,
            updateAllOccurrences: true,
          );

          if (updatedEvent != null) {
            widget.onEventUpdated();
            if (mounted) Navigator.pop(context);
            _showSnackbar('All sessions updated!', Colors.green);
          } else {
            _showSnackbar('Update failed.', errorIndicatorRed);
          }
          setState(() => _isLoading = false);
          return;
        }
      }
      
      // Check if converting recurring to one-time (for non-instance recurring events)
      if (_wasRecurring && _selectedRecurrence == null && !_isRecurringInstance) {
        final confirmBreak = await showDialog<bool>(
          context: context,
          builder: (context) => _buildThemedDialog(
            title: "Convert to One-Time Session?",
            content: "This will convert this recurring session to a one-time session. All future occurrences will be deleted permanently. This action cannot be undone.",
            cancelText: "Cancel",
            confirmText: "Delete Future Sessions",
            isDestructive: true,
          ),
        );
        if (confirmBreak != true) {
          setState(() => _isLoading = false);
          return;
        }
      }
      
      // Check if changing recurrence pattern
      if (_wasRecurring && _selectedRecurrence != null && _selectedRecurrence != 'custom' && _selectedRecurrence != _initialRecurrence) {
        final confirmChange = await showDialog<bool>(
          context: context,
          builder: (context) => _buildThemedDialog(
            title: "Change Recurrence Pattern?",
            content: "Changing the recurrence pattern will affect all future occurrences of this session.",
            cancelText: "Cancel",
            confirmText: "Update All",
          ),
        );
        if (confirmChange != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final eventIdToUpdate = _masterEventId ?? widget.eventToEdit!.id!;
      final updatedEvent = await widget.client.updateEvent(
        eventId: eventIdToUpdate,
        title: _title,
        startTime: startDateTime,
        endTime: endDateTime,
        importanceKey: _selectedImportance,
        recurrenceRule: _selectedRecurrence == 'custom' ? null : _selectedRecurrence,
        recurrenceUntil: (_selectedRecurrence != null && _selectedRecurrence != 'custom') ? _recurrenceEndDate : null,
      );

      if (updatedEvent != null) {
        widget.onEventUpdated();
        if (mounted) Navigator.pop(context);
        _showSnackbar('Session updated!', Colors.green);
      } else {
        _showSnackbar('Update failed.', errorIndicatorRed);
      }
      setState(() => _isLoading = false);
      return;
    }

    final List<DateTime> finalStartTimes = isRecurringMode
        ? [_combineDateTime(_startDate, _startTime)] 
        : [_combineDateTime(_startDate, _startTime)];
    
    if (finalStartTimes.isEmpty) {
        _showErrorDialog('Date Error', 'Select at least one date.');
        setState(() => _isLoading = false);
        return;
    }

    // Check for conflicts on all dates when adding
    for (var startTime in finalStartTimes) {
      final endTime = startTime.add(duration);
      final conflicts = await widget.client.checkForConflicts(
        startTime: startTime,
        endTime: endTime,
        excludeEventId: null,
      );

      if (conflicts.isNotEmpty && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => _buildThemedDialog(
            title: 'Conflict Detected',
            content: 'One or more sessions overlap with existing events on ${DateFormat('MMM dd').format(startTime)}. Add anyway?',
            cancelText: 'Cancel',
            confirmText: 'Add Anyway',
          ),
        );
        if (confirm != true) {
            setState(() => _isLoading = false);
            return;
        }
        // User confirmed, break out and continue adding
        break;
      }
    }

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
      if (mounted) Navigator.pop(context);
      _showSnackbar('Session(s) added!', Colors.green);
    } else {
      _showSnackbar('Add failed.', errorIndicatorRed);
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
  
  String _getRecurrenceHelpText() {
    final recurrenceOptions = {
      'One-time': null, 
      'Daily': 'RRULE:FREQ=DAILY',
      'Weekly': 'RRULE:FREQ=WEEKLY',
      'Monthly': 'RRULE:FREQ=MONTHLY',
    };
    
    final currentKey = recurrenceOptions.keys.firstWhere(
      (k) => recurrenceOptions[k] == _selectedRecurrence, 
      orElse: () => 'One-time'
    );
    
    switch (currentKey) {
      case 'One-time':
        return 'Session will occur only on the selected date';
      case 'Daily':
        return 'Session repeats every day until the end date';
      case 'Weekly':
        return 'Session repeats every week on this day';
      case 'Monthly':
        return 'Session repeats every month on this date';
      default:
        return '';
    }
  }
  
  Future<void> _showErrorDialog(String title, String content) async {
     return showDialog(
        context: context,
        builder: (context) => _buildThemedDialog(
          title: title,
          content: content,
          cancelText: '',
          confirmText: 'OK',
        ),
     );
  }

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
                fontSize: MediaQuery.of(context).size.width * 0.045,
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Text(
              content,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.035,
                color: secondaryTextGrey,
                height: 1.5,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelText.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelText, style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035, color: secondaryTextGrey)),
                  ),
                if (cancelText.isNotEmpty) SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? errorIndicatorRed : primaryThemeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(confirmText, style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.035)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringEditDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryThemeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_calendar,
                color: primaryThemeColor,
                size: 28,
              ),
            ),
            SizedBox(height: 16),
            
            // Title
            Text(
              'Edit Recurring Session',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            
            // Description
            Text(
              'Choose which occurrences to update',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextGrey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Options
            _buildDialogOption(
              title: 'Only This Session',
              subtitle: 'Update just this one',
              icon: Icons.event,
              color: primaryThemeColor,
              onTap: () => Navigator.of(context).pop('this'),
            ),
            SizedBox(height: 10),
            _buildDialogOption(
              title: 'This & Future Sessions',
              subtitle: 'Update this and upcoming',
              icon: Icons.event_repeat,
              color: accentThemeColor,
              onTap: () => Navigator.of(context).pop('future'),
            ),
            SizedBox(height: 10),
            _buildDialogOption(
              title: 'All Sessions',
              subtitle: 'Update entire series',
              icon: Icons.calendar_month,
              color: dfDeepTeal,
              onTap: () => Navigator.of(context).pop('all'),
            ),
            SizedBox(height: 16),
            
            // Cancel
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringDeleteDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: errorIndicatorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: errorIndicatorRed,
                size: 28,
              ),
            ),
            SizedBox(height: 16),
            
            // Title
            Text(
              'Delete Recurring Session',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            
            // Description
            Text(
              'Choose which occurrences to remove',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextGrey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Options
            _buildDialogOption(
              title: 'Only This Session',
              subtitle: 'Remove just this one',
              icon: Icons.event,
              color: primaryThemeColor,
              onTap: () => Navigator.of(context).pop('this'),
            ),
            SizedBox(height: 10),
            _buildDialogOption(
              title: 'This & Future Sessions',
              subtitle: 'Remove this and upcoming',
              icon: Icons.event_repeat,
              color: Colors.orange[700]!,
              onTap: () => Navigator.of(context).pop('future'),
            ),
            SizedBox(height: 10),
            _buildDialogOption(
              title: 'All Sessions',
              subtitle: 'Remove entire series',
              icon: Icons.calendar_month,
              color: errorIndicatorRed,
              onTap: () => Navigator.of(context).pop('all'),
            ),
            SizedBox(height: 16),
            
            // Cancel
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryTextGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryTextDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: secondaryTextGrey),
          ],
        ),
      ),
    );
  }

  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * baseScreenWidthMultiplier;
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, bool enabled = true}) {
    final accent = primaryThemeColor;
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      prefixIcon: Icon(icon, color: enabled ? accent : secondaryTextGrey),
      filled: true,
      fillColor: enabled ? cardBackground : Colors.grey.shade100,
    );
  }
  
  Future<bool> _onWillPop() async {
      if (_isFormDirty && !_isLoading) {
          final shouldPop = await showDialog<bool>(
             context: context,
             builder: (context) => _buildThemedDialog(
               title: "Unsaved Changes",
               content: "Discard unsaved changes?",
               cancelText: "Cancel",
               confirmText: "Discard",
               isDestructive: true,
             ),
          );
          return shouldPop ?? false;
      }
      return true;
  }

  @override
  Widget build(BuildContext context) {
    final accent = primaryThemeColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final recurrenceOptions = {
      'One-time': null, 
      'Daily': 'RRULE:FREQ=DAILY',
      'Weekly': 'RRULE:FREQ=WEEKLY',
      'Monthly': 'RRULE:FREQ=MONTHLY',
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
         if (didPop) return;
         final shouldPop = await _onWillPop();
         if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: primaryBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(cardBorderRadius)),
              boxShadow: subtleShadow,
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.05, 
                    screenHeight * 0.02, 
                    screenWidth * 0.05, 
                    screenHeight * 0.01
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(width: screenWidth * 0.08),
                      Text(
                        isEditing ? 'Edit Session' : 'Add New Session',
                        style: TextStyle(fontSize: _adaptiveFontSize(0.04), fontWeight: FontWeight.bold, color: primaryTextDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: secondaryTextGrey),
                        onPressed: () async {
                            if (await _onWillPop()) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey),
                
                // Scrollable Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    onChanged: _markDirty,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        screenWidth * 0.05,
                        screenHeight * 0.02,
                        screenWidth * 0.05,
                        screenHeight * 0.02 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            initialValue: isEditing ? _title : null,
                            decoration: _inputDecoration(
                              label: 'Session Title',
                              icon: Icons.title,
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
                            onSaved: (value) => _title = value!,
                            onChanged: (value) => _markDirty(),
                          ),
                          SizedBox(height: screenHeight * 0.015), 
                          
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
                                _markDirty();
                              });
                            },
                          ),
                          SizedBox(height: screenHeight * 0.015), 
                          
                          DropdownButtonFormField<String>(
                            value: recurrenceOptions.keys.firstWhere(
                                (k) => recurrenceOptions[k] == _selectedRecurrence, 
                                orElse: () => 'One-time'
                            ),
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
                                if (_selectedRecurrence != null && _selectedRecurrence != 'custom') {
                                  _selectedDates = [_startDate];
                                } else if (key == 'Custom') {
                                  _selectedDates = [_startDate];
                                } else {
                                  _selectedDates = [_startDate];
                                }
                                _markDirty();
                              });
                            },
                          ),
                          SizedBox(height: screenHeight * 0.008),
                          Padding(
                            padding: EdgeInsets.only(left: 12, right: 12),
                            child: Text(
                              _getRecurrenceHelpText(),
                              style: TextStyle(
                                fontSize: _adaptiveFontSize(0.028),
                                color: secondaryTextGrey.withOpacity(0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          
                          Row(
                              children: [
                                  Expanded(
                                      child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            (isRecurringMode || (isEditing && _selectedRecurrence != null)) 
                                                ? 'Start Date' 
                                                : 'Session Date',
                                            style: TextStyle(fontSize: _adaptiveFontSize(0.032))
                                          ),
                                          subtitle: Text(
                                              DateFormat('MMM dd, yyyy').format(_startDate),
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.032))), 
                                          leading: Icon(
                                            Icons.calendar_today,
                                            color: accent,
                                            size: _adaptiveFontSize(0.045)
                                          ),
                                          onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: _startDate,
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime.now().add(const Duration(days: 365*3)),
                                                builder: (context, child) => Theme(
                                                  data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: primaryThemeColor)), 
                                                  child: child!
                                                ),
                                              );
                                              if (date != null) setState(() { _startDate = date; _selectedDates = [date]; _isFormDirty = true; });
                                          },
                                      ),
                                  ),
                                  
                                  if (isRecurringMode || (isEditing && _selectedRecurrence != null))
                                      Expanded(
                                          child: ListTile(
                                              contentPadding: EdgeInsets.only(left: screenWidth * 0.01), 
                                              title: Text('Repeat Until', style: TextStyle(fontSize: _adaptiveFontSize(0.032))),
                                              subtitle: Text(DateFormat('MMM dd, yyyy').format(_recurrenceEndDate!),
                                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: _adaptiveFontSize(0.032))), 
                                              onTap: () async {
                                                  final date = await showDatePicker(
                                                    context: context,
                                                    initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
                                                    firstDate: _startDate,
                                                    lastDate: _startDate.add(const Duration(days: 365)),
                                                    builder: (context, child) => Theme(
                                                      data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: primaryThemeColor)), 
                                                      child: child!
                                                    ),
                                                  );
                                                  if (date != null) setState(() { _recurrenceEndDate = date; _isFormDirty = true; });
                                              },
                                          ),
                                      ),
                              ],
                          ),
                          const Divider(), 
                
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
                                      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: primaryThemeColor)), child: child!),
                                    );
                                    if (time != null) setState(() { _startTime = time; _isFormDirty = true; });
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
                                      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: primaryThemeColor)), child: child!),
                                    );
                                    if (time != null) setState(() { _endTime = time; _isFormDirty = true; });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          _isLoading
                              ? Center(child: Padding(
                              padding: EdgeInsets.all(screenWidth * 0.025),
                              child: CircularProgressIndicator(color: accent)))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
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
                                    onPressed: () async {
                                       if (await _onWillPop()) Navigator.pop(context);
                                    },
                                    child: Text('Cancel', style: TextStyle(color: secondaryTextGrey, fontSize: _adaptiveFontSize(0.034))),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Extra bottom padding for Android nav bar
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// MULTI-DATE PICKER DIALOG
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
    _selectedDates = widget.initialDates.map((d) => DateTime(d.year, d.month, d.day)).toList();
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    if (day.isBefore(DateTime.now().subtract(Duration(days: 1)))) return;

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
                enabledDayPredicate: (day) {
                   return !day.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                },
                onDaySelected: _onDaySelected,
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: primaryThemeColor.withOpacity(0.3), shape: BoxShape.circle),
                  disabledTextStyle: TextStyle(color: Colors.grey),
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
