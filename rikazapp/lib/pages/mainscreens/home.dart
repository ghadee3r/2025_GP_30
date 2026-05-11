import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dart:async';
import 'dart:ui';

enum ScheduleView { all, rikaz }
enum CalendarFormatView { list, month }

// --- MINIMALIST THEME COLORS ---
const Color dfDeepTeal = Color(0xFF1B2536); 
const Color dfTealCyan = Color(0xFF68C29D); 
const Color customModeColor = Color(0xFF7E84D4); 
const Color dfLightSeafoam = Color(0xFFE8F1EC);
const Color dfNavyIndigo = Color(0xFF1B2536);

const Color primaryThemeColor = dfTealCyan;
const Color accentThemeColor = customModeColor;
const Color lightestAccentColor = dfLightSeafoam;

const Color primaryBackground = Color(0xFFF2F6F9); 
const Color cardBackground = Color(0xFFFFFFFF); 
const Color primaryTextDark = Color(0xFF1B2536);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
  BoxShadow(
    color: dfNavyIndigo.withOpacity(0.04),
    blurRadius: 30,
    offset: const Offset(0, 10),
  ),
];

Map<String, Color> importanceColors = {
  'High': errorIndicatorRed,
  'Medium': const Color(0xFFF4A261),
  'Low': dfTealCyan,
  'Default': customModeColor,
};

Map<String, String> googleColorMap = {
  'High': '11',
  'Medium': '5',
  'Low': '10',
  'Default': '9',
};

const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/calendar',
  'email',
];

// =============================================================================
// CALENDAR CLIENT
// =============================================================================
class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  calendar.CalendarApi? calendarApi;
  bool get isConnected => calendarApi != null;

  Future<bool> signin() async {
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
      return await calendarApi!.events.get('primary', eventId);
    } catch (e) {
      debugPrint('Error fetching event by ID: $e');
      return null;
    }
  }

  Future<calendar.Event?> getRecurringEventMaster(String recurringEventId) async {
    if (calendarApi == null) return null;
    try {
      return await calendarApi!.events.get('primary', recurringEventId);
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
  }) async {
    if (calendarApi == null) return null;
    try {
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

      return await calendarApi!.events.update(updatedEvent, 'primary', eventId);
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
          private: {'isRikazSession': isRikazSession.toString(), 'importance': importanceKey}
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
          private: {'isRikazSession': isRikazSession.toString(), 'importance': importanceKey}
        ),
      );
      try {
        final createdEvent = await calendarApi!.events.insert(event, 'primary');
        createdEvents.add(createdEvent);
      } catch (e) {
        debugPrint('Error creating event: $e');
        createdEvents.add(null);
      }
    }
    return createdEvents;
  }

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

  Future<bool> deleteRecurringEventFromDate(String recurringEventId, DateTime fromDate) async {
    if (calendarApi == null) return false;
    try {
      final masterEvent = await calendarApi!.events.get('primary', recurringEventId);
      if (masterEvent.recurrence == null || masterEvent.recurrence!.isEmpty) return false;
      
      String rrule = masterEvent.recurrence!.first;
      if (rrule.contains('UNTIL=')) {
        rrule = rrule.split(';UNTIL=')[0];
      }
      final untilDate = fromDate.subtract(const Duration(days: 1)).toUtc();
      final untilString = DateFormat('yyyyMMdd').format(untilDate);
      rrule += ';UNTIL=${untilString}T235959Z';
      
      masterEvent.recurrence = [rrule];
      await calendarApi!.events.update(masterEvent, 'primary', recurringEventId);
      return true;
    } catch (e) {
      debugPrint('Error ending recurring series: $e');
      return false;
    }
  }
}

