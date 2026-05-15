import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:intl/intl.dart';

// =============================================================================
// THEME DEFINITIONS
// =============================================================================
const Color dfDeepBlue = Color(0xFF7E84D4);
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

const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF8B95A5);

const double cardBorderRadius = 24.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.04),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ];

double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
  const mitigationFactor = 0.9;
  return baseSize / (1.0 + (textScale - 1.0) * mitigationFactor);
}

// =============================================================================
// PROGRESS SCREEN
// =============================================================================

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
 
  DateTime _parseDbTime(String timeStr) {
    String cleanStr = timeStr;
    if (cleanStr.contains('+')) {
      cleanStr = cleanStr.substring(0, cleanStr.indexOf('+'));
    } else if (cleanStr.endsWith('Z')) {
      cleanStr = cleanStr.substring(0, cleanStr.length - 1);
    }
    return DateTime.parse(cleanStr);
  }

  late TabController _tabController;
  int _selectedTabIndex = 0;
  final List<String> tabs = const ['Daily', 'Weekly', 'Monthly'];

  bool _isLoading = true;
  List<Map<String, dynamic>> _allSessions = [];
  DateTime _viewDate = DateTime.now();
  String _primeFilter = 'Overall'; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _viewDate = DateTime.now(); 
        });
      }
    });

    _fetchSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =============================================================================
  // DATABASE FETCHING
  // =============================================================================
  Future<void> _fetchSessions() async {
    try {
      final userId = sb.Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await sb.Supabase.instance.client
          .from('Focus_Session')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      if (mounted) {
        setState(() {
          _allSessions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // =============================================================================
  // DATA CALCULATIONS & FILTERING
  // =============================================================================
  
  List<Map<String, dynamic>> _getSessionsForPeriod(String period) {
    return _allSessions.where((session) {
      final startTimeStr = session['start_time'];
      if (startTimeStr == null) return false;
      
      final start = _parseDbTime(session['start_time']);
      
      if (period == 'Daily') {
        return start.year == _viewDate.year && 
               start.month == _viewDate.month && 
               start.day == _viewDate.day;
      } else if (period == 'Weekly') {
        final DateTime startOfWeek = DateTime(_viewDate.year, _viewDate.month, _viewDate.day)
            .subtract(Duration(days: _viewDate.weekday - 1));
        final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        
        return start.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
               start.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      } else { 
        return start.year == _viewDate.year && start.month == _viewDate.month;
      }
    }).toList();
  }

  String _calculateTotalTime(List<Map<String, dynamic>> sessions) {
    int totalMinutes = 0;
    for (var session in sessions) {
      totalMinutes += (session['actual_duration'] as num?)?.toInt() ?? 0;
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  List<_ChartDataPoint> _getChartData(String period, List<Map<String, dynamic>> sessions) {
    if (period == 'Daily') {
      List<Map<String, dynamic>> m=[], a=[], e=[], n=[];
      int morning = 0, afternoon = 0, evening = 0, night = 0;
      
      for (var s in sessions) {
        final start = _parseDbTime(s['start_time']);
        final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
        
        if (start.hour >= 6 && start.hour < 12) { morning += mins; m.add(s); }
        else if (start.hour >= 12 && start.hour < 17) { afternoon += mins; a.add(s); }
        else if (start.hour >= 17 && start.hour < 22) { evening += mins; e.add(s); }
        else { night += mins; n.add(s); }
      }
      return [
        _ChartDataPoint('Morning', morning, m),
        _ChartDataPoint('Afternoon', afternoon, a),
        _ChartDataPoint('Evening', evening, e),
        _ChartDataPoint('Night', night, n),
      ];
    } else {
      Map<int, int> days = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0}; 
      Map<int, List<Map<String, dynamic>>> daySessions = {1:[], 2:[], 3:[], 4:[], 5:[], 6:[], 7:[]};

      for (var s in sessions) {
        final start = _parseDbTime(s['start_time']);
        final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
        days[start.weekday] = (days[start.weekday] ?? 0) + mins;
        daySessions[start.weekday]!.add(s);
      }
      return [
        _ChartDataPoint('Mon', days[1]!, daySessions[1]!),
        _ChartDataPoint('Tue', days[2]!, daySessions[2]!),
        _ChartDataPoint('Wed', days[3]!, daySessions[3]!),
        _ChartDataPoint('Thu', days[4]!, daySessions[4]!),
        _ChartDataPoint('Fri', days[5]!, daySessions[5]!),
        _ChartDataPoint('Sat', days[6]!, daySessions[6]!),
        _ChartDataPoint('Sun', days[7]!, daySessions[7]!),
      ];
    }
  }

  // =============================================================================
  // INSIGHTS CALCULATIONS (THE PRIME)
  // =============================================================================

  String _getPrimeTimeOfDay(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 'N/A';
    int m = 0, a = 0, e = 0, n = 0;
    for (var s in sessions) {
      final start = _parseDbTime(s['start_time']);
      final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
      if (start.hour >= 6 && start.hour < 12) m += mins;
      else if (start.hour >= 12 && start.hour < 17) a += mins;
      else if (start.hour >= 17 && start.hour < 22) e += mins;
      else n += mins;
    }
    int maxMins = m; String prime = 'Morning';
    if (a > maxMins) { maxMins = a; prime = 'Afternoon'; }
    if (e > maxMins) { maxMins = e; prime = 'Evening'; }
    if (n > maxMins) { maxMins = n; prime = 'Night'; }
    return maxMins == 0 ? 'N/A' : prime;
  }

  String _getPrimeDayOfWeek(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 'N/A';
    Map<int, int> days = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
    for (var s in sessions) {
      final start = _parseDbTime(s['start_time']);
      final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
      days[start.weekday] = (days[start.weekday] ?? 0) + mins;
    }
    int maxMins = -1;
    int bestDay = 1;
    days.forEach((key, value) {
      if (value > maxMins) { maxMins = value; bestDay = key; }
    });
    if (maxMins <= 0) return 'N/A';
    const dayNames = {1:'Monday', 2:'Tuesday', 3:'Wednesday', 4:'Thursday', 5:'Friday', 6:'Saturday', 7:'Sunday'};
    return dayNames[bestDay] ?? 'N/A';
  }

  String _getPrimeSessionType(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 'N/A';
    
    double getScore(String type) {
      var filtered = sessions.where((s) => s['session_type'] == type).toList();
      if (filtered.isEmpty) return -1.0; 
      
      double score = 0;
      for (var s in filtered) {
        if (s['session_status'] == 'completed') score += 1;
        if (s['progress_level'] == 'fully') score += 1;
        if (s['distraction_level'] == 'low') score += 1;
      }
      return score / filtered.length; 
    }

    double pomoScore = getScore('pomodoro');
    double customScore = getScore('custom');

    if (pomoScore < 0 && customScore < 0) return 'N/A';
    if (pomoScore > customScore) return 'Pomodoro';
    if (customScore > pomoScore) return 'Custom';
    return 'Balanced';
  }

  // =============================================================================
  // UI DIALOGS
  // =============================================================================

  void _showDrillDownBottomSheet(String title, List<Map<String, dynamic>> sessions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.filter_list_rounded, color: accentThemeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('$title Sessions', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dfNavyIndigo)),
                  const Spacer(),
                  Text('${sessions.length} total', style: const TextStyle(color: secondaryTextGrey, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _buildSessionHistoryList(sessions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionBreakdownDialog(List<Map<String, dynamic>> sessions) {
    int pomo25Count = sessions.where((s) => s['session_type'] == 'pomodoro' && s['pomodoro_type'] == '25-5').length;
    int pomo50Count = sessions.where((s) => s['session_type'] == 'pomodoro' && s['pomodoro_type'] == '50-10').length;
    int otherPomoCount = sessions.where((s) => s['session_type'] == 'pomodoro' && s['pomodoro_type'] != '25-5' && s['pomodoro_type'] != '50-10').length;
    int customCount = sessions.where((s) => s['session_type'] == 'custom').length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sessions Breakdown', style: TextStyle(color: dfNavyIndigo, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer, color: dfTealCyan),
              title: const Text('Pomodoro (25-5)'),
              trailing: Text('$pomo25Count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: dfTealCyan),
              title: const Text('Pomodoro (50-10)'),
              trailing: Text('$pomo50Count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (otherPomoCount > 0)
              ListTile(
                leading: const Icon(Icons.timer, color: dfTealCyan),
                title: const Text('Pomodoro (Other)'),
                trailing: Text('$otherPomoCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ListTile(
              leading: const Icon(Icons.tune, color: customModeColor), 
              title: const Text('Custom Sessions'),
              trailing: Text('$customCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: dfTealCyan)),
          )
        ],
      ),
    );
  }

  void _showSessionDetailsBottomSheet(Map<String, dynamic> session) {
    final start = _parseDbTime(session['start_time']);
    final dateFormatted = DateFormat('MMM d, yyyy - h:mm a').format(start);
    
    final status = session['session_status'] ?? 'Unknown';
    final type = session['session_type'] ?? 'Unknown';
    final pomoType = session['pomodoro_type'];
    final actualDur = session['actual_duration'] ?? 0;
    final plannedDur = session['planned_duration'] ?? 0;
    
    final dbProgress = session['progress_level'] ?? 'N/A';
    String displayProgress = 'Unknown';
    Color progressColor = secondaryTextGrey;
    if (dbProgress == 'fully') { displayProgress = 'High'; progressColor = Colors.green; }
    else if (dbProgress == 'partially') { displayProgress = 'Medium'; progressColor = Colors.orange; }
    else if (dbProgress == 'barely') { displayProgress = 'Low'; progressColor = Colors.red; }

    final bool isCameraMonitored = session['camera_monitored'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text('Session Details', style: TextStyle(fontSize: adaptiveFontSize(context, 0.05), fontWeight: FontWeight.bold, color: dfNavyIndigo)),
                Text(dateFormatted, style: const TextStyle(color: secondaryTextGrey)),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(child: _detailBox('Status', status.toString().toUpperCase(), status == 'completed' ? Colors.green : Colors.red)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailBox('Duration', '$actualDur / $plannedDur min', customModeColor)),                  
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _detailBox('Type', type == 'pomodoro' ? 'Pomodoro ($pomoType)' : 'Custom', dfTealCyan)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailBox('Progress', displayProgress, progressColor)),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryBackground, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(
                        isCameraMonitored ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        color: isCameraMonitored ? dfTealCyan : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Camera Monitored', style: TextStyle(fontWeight: FontWeight.w600, color: dfNavyIndigo))),
                      Text(isCameraMonitored ? 'Yes' : 'No', style: TextStyle(fontWeight: FontWeight.bold, color: isCameraMonitored ? dfTealCyan : Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: dfNavyIndigo, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: secondaryTextGrey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 15)),
        ],
      ),
    );
  }

  // =============================================================================
  // UI WIDGETS
  // =============================================================================

  Widget _buildCustomTabToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24)
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: _InteractivePill(
              onTap: () {
                setState(() => _selectedTabIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? primaryThemeColor : secondaryTextGrey
                    )
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _navigatePast() {
    setState(() {
      if (tabs[_selectedTabIndex] == 'Daily') {
        _viewDate = _viewDate.subtract(const Duration(days: 1));
      } else if (tabs[_selectedTabIndex] == 'Weekly') {
        _viewDate = _viewDate.subtract(const Duration(days: 7));
      } else {
        _viewDate = DateTime(_viewDate.year, _viewDate.month - 1, 1);
      }
    });
  }

  void _navigateFuture() {
    setState(() {
      if (tabs[_selectedTabIndex] == 'Daily') {
        _viewDate = _viewDate.add(const Duration(days: 1));
      } else if (tabs[_selectedTabIndex] == 'Weekly') {
        _viewDate = _viewDate.add(const Duration(days: 7));
      } else {
        _viewDate = DateTime(_viewDate.year, _viewDate.month + 1, 1);
      }
    });
  }

  bool _canNavigateFuture() {
    final now = DateTime.now();
    if (tabs[_selectedTabIndex] == 'Daily') {
      return _viewDate.year < now.year || (_viewDate.year == now.year && _viewDate.month < now.month) || (_viewDate.year == now.year && _viewDate.month == now.month && _viewDate.day < now.day);
    } else if (tabs[_selectedTabIndex] == 'Weekly') {
      final startOfCurrentWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final startOfViewWeek = DateTime(_viewDate.year, _viewDate.month, _viewDate.day).subtract(Duration(days: _viewDate.weekday - 1));
      return startOfViewWeek.isBefore(startOfCurrentWeek);
    } else {
      return _viewDate.year < now.year || (_viewDate.year == now.year && _viewDate.month < now.month);
    }
  }

  String _getDateHeaderLabel() {
    if (tabs[_selectedTabIndex] == 'Daily') {
      return DateFormat('MMMM d, yyyy').format(_viewDate);
    } else if (tabs[_selectedTabIndex] == 'Weekly') {
      final startOfWeek = DateTime(_viewDate.year, _viewDate.month, _viewDate.day).subtract(Duration(days: _viewDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}';
    } else {
      return DateFormat('MMMM yyyy').format(_viewDate);
    }
  }

  Widget _buildDateNavigator() {
    bool canGoForward = _canNavigateFuture();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _InteractivePill(
            onTap: _navigatePast,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: subtleShadow),
              child: const Icon(Icons.chevron_left_rounded, color: dfNavyIndigo),
            ),
          ),
          Text(_getDateHeaderLabel(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
          _InteractivePill(
            onTap: canGoForward ? _navigateFuture : () {},
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: canGoForward ? Colors.white : Colors.transparent, shape: BoxShape.circle, boxShadow: canGoForward ? subtleShadow : null),
              child: Icon(Icons.chevron_right_rounded, color: canGoForward ? dfNavyIndigo : secondaryTextGrey.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeatmapCard(BuildContext context) {
    final lastDayOfMonth = DateTime(_viewDate.year, _viewDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    Map<int, int> dailyMinutes = {};
    Map<int, List<Map<String, dynamic>>> dailySessions = {}; 

    for (var s in _allSessions) {
      final startTimeStr = s['start_time'];
      if (startTimeStr == null) continue;

      final start = _parseDbTime(startTimeStr);
      
      if (start.month == _viewDate.month && start.year == _viewDate.year) {
        dailyMinutes[start.day] = (dailyMinutes[start.day] ?? 0) + ((s['actual_duration'] as num?)?.toInt() ?? 0);
        
        if (dailySessions[start.day] == null) { dailySessions[start.day] = []; }
        dailySessions[start.day]!.add(s);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(cardBorderRadius), 
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: subtleShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.calendar_month_rounded, color: accentThemeColor, size: 20)
              ),
              const SizedBox(width: 12),
              const Text('Activity Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, 
              mainAxisSpacing: 8, 
              crossAxisSpacing: 8
            ),
            itemCount: daysInMonth, 
            itemBuilder: (context, index) {
              final day = index + 1;
              final mins = dailyMinutes[day] ?? 0;
              final sessionsForDay = dailySessions[day] ?? []; 

              Color boxColor = primaryBackground;
              if (mins > 0 && mins <= 25) boxColor = dfTealCyan.withOpacity(0.3);
              else if (mins > 25 && mins <= 60) boxColor = dfTealCyan.withOpacity(0.65);
              else if (mins > 60 && mins <= 120) boxColor = dfTealCyan;
              else if (mins > 120) boxColor = customModeColor;

              return _InteractivePill(
                onTap: () {
                  if (sessionsForDay.isNotEmpty) {
                    final dateStr = DateFormat('MMMM d').format(DateTime(_viewDate.year, _viewDate.month, day));
                    _showDrillDownBottomSheet(dateStr, sessionsForDay);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: boxColor, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                  ),
                  child: Center(
                    child: Text('$day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mins > 60 ? Colors.white : secondaryTextGrey))
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text('Less', style: TextStyle(fontSize: 11, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dfTealCyan.withOpacity(0.65), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: dfTealCyan, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: customModeColor, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              const Text('More Focus', style: TextStyle(fontSize: 11, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNativeBarChart(List<_ChartDataPoint> data) {
    int maxMins = 0;
    for (var d in data) { if (d.minutes > maxMins) maxMins = d.minutes; }
    if (maxMins == 0) maxMins = 1; 

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((point) {
        final heightFactor = point.minutes / maxMins;
        return Expanded(
          child: _InteractivePill(
            onTap: () {
              if (point.sessions.isNotEmpty) {
                _showDrillDownBottomSheet(point.label, point.sessions);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (point.minutes > 0)
                  Text('${point.minutes}m', style: const TextStyle(fontSize: 10, color: secondaryTextGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: heightFactor > 0 ? heightFactor : 0.05, 
                      child: Container(
                        width: 24, 
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [customModeColor, dfTealCyan]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  point.label, 
                  style: const TextStyle(fontSize: 11, color: secondaryTextGrey, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartCard(BuildContext context, String period, List<Map<String, dynamic>> sessions) {
    final screenHeight = MediaQuery.of(context).size.height;
    final chartData = _getChartData(period, sessions);

    return Container(
      height: screenHeight * 0.3,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(cardBorderRadius), 
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: subtleShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.bar_chart_rounded, color: accentThemeColor, size: 20)
              ),
              const SizedBox(width: 12),
              Text('$period Focus Time', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dfNavyIndigo)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildNativeBarChart(chartData)),
        ],
      ),
    );
  }

  // =============================================================================
  // CONSOLIDATED SUMMARY WIDGET
  // =============================================================================
  Widget _buildConsolidatedSummary(List<Map<String, dynamic>> sessions) {
    final String productiveTime = _calculateTotalTime(sessions);
    
    final completedSessions = sessions.where((s) => s['session_status'] == 'completed').toList();
    final int completedCount = completedSessions.length;
    
    final int high = sessions.where((s) => s['progress_level'] == 'fully').length;
    final int med = sessions.where((s) => s['progress_level'] == 'partially').length;
    final int low = sessions.where((s) => s['progress_level'] == 'barely').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: subtleShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _compactSummaryItem(Icons.access_time_filled_rounded, 'Total Time', productiveTime, dfTealCyan),
              ),
              Container(width: 1.5, height: 40, color: Colors.white), 
              
              Expanded(
                child: _InteractivePill(
                  onTap: () {
                    _showSessionBreakdownDialog(completedSessions);
                  },
                  child: _compactSummaryItem(Icons.check_circle_rounded, 'Completed', '$completedCount', customModeColor),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white, thickness: 1.5, height: 1),
          ),
          
          const Center(
            child: Text('Total Productivity', style: TextStyle(fontSize: 14, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _progressPillCompact('High', high, Colors.green),
              _progressPillCompact('Medium', med, Colors.orange),
              _progressPillCompact('Low', low, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _compactSummaryItem(IconData icon, String label, String value, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dfNavyIndigo)),
          ],
        )
      ],
    );
  }

  Widget _progressPillCompact(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: secondaryTextGrey, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInsightsSection() {
    final now = DateTime.now();
    final primeSessions = _allSessions.where((s) {
      final startTimeStr = s['start_time'];
      if (startTimeStr == null) return false;
      
      final start = _parseDbTime(startTimeStr);

      if (_primeFilter == 'Last Week') {
        return start.isAfter(now.subtract(const Duration(days: 7)));
      } else if (_primeFilter == 'Last Month') {
        return start.isAfter(now.subtract(const Duration(days: 30)));
      }
      return true; 
    }).toList();

    final primeTime = _getPrimeTimeOfDay(primeSessions);
    final primeDay = _getPrimeDayOfWeek(primeSessions);
    final primeType = _getPrimeSessionType(primeSessions);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(cardBorderRadius), 
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: subtleShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: accentThemeColor, size: 20),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('The Prime', style: TextStyle(fontSize: 18, color: dfNavyIndigo, fontWeight: FontWeight.w600)),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryBackground, 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white, width: 2), 
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true, 
                              value: _primeFilter,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: secondaryTextGrey, size: 18),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dfNavyIndigo),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _primeFilter = newValue);
                                }
                              },
                              items: <String>['Last Week', 'Last Month', 'Overall']
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('This is when you\'re most productive!', style: TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          
          if (primeSessions.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: secondaryTextGrey.withOpacity(0.3), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    _primeFilter == 'Last Week'
                        ? "You haven't completed any sessions in the past week.\nFocus more to discover your prime patterns!"
                        : _primeFilter == 'Last Month'
                            ? "You haven't completed any sessions in the past month.\nFocus more to discover your prime patterns!"
                            : "You haven't completed any sessions yet.\nComplete your first session to unlock productivity insights!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: secondaryTextGrey, fontWeight: FontWeight.w500, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24), 
            _insightRow(Icons.wb_sunny_rounded, 'Time of Day', primeTime, dfTealCyan),
            const Divider(color: Colors.white, height: 24, thickness: 1.5),
            _insightRow(Icons.calendar_today_rounded, 'Day of Week', primeDay, customModeColor),
            const Divider(color: Colors.white, height: 24, thickness: 1.5),
            _insightRow(Icons.star_rounded, 'Session Type', primeType, Colors.orangeAccent),
          ],
        ],
      ),
    );
  }

  Widget _insightRow(IconData icon, String title, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w500))),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dfNavyIndigo)),
      ],
    );
  }

  Widget _buildSessionHistoryList(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No sessions for this period.', style: TextStyle(color: secondaryTextGrey, fontSize: 14, fontStyle: FontStyle.italic))),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final start = _parseDbTime(session['start_time']);
        final isCompleted = session['session_status'] == 'completed';
        final color = session['session_type'] == 'pomodoro' ? dfTealCyan : customModeColor;
        
        return _InteractivePill(
          onTap: () => _showSessionDetailsBottomSheet(session),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6), 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: subtleShadow
            ),
            child: Row(
              children: [
                Container(width: 4, height: 40, margin: const EdgeInsets.only(left: 16), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${session['actual_duration'] ?? 0} mins • ${isCompleted ? "Completed" : "Cancelled"}', style: const TextStyle(fontWeight: FontWeight.w600, color: dfNavyIndigo, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(DateFormat('MMM d, h:mm a').format(start), style: const TextStyle(color: secondaryTextGrey, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.only(right: 16.0), child: Icon(Icons.chevron_right_rounded, color: secondaryTextGrey))
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(BuildContext context, String period) {
    final filteredSessions = _getSessionsForPeriod(period);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateNavigator(),
          if (period == 'Monthly')
            _buildHeatmapCard(context)
          else
            _buildChartCard(context, period, filteredSessions),

          const SizedBox(height: 8),
          const Text('Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
          const SizedBox(height: 16),

          _buildConsolidatedSummary(filteredSessions),

          const SizedBox(height: 12),
          _buildInsightsSection(),

          const SizedBox(height: 12),
          const Text('Session History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dfNavyIndigo, letterSpacing: -0.5)),
          const SizedBox(height: 16),

          _buildSessionHistoryList(filteredSessions),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, 
                end: Alignment.bottomCenter, 
                colors: [Color(0xFFF4F7F9), Color(0xFFE5ECEF)]
              )
            )
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text('Your Progress', style: TextStyle(fontSize: 30, fontWeight: FontWeight.normal, color: dfNavyIndigo, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Track your productivity history', style: TextStyle(fontSize: 15, color: secondaryTextGrey, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 24),

                  _buildCustomTabToggle(context),
                  const SizedBox(height: 16),

                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: primaryThemeColor))
                      : TabBarView(
                          controller: _tabController,
                          children: tabs.map((period) => _buildTabContent(context, period)).toList(),
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
} 

// =============================================================================
// HELPER CLASSES & COMPONENTS
// =============================================================================

class _ChartDataPoint {
  final String label;
  final int minutes;
  final List<Map<String, dynamic>> sessions; 
  _ChartDataPoint(this.label, this.minutes, this.sessions);
}

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
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0, 
        duration: const Duration(milliseconds: 150), 
        curve: Curves.easeOutCubic, 
        child: widget.child
      ),
    );
  }
}