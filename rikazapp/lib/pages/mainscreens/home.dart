import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// -----------------------------------------------------------------------------
// Calendar Client
// -----------------------------------------------------------------------------
const List<String> _scopes = [
  'https://www.googleapis.com/auth/calendar',
  'email',
];

class CalendarClient {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  calendar.CalendarApi? calendarApi;

  bool get isConnected => calendarApi != null;

  Future<bool> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) return false;
      final client = await _googleSignIn.authenticatedClient();
      if (client != null) {
        calendarApi = calendar.CalendarApi(client);
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
    try {
      final events = await calendarApi!.events.list(
        'primary',
        maxResults: 20,
        timeMin: DateTime.now().toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items
              ?.where((e) => e.summary != null && e.start != null)
              .toList() ??
          [];
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<bool> deleteEvent(String id) async {
    if (calendarApi == null) return false;
    try {
      await calendarApi!.events.delete('primary', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  Future<bool> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (calendarApi == null) return false;
    final query = calendar.FreeBusyRequest(
      timeMin: startTime.toUtc(),
      timeMax: endTime.toUtc(),
      items: [calendar.FreeBusyRequestItem(id: 'primary')],
    );
    try {
      final response = await calendarApi!.freebusy.query(query);
      final busy = response.calendars?['primary']?.busy;
      return busy != null && busy.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking conflicts: $e');
      return false;
    }
  }

  Future<calendar.Event?> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (calendarApi == null) return null;
    final event = calendar.Event(
      summary: title,
      start:
          calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: 'UTC'),
      end: calendar.EventDateTime(dateTime: endTime.toUtc(), timeZone: 'UTC'),
    );
    try {
      final created = await calendarApi!.events.insert(event, 'primary');
      return created;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return null;
    }
  }
}

// -----------------------------------------------------------------------------
// Home Page
// -----------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CalendarClient _client = CalendarClient();
  bool _isCalendarConnected = false;
  bool _isSigningIn = false;
  List<calendar.Event> _events = [];
  bool isRikazToolConnected = false;
  bool isLoading = false;
  int? selectedModeIndex;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final List<Map<String, String>> modes = const [
    {'title': 'Pomodoro Mode', 'desc': 'Structured focus and break sessions'},
    {'title': 'Custom Mode', 'desc': 'Set your own duration'},
  ];

  @override
  void initState() {
    super.initState();
    _client._googleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) {
        _client.signIn().then((success) {
          if (success) _fetchSchedule();
          setState(() => _isCalendarConnected = success);
        });
      }
    });
    _client._googleSignIn.signInSilently();
  }

  Future<void> _fetchSchedule() async {
    if (!_client.isConnected) {
      setState(() => _events = []);
      return;
    }
    final fetched = await _client.fetchUpcomingEvents();
    setState(() => _events = fetched);
  }

  void _showSnackbar(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  Future<void> handleConnect() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isRikazToolConnected = true;
      isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const accentBlue = Color(0xFF6E5DE7);
    const lavender = Color.fromARGB(255, 174, 165, 255);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color.fromARGB(149, 204, 216, 255),
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

                // each section individually glassy
                _buildGlassSection(_buildRikazConnect(lavender)),
                const SizedBox(height: 20),
                _buildGlassSection(
                    _buildFocusSection(lavender, accentBlue)),
                const SizedBox(height: 20),
                _buildGlassSection(_buildGoogleConnect(lavender)),
                const SizedBox(height: 20),
                _buildGlassSection(_buildScheduleSection(accentBlue)),
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
  // UI Sections
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Start Focus Session',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
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
                              color:
                                  selected ? Colors.white : Colors.black)),
                      const SizedBox(height: 6),
                      Text(mode['desc']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  selected ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedModeIndex == null
                ? null
                : () {
                    final selectedTitle = modes[selectedModeIndex!]['title'];
                    final routeName = (selectedTitle == 'Pomodoro Mode')
                        ? '/pomodoro'
                        : '/custom';
                    Navigator.pushNamed(context, routeName!);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedModeIndex == null ? Colors.grey.shade300 : accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Set Session',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleConnect(Color lavender) {
    final connected = _isCalendarConnected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            connected ? 'Google Calendar Sync' : 'Google Calendar Required',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: connected ? lavender : Colors.black54),
          ),
          Text(
            connected
                ? 'Sessions synced successfully!'
                : 'Connect to sync and manage sessions.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ])),
        const SizedBox(width: 10),
        connected
            ? ElevatedButton.icon(
                onPressed: () async {
                  await _client.signOut();
                  setState(() => _isCalendarConnected = false);
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade400,
                    foregroundColor: Colors.white),
              )
            : ElevatedButton.icon(
                onPressed:
                    _isSigningIn ? null : () async => await _client.signIn(),
                icon: _isSigningIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add_alt_1, size: 18),
                label:
                    Text(_isSigningIn ? 'Connecting...' : 'Connect Google'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: lavender, foregroundColor: Colors.white),
              ),
      ],
    );
  }

  Widget _buildScheduleSection(Color lavender) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Calendar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: TableCalendar(
            locale: 'en_US',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true),
            calendarFormat: CalendarFormat.month,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: lavender.withOpacity(0.6), shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: lavender, shape: BoxShape.circle),
              outsideDaysVisible: false,
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (d, f) =>
                setState(() => {_selectedDay = d, _focusedDay = f}),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Upcoming Sessions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _events.isEmpty
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No upcoming sessions found.',
                        style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic))))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _events.length,
                itemBuilder: (context, i) {
                  final e = _events[i];
                  final s = e.start?.dateTime?.toLocal() ?? e.start?.date;
                  final en = e.end?.dateTime?.toLocal() ?? e.end?.date;
                  if (s == null) return const SizedBox.shrink();
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: lavender,
                          child: Text(DateFormat('d').format(s),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                      title: Text(e.summary ?? 'Untitled'),
                      subtitle: Text(
                          en != null
                              ? '${DateFormat('MMM d, h:mm a').format(s)} - ${DateFormat('h:mm a').format(en)}'
                              : DateFormat('MMM d, yyyy').format(s),
                          style: const TextStyle(color: Colors.black54)),
                      trailing:
                          const Icon(Icons.delete_forever, color: Colors.red),
                    ),
                  );
                }),
      ],
    );
  }
}