// =============================================================================
// MAIN HOME PAGE
// =============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;
  List<calendar.Event> _events = [];
  List<calendar.Event> _displayedEvents = [];
  ScheduleView _scheduleView = ScheduleView.all;
  CalendarFormatView _calendarFormatView = CalendarFormatView.list;
  final supabase = sb.Supabase.instance.client;
  String _userName = 'User Name';
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  int? selectedModeIndex;
  bool _isEnterPressed = false; 
  Timer? _autoRefreshTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> modes = [
    {
      'title': 'Pomodoro',
      'desc': 'Structured intervals',
      'badge': '25-5 | 50-10', 
      'color': dfTealCyan,
      'icon': Icons.adjust,
    },
    {
      'title': 'Custom',
      'desc': 'Adaptive duration',
      'badge': 'Free',
      'color': customModeColor,
      'icon': Icons.all_inclusive,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));

    _fetchUserName();
    _client._googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      final wasConnected = _isCalendarConnected;
      if (account != null) {
        _client.signin().then((success) {
          if (success) {
            _fetchSchedule();
            _startAutoRefresh();
            setState(() { _isCalendarConnected = success; });
          }
        });
      } else if (wasConnected) {
        _stopAutoRefresh();
        setState(() {
          _isCalendarConnected = false;
          _events = [];
          _displayedEvents = [];
          _filterEvents();
        });
      }
    });
    _client._googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_client.isConnected) _fetchSchedule();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _client.isConnected) _fetchSchedule();
  }

  Future<void> _fetchUserName() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      String fetchedName = metadata?['full_name'] as String? ?? user.email?.split('@')[0] ?? 'User';
      final formattedName = fetchedName.split(' ').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
      if (mounted) setState(() => _userName = formattedName);
    } else {
      if (mounted) setState(() => _userName = 'Guest');
    }
  }

  void _filterEvents() {
    List<calendar.Event> sourceEvents = _isCalendarConnected ? _events.toList() : [];
    
    sourceEvents = sourceEvents.where((e) {
      final start = e.start?.dateTime?.toLocal() ?? e.start?.date;
      if (start == null) return false;
      
      // BOTH List and Month views now fetch the next 7 days equally
      final endRange = _selectedDay.add(const Duration(days: 7));
      return (isSameDay(start, _selectedDay) || start.isAfter(_selectedDay)) && start.isBefore(endRange);
    }).toList();

    if (_scheduleView == ScheduleView.rikaz) {
      sourceEvents = sourceEvents.where((event) => event.extendedProperties?.private?['isRikazSession'] == 'true').toList();
    }

    _displayedEvents = sourceEvents;
    _displayedEvents.sort((a, b) {
      final timeA = a.start?.dateTime?.toLocal() ?? a.start?.date;
      final timeB = b.start?.dateTime?.toLocal() ?? b.start?.date;
      if (timeA == null || timeB == null) return 0;
      return timeA.compareTo(timeB);
    });
  }

  // --- SPRING ANIMATED DIALOG BUILDER ---
  Future<T?> _showAnimatedDialog<T>({required Widget child}) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
    );
  }

  Future<void> _handleSingleDelete(calendar.Event event) async {
    if (!_client.isConnected || event.id == null) return;
    String? recurringChoice;
    
    if (event.recurringEventId != null) {
      recurringChoice = await _showAnimatedDialog<String>(child: _buildRecurringDeleteDialog());
      if (recurringChoice == null) return;
    }

    final confirmDelete = await _showAnimatedDialog<bool>(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: errorIndicatorRed, size: 36)),
              const SizedBox(height: 20),
              const Text('Delete Session?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              const Text("Are you sure you want to remove this session from your schedule?", textAlign: TextAlign.center, style: TextStyle(color: secondaryTextGrey, fontSize: 14, height: 1.4)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _InteractivePill(onTap: () => Navigator.pop(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Cancel', style: TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600, fontSize: 15)))))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InteractivePill(
                      onTap: () => Navigator.pop(context, true), 
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        decoration: BoxDecoration(color: errorIndicatorRed, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: errorIndicatorRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]), 
                        child: const Center(child: Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)))
                      )
                    )
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmDelete == true) {
      bool success = false;
      if (event.recurringEventId != null && recurringChoice != null) {
        if (recurringChoice == 'this') success = await _client.deleteEvent(event.id!);
        else if (recurringChoice == 'future') success = await _client.deleteRecurringEventFromDate(event.recurringEventId!, event.start!.dateTime!.toLocal());
        else if (recurringChoice == 'all') success = await _client.deleteEvent(event.recurringEventId!);
      } else {
        success = await _client.deleteEvent(event.id!);
      }
      await _fetchSchedule();
      if (mounted) _showSnackbar(success ? 'Session deleted.' : 'Failed to delete session.', success ? dfTealCyan : errorIndicatorRed);
    }
  }

  void _setScheduleView(ScheduleView view) {
    setState(() { _scheduleView = view; _filterEvents(); });
  }

  void _setCalendarFormatView(CalendarFormatView view) {
    setState(() { _calendarFormatView = view; if (view == CalendarFormatView.list) _filterEvents(); });
  }

  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) {
      if (mounted) setState(() { _events = []; _filterEvents(); });
      return;
    }
    final fetchedEvents = await _client.fetchUpcomingEvents();
    if (mounted) setState(() { _events = fetchedEvents; _filterEvents(); });
  }

  Future<void> _handleCalendarSignin() async {
    if (_isCalendarConnected) return;
    setState(() { _isSigningIn = true; });
    final success = await _client.signin();
    if (!mounted) return;
    setState(() { _isCalendarConnected = success; _isSigningIn = false; });
    if (success) {
      await _fetchSchedule();
      _startAutoRefresh();
      if (mounted) _showSnackbar('Connected!', dfTealCyan);
    } else {
      if (mounted) _showSnackbar('Connection failed.', errorIndicatorRed);
    }
  }

  Future<void> _handleCalendarSignOut() async {
    _stopAutoRefresh();
    await _client.signOut();
    setState(() { _isCalendarConnected = false; _events = []; _displayedEvents = []; });
    _showSnackbar('Disconnected.', dfNavyIndigo);
    _filterEvents();
  }

  // --- Disconnect Confirmation Dialog ---
  Future<void> _promptDisconnect() async {
    final confirm = await _showAnimatedDialog<bool>(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.link_off_rounded, color: errorIndicatorRed, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Disconnect Calendar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              const Text("You will no longer see your Google Calendar events in Rikaz.", textAlign: TextAlign.center, style: TextStyle(color: secondaryTextGrey, fontSize: 14, height: 1.4)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _InteractivePill(onTap: () => Navigator.pop(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Cancel', style: TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600, fontSize: 15)))))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InteractivePill(
                      onTap: () => Navigator.pop(context, true), 
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        decoration: BoxDecoration(color: errorIndicatorRed, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: errorIndicatorRed.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]), 
                        child: const Center(child: Text('Disconnect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)))
                      )
                    )
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      _handleCalendarSignOut();
    }
  }

  void handleSetSession() {
    if (selectedModeIndex == null) return;
    Navigator.of(context).pushNamed('/SetSession');
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
  }

  void _onMonthDayTapped(DateTime day) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (day.isBefore(today)) { _showSnackbar('Cannot select past dates.', errorIndicatorRed); return; }
    setState(() { _selectedDay = day; _focusedDay = day; _filterEvents(); });
  }

  void _showEventOverlay({calendar.Event? eventToEdit, DateTime? selectedDate}) {
    if (!_client.isConnected && eventToEdit == null) {
      _showSnackbar('Please connect to Google Calendar first.', errorIndicatorRed);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EventManagementOverlay(client: _client, eventToEdit: eventToEdit, onEventUpdated: _fetchSchedule, initialDate: selectedDate, allEvents: _events),
      ),
    );
  }

  void _showSessionOptionsModal(calendar.Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text(event.summary ?? 'Session Options', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
            const SizedBox(height: 24),
            _InteractivePill(
              onTap: () { Navigator.pop(context); _showEventOverlay(eventToEdit: event); },
              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.edit_rounded, color: dfTealCyan), SizedBox(width: 16), Text('Edit Session', style: TextStyle(color: dfTealCyan, fontWeight: FontWeight.w600, fontSize: 15))])),
            ),
            const SizedBox(height: 12),
            _InteractivePill(
              onTap: () { Navigator.pop(context); _handleSingleDelete(event); },
              child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.delete_outline_rounded, color: errorIndicatorRed), SizedBox(width: 16), Text('Delete Session', style: TextStyle(color: errorIndicatorRed, fontWeight: FontWeight.w600, fontSize: 15))])),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(calendar.Event event) {
    final importanceKey = event.extendedProperties?.private?['importance'];
    return importanceColors[importanceKey] ?? importanceColors['Default']!;
  }

  List<Color> _getEventColorsForDay(DateTime day) {
    if (!_isCalendarConnected) return [];
    final eventsOnDay = _events.where((e) { final start = e.start?.dateTime?.toLocal() ?? e.start?.date; return start != null && isSameDay(day, start); }).toList();
    final uniqueImportanceKeys = eventsOnDay.map((e) => e.extendedProperties?.private?['importance'] ?? 'Default').toSet();
    return uniqueImportanceKeys.map((key) => importanceColors[key] ?? importanceColors['Default']!).toList();
  }
  
  Widget _buildGreetingHeader() {
    String dateStr = DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase();
    
    // Determine the time of day
    final hour = DateTime.now().hour;
    String greeting = 'Good morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17) {
      greeting = 'Good evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextGrey, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            '$greeting, $_userName', 
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.normal, color: dfNavyIndigo, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text('Reclaim your depth.', style: TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _buildCentralCircle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final size = screenWidth * 0.55; 
    bool isActive = selectedModeIndex != null;
    Color baseColor = isActive ? modes[selectedModeIndex!]['color'] : Colors.grey.shade400;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          double currentScale = _isEnterPressed ? 0.90 : (isActive ? _pulseAnimation.value : 1.0);
          double glowSpread = isActive ? (_pulseAnimation.value * 25) : 0;

          return GestureDetector(
            onTapDown: (_) { if (isActive) setState(() => _isEnterPressed = true); },
            onTapUp: (_) { if (isActive) { setState(() => _isEnterPressed = false); Future.delayed(const Duration(milliseconds: 150), handleSetSession); } },
            onTapCancel: () { if (isActive) setState(() => _isEnterPressed = false); },
            child: Transform.scale(
              scale: currentScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? baseColor.withOpacity(0.20) : Colors.grey.shade200,
                  boxShadow: isActive ? [BoxShadow(color: baseColor.withOpacity(0.3), blurRadius: 50, spreadRadius: glowSpread)] : subtleShadow,
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: size * 0.55, 
                    height: size * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [baseColor.withOpacity(0.65), baseColor]) : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
                      boxShadow: isActive && !_isEnterPressed ? [BoxShadow(color: baseColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : [],
                    ),
                    child: Center(
                      child: isActive 
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36), SizedBox(height: 2), Text('START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2.0, fontSize: 11))])
                        : Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildModeCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: List.generate(modes.length, (index) {
          final mode = modes[index];
          final isSelected = selectedModeIndex == index;
          final hasSelection = selectedModeIndex != null;
          final color = mode['color'] as Color;

          return _InteractivePill(
            onTap: () => setState(() => selectedModeIndex = index),
            child: AnimatedOpacity(
              opacity: (!hasSelection || isSelected) ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isSelected ? color.withOpacity(0.3) : Colors.transparent, width: 1.5),
                  boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))] : [],
                ),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(mode['icon'], color: color, size: 22)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(mode['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: dfNavyIndigo)),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(mode['badge'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(mode['desc'], style: const TextStyle(color: secondaryTextGrey, fontSize: 13, fontWeight: FontWeight.w400)),
                        ],
                      ),
                    ),
                    Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? color : Colors.transparent, border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.5)), child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null)
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScheduleSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Schedule', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
              _buildViewToggle(), 
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildGoogleConnectPanel(),
          SizedBox(height: screenHeight * 0.02),
          if (_calendarFormatView == CalendarFormatView.month) _buildMonthCalendarView(screenHeight) else _buildListView(screenHeight),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    Widget textTab(CalendarFormatView view, String label) {
      final isSelected = _calendarFormatView == view;
      return GestureDetector(
        onTap: () => _setCalendarFormatView(view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? dfNavyIndigo : Colors.transparent, width: 2))),
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? dfNavyIndigo : secondaryTextGrey)),
        ),
      );
    }
    return Row(children: [textTab(CalendarFormatView.list, 'List'), const SizedBox(width: 16), textTab(CalendarFormatView.month, 'Month')]);
  }

  Widget _buildScheduleToggle() {
    Widget textTab(ScheduleView view, String label) {
      final isSelected = _scheduleView == view;
      return _InteractivePill(
        onTap: () => _setScheduleView(view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.8) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? primaryThemeColor : secondaryTextGrey)),
        ),
      );
    }
    return Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(24)), child: Row(mainAxisSize: MainAxisSize.min, children: [textTab(ScheduleView.all, 'All Calendar'), textTab(ScheduleView.rikaz, 'Rikaz Sessions')]));
  }

  Widget _buildMinimalAddButton() {
    return _InteractivePill(
      onTap: () => _showEventOverlay(selectedDate: _selectedDay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 1.5), boxShadow: subtleShadow),
        child: const Row(children: [Icon(Icons.add_rounded, color: primaryThemeColor, size: 20), SizedBox(width: 6), Text('Add', style: TextStyle(color: primaryThemeColor, fontSize: 14, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  // --- SHARED EVENT LIST UI FOR BOTH CALENDAR AND LIST VIEWS ---
  Widget _buildEventList(double screenHeight) {
    if (!_isCalendarConnected) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.05), 
          child: const Text(
            'Connect Google Calendar to see your upcoming sessions.', 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 14, color: secondaryTextGrey)
          )
        )
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text('Upcoming Sessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dfNavyIndigo)),
        ),
        _displayedEvents.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03), 
                child: const Text('No sessions found for the next 7 days.', style: TextStyle(fontStyle: FontStyle.italic, color: secondaryTextGrey, fontSize: 14))
              )
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
                return _buildSessionCard(event: event, color: _getEventColor(event), startTime: startTime, endTime: endTime); 
              }
            ),
      ],
    );
  }

  Widget _buildMonthCalendarView(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white)),
          padding: const EdgeInsets.all(8),
          child: TableCalendar(
            locale: 'en_US', firstDay: DateTime.now().subtract(const Duration(days: 365)), lastDay: DateTime.now().add(const Duration(days: 365)), focusedDay: _focusedDay, currentDay: DateTime.now(),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dfNavyIndigo), leftChevronIcon: Icon(Icons.chevron_left, color: secondaryTextGrey), rightChevronIcon: Icon(Icons.chevron_right, color: secondaryTextGrey)),
            calendarFormat: CalendarFormat.month,
            calendarStyle: CalendarStyle(todayDecoration: BoxDecoration(color: accentThemeColor.withOpacity(0.2), shape: BoxShape.circle), selectedDecoration: const BoxDecoration(color: primaryThemeColor, shape: BoxShape.circle), outsideDaysVisible: false, weekendTextStyle: TextStyle(color: dfNavyIndigo.withOpacity(0.6)), defaultTextStyle: const TextStyle(color: dfNavyIndigo), disabledTextStyle: TextStyle(color: Colors.grey.withOpacity(0.4))),
            enabledDayPredicate: (day) => !day.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) => _onMonthDayTapped(selectedDay),
            eventLoader: _getEventColorsForDay,
            calendarBuilders: CalendarBuilders(markerBuilder: (context, day, colors) {
              if (colors.isEmpty) return const SizedBox.shrink();
              return Positioned(bottom: 6, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(colors.length, (index) => Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: colors[index] as Color, shape: BoxShape.circle)))));
            }),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildScheduleToggle(), _buildMinimalAddButton()]),
        SizedBox(height: screenHeight * 0.02),
        // Use the unified list
        _buildEventList(screenHeight),
      ],
    );
  }

  Widget _buildListView(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateRibbon(selectedDay: _selectedDay, onDaySelected: (day) => setState(() { _selectedDay = day; _focusedDay = day; _filterEvents(); })),
        SizedBox(height: screenHeight * 0.03),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildScheduleToggle(), _buildMinimalAddButton()]),
        SizedBox(height: screenHeight * 0.02),
        // Use the unified list
        _buildEventList(screenHeight),
      ],
    );
  }

  Widget _buildSessionCard({required calendar.Event event, required Color color, required DateTime startTime, DateTime? endTime}) {
    return _InteractivePill(
      onTap: () => _isCalendarConnected && event.id != null ? _showSessionOptionsModal(event) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 1.5), boxShadow: subtleShadow),
        child: Row(
          children: [
            Container(width: 4, height: 40, margin: const EdgeInsets.only(left: 16), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.summary ?? 'Untitled Session', style: const TextStyle(fontWeight: FontWeight.w600, color: dfNavyIndigo, fontSize: 15), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      endTime != null 
                        ? '${DateFormat('EEE, MMM d').format(startTime)}  •  ${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}' 
                        : '${DateFormat('EEE, MMM d').format(startTime)}  •  ${DateFormat('h:mm a').format(startTime)}', 
                      style: const TextStyle(color: secondaryTextGrey, fontSize: 12, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
            ),
            if (_isCalendarConnected && event.id != null)
              Padding(padding: const EdgeInsets.only(right: 16.0), child: Icon(Icons.more_horiz_rounded, color: secondaryTextGrey.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  // --- CONNECT/DISCONNECT GOOGLE CALENDAR PANEL ---
  Widget _buildGoogleConnectPanel() {
    final isConn = _isCalendarConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isConn ? Icons.calendar_today_rounded : Icons.event_busy_rounded, 
                  color: isConn ? primaryThemeColor : secondaryTextGrey, 
                  size: 20
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConn ? 'Google Calendar Connected' : 'Google Calendar Disconnected', 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dfNavyIndigo), 
                    overflow: TextOverflow.ellipsis
                  )
                ),
              ]
            ),
          ),
          const SizedBox(width: 8),
          _InteractivePill(
            onTap: _isSigningIn ? () {} : (isConn ? _promptDisconnect : _handleCalendarSignin),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isConn ? errorIndicatorRed.withOpacity(0.8) : dfTealCyan, 
                  width: 1.5
                ),
                boxShadow: subtleShadow,
              ),
              child: _isSigningIn 
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: isConn ? errorIndicatorRed : dfTealCyan)) 
                : Text(
                    isConn ? 'Disconnect' : 'Connect', 
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w700, 
                      color: isConn ? errorIndicatorRed : dfTealCyan
                    )
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringDeleteDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: errorIndicatorRed.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.auto_delete_rounded, color: errorIndicatorRed, size: 36)),
            const SizedBox(height: 20),
            const Text('Recurring Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('Choose which occurrences to remove', style: TextStyle(fontSize: 14, color: secondaryTextGrey, height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            _buildDeleteDialogOption(title: 'Only This Session', subtitle: 'Remove just this one', icon: Icons.event_rounded, color: primaryThemeColor, onTap: () => Navigator.of(context).pop('this')),
            const SizedBox(height: 12),
            _buildDeleteDialogOption(title: 'This & Future Sessions', subtitle: 'Remove this and upcoming', icon: Icons.event_repeat_rounded, color: accentThemeColor, onTap: () => Navigator.of(context).pop('future')),
            const SizedBox(height: 12),
            _buildDeleteDialogOption(title: 'All Sessions', subtitle: 'Remove entire series', icon: Icons.calendar_month_rounded, color: dfNavyIndigo, onTap: () => Navigator.of(context).pop('all')),
            const SizedBox(height: 20),
            _InteractivePill(onTap: () => Navigator.of(context).pop(null), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Cancel', style: TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w600))))),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteDialogOption({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return _InteractivePill(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.2), width: 1.5), borderRadius: BorderRadius.circular(16), color: color.withOpacity(0.05)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dfNavyIndigo)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: secondaryTextGrey))])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: secondaryTextGrey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)]))),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreetingHeader(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildCentralCircle(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  Center(child: Text('SELECT A MODE TO AWAKEN', style: TextStyle(color: secondaryTextGrey.withOpacity(0.8), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 16),
                  _buildModeCards(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  _buildScheduleSection(), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _DateRibbon extends StatefulWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  const _DateRibbon({required this.selectedDay, required this.onDaySelected});
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
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _endDate.difference(_startDate).inDays + 1,
        itemBuilder: (context, index) {
          final day = _startDate.add(Duration(days: index));
          final bool isSelected = isSameDay(widget.selectedDay, day);
          final bool isToday = isSameDay(DateTime.now(), day);
          final bool isPast = day.isBefore(today);
          return _InteractivePill(
            onTap: isPast ? () {} : () => widget.onDaySelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 55,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : (isToday ? Colors.white.withOpacity(0.5) : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? primaryThemeColor.withOpacity(0.5) : Colors.transparent, width: 1.5),
                boxShadow: isSelected ? [BoxShadow(color: primaryThemeColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(day), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPast ? secondaryTextGrey.withOpacity(0.5) : (isSelected ? primaryThemeColor : secondaryTextGrey))),
                  const SizedBox(height: 2),
                  Text(DateFormat('d').format(day), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isPast ? secondaryTextGrey.withOpacity(0.5) : dfNavyIndigo)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- GLASSMORPHIC ADD/EDIT EVENT FORM ---
class _EventManagementOverlay extends StatefulWidget {
  final CalendarClient client;
  final calendar.Event? eventToEdit;
  final VoidCallback onEventUpdated;
  final DateTime? initialDate;
  final List<calendar.Event> allEvents;

  const _EventManagementOverlay({required this.client, required this.onEventUpdated, this.eventToEdit, this.initialDate, required this.allEvents});

  @override
  _EventManagementOverlayState createState() => _EventManagementOverlayState();
}

class _EventManagementOverlayState extends State<_EventManagementOverlay> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;
  late String _selectedImportance;
  String? _selectedRecurrence;
  DateTime? _recurrenceEndDate;
  bool _isFormDirty = false;
  String? _masterEventId;

  String? _titleError;
  String? _timeError;
  String? _dateError;

  bool get isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    final now = DateTime.now();
    if (isEditing) {
      _title = widget.eventToEdit!.summary ?? '';
      final start = widget.eventToEdit!.start!.dateTime?.toLocal() ?? now;
      final end = widget.eventToEdit!.end!.dateTime?.toLocal() ?? now.add(const Duration(hours: 1));
      _startDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(end);
      _selectedImportance = widget.eventToEdit!.extendedProperties?.private?['importance'] ?? 'Default';
      
      if (widget.eventToEdit!.recurringEventId != null) {
        _masterEventId = widget.eventToEdit!.recurringEventId;
        _selectedRecurrence = 'RRULE:FREQ=DAILY'; 
      }
      if (mounted) setState(() {});
    } else {
      final selectedDate = widget.initialDate ?? now;
      _title = '';
      _startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      _startTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)));
      _endTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
      _selectedImportance = 'Default';
    }
  }

  void _markDirty() { if (!_isFormDirty) setState(() => _isFormDirty = true); }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) => DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<bool?> _showMinimalDialog({required String title, required String content, String? confirmText, String? cancelText, bool isError = false}) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: (isError ? errorIndicatorRed : dfNavyIndigo).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: isError ? errorIndicatorRed : dfNavyIndigo, size: 36),
                ),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text(content, textAlign: TextAlign.center, style: const TextStyle(color: secondaryTextGrey, fontSize: 14, height: 1.4)),
                const SizedBox(height: 32),
                Row(
                  children: [
                    if (cancelText != null)
                      Expanded(child: _InteractivePill(onTap: () => Navigator.pop(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: Center(child: Text(cancelText, style: const TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600, fontSize: 15)))))),
                    if (cancelText != null) const SizedBox(width: 16),
                    Expanded(
                      child: _InteractivePill(
                        onTap: () => Navigator.pop(context, true), 
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16), 
                          decoration: BoxDecoration(
                            color: isError ? errorIndicatorRed : dfNavyIndigo, 
                            borderRadius: BorderRadius.circular(16), 
                            boxShadow: [BoxShadow(color: (isError ? errorIndicatorRed : dfNavyIndigo).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                          ), 
                          child: Center(child: Text(confirmText ?? 'OK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)))
                        )
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(scale: Curves.easeOutBack.transform(anim.value), child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    
    setState(() {
      _titleError = null;
      _timeError = null;
      _dateError = null;
      _isLoading = true;
    });

    bool hasValidationErrors = false;

    if (_title.trim().isEmpty) {
      _titleError = 'Please enter a name for your session.';
      hasValidationErrors = true;
    }

    final startDateTime = _combineDateTime(_startDate, _startTime);
    DateTime endDateTime = _combineDateTime(_startDate, _endTime);

    // Midnight crossover fix 
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    if (endDateTime.isAtSameMomentAs(startDateTime)) {
      _timeError = 'Session duration cannot be zero.';
      hasValidationErrors = true;
    }

    if (startDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      _dateError = 'Sessions cannot be scheduled in the past.';
      hasValidationErrors = true;
    }

    if (hasValidationErrors) {
      setState(() => _isLoading = false);
      return;
    }

    final conflicts = await widget.client.checkForConflicts(
      startTime: startDateTime,
      endTime: endDateTime,
      excludeEventId: isEditing ? (_masterEventId ?? widget.eventToEdit?.id) : null,
    );
    
    if (conflicts.isNotEmpty && mounted) {
      final confirm = await _showMinimalDialog(
        title: 'Schedule Conflict',
        content: 'This session overlaps with an existing event. Add it anyway?',
        confirmText: 'Add Anyway',
        cancelText: 'Cancel',
      );
      if (confirm != true) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (isEditing) {
      final updatedEvent = await widget.client.updateEvent(eventId: _masterEventId ?? widget.eventToEdit!.id!, title: _title, startTime: startDateTime, endTime: endDateTime, importanceKey: _selectedImportance, recurrenceRule: _selectedRecurrence, recurrenceUntil: _selectedRecurrence != null ? _recurrenceEndDate : null);
      if (updatedEvent != null) { widget.onEventUpdated(); if (mounted) Navigator.pop(context); }
      setState(() => _isLoading = false);
      return;
    }

    final results = await widget.client.createEvents(title: _title, startTimes: [startDateTime], duration: endDateTime.difference(startDateTime), recurrenceRule: _selectedRecurrence, recurrenceUntil: _selectedRecurrence != null ? _recurrenceEndDate : null, importanceKey: _selectedImportance, isRikazSession: true);
    if (results.any((r) => r != null)) { widget.onEventUpdated(); if (mounted) Navigator.pop(context); }
    setState(() => _isLoading = false);
  }

  Widget _buildFormRow({required IconData icon, required String label, required Widget child, Color? iconColor, bool hasError = false, String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: errorText != null ? 6 : 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: hasError ? errorIndicatorRed.withOpacity(0.05) : dfNavyIndigo.withOpacity(0.03), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: hasError ? errorIndicatorRed.withOpacity(0.5) : Colors.white, width: 2)
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (hasError ? errorIndicatorRed : (iconColor ?? dfTealCyan)).withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: hasError ? errorIndicatorRed : (iconColor ?? dfTealCyan), size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: hasError ? errorIndicatorRed : secondaryTextGrey, fontWeight: FontWeight.bold)), child])),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Text(errorText, style: const TextStyle(color: errorIndicatorRed, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              
              TextFormField(
                initialValue: isEditing ? _title : null,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Session Title', 
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5), 
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, errorBorder: InputBorder.none, focusedErrorBorder: InputBorder.none,
                  errorText: _titleError,
                  errorStyle: const TextStyle(color: errorIndicatorRed, fontSize: 12, fontWeight: FontWeight.w600),
                  filled: false, 
                  contentPadding: const EdgeInsets.symmetric(vertical: 8)
                ),
                onChanged: (val) {
                  _title = val;
                  if (_titleError != null) setState(() => _titleError = null);
                  _markDirty();
                },
                onSaved: (val) => _title = val ?? '',
              ),
              const SizedBox(height: 16),

              _InteractivePill(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
                  if (picked != null) setState(() { _startDate = picked; _dateError = null; _markDirty(); });
                },
                child: _buildFormRow(
                  icon: Icons.calendar_today_rounded, label: 'DATE', 
                  hasError: _dateError != null, errorText: _dateError,
                  child: Text(DateFormat('EEEE, MMM d, yyyy').format(_startDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dateError != null ? errorIndicatorRed : dfNavyIndigo))
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InteractivePill(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() { _startTime = picked; _timeError = null; _markDirty(); });
                      },
                      child: _buildFormRow(icon: Icons.access_time_rounded, label: 'START', hasError: _timeError != null, child: Text(_startTime.format(context), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _timeError != null ? errorIndicatorRed : dfNavyIndigo))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InteractivePill(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() { _endTime = picked; _timeError = null; _markDirty(); });
                      },
                      child: _buildFormRow(
                        icon: Icons.timer_rounded, 
                        label: 'END', 
                        iconColor: customModeColor, 
                        hasError: _timeError != null, 
                        child: Text(
                          _endTime.format(context), 
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _timeError != null ? errorIndicatorRed : dfNavyIndigo)
                        )
                      ),
                    ),
                  ),
                ],
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  child: Text(_timeError!, style: const TextStyle(color: errorIndicatorRed, fontSize: 12, fontWeight: FontWeight.w600)),
                ),

              _buildFormRow(
                icon: Icons.flag_rounded, label: 'PRIORITY', iconColor: importanceColors[_selectedImportance],
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedImportance, isDense: true, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: secondaryTextGrey),
                    items: ['High', 'Medium', 'Low', 'Default'].map((String value) => DropdownMenuItem(
                      value: value, 
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: importanceColors[value], shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
                        ],
                      )
                    )).toList(),
                    onChanged: (val) { if (val != null) setState(() { _selectedImportance = val; _markDirty(); }); },
                  ),
                ),
              ),

              _buildFormRow(
                icon: Icons.repeat_rounded, label: 'RECURRENCE', iconColor: Colors.orange,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedRecurrence, isDense: true, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: secondaryTextGrey),
                    items: const [DropdownMenuItem(value: null, child: Text('Does not repeat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dfNavyIndigo))), DropdownMenuItem(value: 'RRULE:FREQ=DAILY', child: Text('Daily', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dfNavyIndigo))), DropdownMenuItem(value: 'RRULE:FREQ=WEEKLY', child: Text('Weekly', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dfNavyIndigo)))],
                    onChanged: (val) => setState(() { _selectedRecurrence = val; _markDirty(); }),
                  ),
                ),
              ),

              if (_selectedRecurrence != null)
                _InteractivePill(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, 
                      initialDate: _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)), 
                      firstDate: _startDate, 
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2))
                    );
                    if (picked != null) setState(() { _recurrenceEndDate = picked; _markDirty(); });
                  },
                  child: _buildFormRow(
                    icon: Icons.event_busy_rounded, 
                    label: 'ENDS ON', 
                    iconColor: errorIndicatorRed, 
                    child: Text(
                      _recurrenceEndDate != null ? DateFormat('EEEE, MMM d, yyyy').format(_recurrenceEndDate!) : 'Select end date', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _recurrenceEndDate != null ? dfNavyIndigo : errorIndicatorRed)
                    )
                  ),
                ),

              const SizedBox(height: 8),

              _isLoading
                ? const Center(child: CircularProgressIndicator(color: dfNavyIndigo))
                : _InteractivePill(
                    onTap: _handleSave,
                    child: Container(
                      width: double.infinity, 
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: dfNavyIndigo, 
                        borderRadius: BorderRadius.circular(24), 
                        boxShadow: [BoxShadow(color: dfNavyIndigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                      ),
                      child: Center(
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Session', 
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                        )
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SHARED SQUISH PHYSICS COMPONENT ---
class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractivePill({required this.child, required this.onTap});
  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(scale: _isPressed ? 0.94 : 1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic, child: widget.child),
    );
  }
}