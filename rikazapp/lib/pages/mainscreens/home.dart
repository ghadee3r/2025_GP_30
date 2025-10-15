import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 1. API Client Setup (The brain for all Calendar interactions)
// -----------------------------------------------------------------------------

// Use the explicit string literal for the full read/write scope to avoid build errors.
const List<String> _scopes = <String>[
  'https://www.googleapis.com/auth/calendar', // Full Read/Write access scope
  'email',
];

class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  calendar.CalendarApi? calendarApi;

  bool get isConnected => calendarApi != null;

  // Handles Google Sign-In and client initialization
  Future<bool> signIn() async {
    try {
      // Sign-in will prompt the user to choose an account
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
  
  // Signs out the user and clears the client
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    calendarApi = null;
  }

  // Fetches upcoming events from the user's primary calendar
  Future<List<calendar.Event>> fetchUpcomingEvents() async {
    if (calendarApi == null) return [];

    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 10, // Fetch up to 10 events
        timeMin: DateTime.now().toUtc(),
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

class _HomePageState extends State<HomePage> {
  // Calendar API State and Client
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false; // Tracks Google Calendar API status
  bool _isSigningIn = false;
  List<calendar.Event> _events = [];

  // Existing Focus State
  String selectedPreset = 'Choose Preset';
  int selectedModeIndex = 0; 
  bool hasSelectedMode = false;
  
  // Existing placeholder for custom Rikaz connection status
  bool isRikazToolConnected = false; 
  // FIX: Declare the missing isLoading variable for the Rikaz tool connection
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

  // Refreshes the event list from Google Calendar (Two-way sync: Read)
  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) return;
    
    final fetchedEvents = await _client.fetchUpcomingEvents();
    setState(() {
      _events = fetchedEvents;
    });
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
      _fetchSchedule();
      _showSnackbar('Successfully connected to Google Calendar! 🎉', Colors.green);
    } else {
      _showSnackbar('Connection failed or cancelled. 😔 Check network.', Colors.red);
    }
  }
  
  // Handles Google Calendar Sign-out
  Future<void> _handleCalendarSignOut() async {
    await _client.signOut();
    setState(() {
      _isCalendarConnected = false;
      _events = [];
    });
    _showSnackbar('Disconnected from Google. 👋', Colors.blueGrey);
  }

  // Placeholder for Rikaz Tool Connect (using SlideAction)
  Future<void> handleConnect() async {
    // FIX: isLoading is now defined in _HomePageState
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
    final selectedTitle = modes[selectedModeIndex]['title']!;
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

  // Shows the "cute overlay" for adding/deleting events
  void _showEventOverlay({calendar.Event? eventToEdit}) {
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
            onEventUpdated: _fetchSchedule, // Callback to trigger two-way sync: Read
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // الخلفية
          Positioned.fill(
            child: Image.asset(
              'assets/images/BlueHaze.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // الورقة القابلة للسحب
          DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Stack(
                children: [
                  // طبقة بلور
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(color: Colors.white.withOpacity(0.75)),
                      ),
                    ),
                  ),

                  // المحتوى
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // المقبض
                          Center(
                            child: Container(
                              width: 54,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8, bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                          // الشعار
                          const Center(
                            child: CircleAvatar(
                              radius: 65,
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  AssetImage('assets/images/RikazLogo.png'),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ترحيب
                          const Text(
                            'Welcome back, User!',
                            style:
                                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Ready for a productive day?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),

                          // ---------------------------------------------------
                          // ORIGINAL RIKAZ TOOL CARD (Retained your original logic)
                          // ---------------------------------------------------
                          Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: isRikazToolConnected
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Rikaz Tools Connected',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4f46e5),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'You can now unlock custom presets and advanced features.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Connect Rikaz Tools',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Connect to unlock custom presets and advanced features',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // زر السحب للاتصال
                                        Builder(
                                          builder: (context) {
                                            final key =
                                                GlobalKey<SlideActionState>();
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8.0),
                                              child: SlideAction(
                                                key: key,
                                                text: "Slide to Connect",
                                                textStyle: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                innerColor: Colors.white,
                                                outerColor:
                                                    const Color(0xFF4f46e5),
                                                sliderButtonIcon: const Icon(
                                                  Icons.wifi,
                                                  color: Colors.black,
                                                  size: 15,
                                                ),
                                                height: 40,
                                                onSubmit: isLoading ? null : () async {
                                                  await handleConnect();
                                                  // اختياري: رجّع السلايدر
                                                  Future.delayed(
                                                    const Duration(seconds: 1),
                                                    () => key.currentState?.reset(),
                                                  );
                                                  return null;
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ---------------------------------------------------
                          // 3. GOOGLE CALENDAR CONNECT SECTION
                          // ---------------------------------------------------
                          _buildGoogleConnectSection(),
                          
                          const SizedBox(height: 24),

                          // البداية
                          const Text(
                            'Start Focus Session',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // اختيار الـpreset
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => ListView(
                                shrinkWrap: true,
                                children: presets
                                    .map((p) => ListTile(
                                          title: Text(p),
                                          onTap: () => handlePresetSelect(p),
                                        ))
                                    .toList(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE6E2DC),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedPreset,
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // اختيار الـMode (بطاقات زرقاء)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children:
                                List.generate(modes.length, (index) {
                              final mode = modes[index];
                              final isSelected =
                                  selectedModeIndex == index;

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedModeIndex = index;
                                      hasSelectedMode = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    height: 100,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4f46e5)
                                          : Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4f46e5)
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4f46e5)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          mode['title']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          mode['desc']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 24),

                          // زر Set Session
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: ElevatedButton(
                                onPressed: hasSelectedMode ? handleSetSession : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasSelectedMode
                                      ? const Color(0xFF000000)
                                      : const Color(0xFF535353),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Set Session',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ---------------------------------------------------
                          // 4. UPCOMING SESSIONS LIST (Google Calendar)
                          // ---------------------------------------------------
                          _buildScheduleSection(),
                          
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  // New Widget: Google Connection Status Card
  Widget _buildGoogleConnectSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCalendarConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isCalendarConnected ? Colors.green : Colors.red, width: 1.5),
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
                    color: _isCalendarConnected ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                Text(
                  _isCalendarConnected 
                    ? 'Sessions are synced successfully! ✅'
                    : 'Connect to sync your sessions and manage them directly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
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
                    backgroundColor: Colors.red.shade400,
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
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
        ],
      ),
    );
  }

  // New Widget: Schedule Display Section
  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Add Session Button
            TextButton.icon(
              onPressed: () => _showEventOverlay(),
              icon: const Icon(Icons.add_circle, color: Colors.green),
              label: const Text('Add Session'),
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
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                        endTime != null && startTime is DateTime && endTime is DateTime
                          ? '${DateFormat('MMM d, hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'
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

  const _EventManagementOverlay({
    required this.client,
    required this.onEventUpdated,
    this.eventToEdit,
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
      _title = '';
      _startDate = DateTime(now.year, now.month, now.day);
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
    
    final result = await widget.client.createEvent(
        title: _title,
        startTime: startDateTime,
        endTime: endDateTime,
    );
    
    if (result != null) {
      widget.onEventUpdated();
      Navigator.pop(context);
      _showSnackbar('Event added to Google Calendar! ✨', Colors.green);
    } else {
      _showSnackbar('Add failed. Check console for details.', Colors.red);
    }
    
    setState(() => _isLoading = false);
  }
  
  // Handles the Delete action (Two-way sync: Write)
  Future<void> _handleDelete() async {
    if (!isEditing || widget.eventToEdit!.id == null) return;
    
    setState(() => _isLoading = true);

    final success = await widget.client.deleteEvent(widget.eventToEdit!.id!);
    
    if (success) {
      widget.onEventUpdated();
      Navigator.pop(context);
      _showSnackbar('Event deleted from Google Calendar! 🗑️', Colors.green);
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
        color: Colors.white,
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
            Text(
              isEditing ? 'Delete Session' : 'Add New Session',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 20),
            
            // Title Field
            TextFormField(
              initialValue: isEditing ? _title : null,
              decoration: InputDecoration(
                labelText: 'Session Title',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
                enabled: !isEditing, // Disable input when editing/deleting
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
              leading: const Icon(Icons.calendar_today, color: Colors.lightBlue),
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
                    leading: const Icon(Icons.schedule, color: Colors.green),
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
                    leading: const Icon(Icons.schedule, color: Colors.red),
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
                              backgroundColor: Colors.blue.shade600,
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
