import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:intl/intl.dart';

// =============================================================================
// THEME DEFINITIONS
// =============================================================================

const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

const Color primaryThemeColor = dfDeepTeal;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;

const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);

const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);

const double cardBorderRadius = 16.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

double adaptiveFontSize(BuildContext context, double baseScreenWidthMultiplier) {
  final screenWidth = MediaQuery.of(context).size.width;
  final baseSize = screenWidth * baseScreenWidthMultiplier;
  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
  const mitigationFactor = 0.9;
  return baseSize / (1.0 + (textScaleFactor - 1.0) * mitigationFactor);
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
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final List<String> tabs = const ['Daily', 'Weekly', 'Monthly'];

  bool _isLoading = true;
  List<Map<String, dynamic>> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
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
    final now = DateTime.now();
    return _allSessions.where((session) {
      final startTimeStr = session['start_time'];
      if (startTimeStr == null) return false;
      
      final start = DateTime.parse(startTimeStr);
      
      if (period == 'Daily') {
        return start.year == now.year && start.month == now.month && start.day == now.day;
      } else if (period == 'Weekly') {
        final int currentDay = now.weekday;
        final DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentDay - 1));
        return start.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
      } else { 
        return start.year == now.year && start.month == now.month;
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
      int morning = 0, afternoon = 0, evening = 0, night = 0;
      for (var s in sessions) {
        final start = DateTime.parse(s['start_time']);
        final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
        if (start.hour >= 6 && start.hour < 12) morning += mins;
        else if (start.hour >= 12 && start.hour < 17) afternoon += mins;
        else if (start.hour >= 17 && start.hour < 22) evening += mins;
        else night += mins;
      }
      return [
        _ChartDataPoint('Morning', morning),
        _ChartDataPoint('Afternoon', afternoon),
        _ChartDataPoint('Evening', evening),
        _ChartDataPoint('Night', night),
      ];
    } else {
      // Weekly
      Map<int, int> days = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0}; 
      for (var s in sessions) {
        final start = DateTime.parse(s['start_time']);
        final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
        days[start.weekday] = (days[start.weekday] ?? 0) + mins;
      }
      return [
        _ChartDataPoint('Mon', days[1]!),
        _ChartDataPoint('Tue', days[2]!),
        _ChartDataPoint('Wed', days[3]!),
        _ChartDataPoint('Thu', days[4]!),
        _ChartDataPoint('Fri', days[5]!),
        _ChartDataPoint('Sat', days[6]!),
        _ChartDataPoint('Sun', days[7]!),
      ];
    }
  }

  // =============================================================================
  // UI DIALOGS
  // =============================================================================

  void _showSessionBreakdownDialog(List<Map<String, dynamic>> sessions) {
    int pomoCount = sessions.where((s) => s['session_type'] == 'pomodoro').length;
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
              title: const Text('Pomodoro Sessions'),
              trailing: Text('$pomoCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: dfLightSeafoam),
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
    final start = DateTime.parse(session['start_time']);
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
                    Expanded(child: _detailBox('Duration', '$actualDur / $plannedDur min', dfDeepBlue)),
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
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.all(screenHeight * 0.005),
      decoration: BoxDecoration(color: secondaryTextGrey.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                decoration: BoxDecoration(
                  color: isSelected ? primaryThemeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: primaryThemeColor.withOpacity(0.3), blurRadius: 8)] : null,
                ),
                child: Center(
                  child: Text(tabs[index], style: TextStyle(fontSize: adaptiveFontSize(context, 0.038), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : secondaryTextGrey)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // THE NEW HEATMAP WIDGET
  // -----------------------------------------------------------------------------
  Widget _buildHeatmapCard(BuildContext context, List<Map<String, dynamic>> sessions) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate total minutes for every single day in history
    Map<String, int> dailyMinutes = {};
    for (var s in sessions) {
      if (s['start_time'] == null) continue;
      final start = DateTime.parse(s['start_time']);
      final dateKey = DateFormat('yyyy-MM-dd').format(start);
      final mins = (s['actual_duration'] as num?)?.toInt() ?? 0;
      dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + mins;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Create 15 weeks (105 days) of history grid. Align the start to a Sunday.
    int currentWeekday = today.weekday == 7 ? 0 : today.weekday; 
    DateTime startDate = today.subtract(Duration(days: (14 * 7) + currentWeekday));

    List<Widget> columns = [];
    DateTime currentDay = startDate;

    while (currentDay.isBefore(today) || currentDay.isAtSameMomentAs(today)) {
      List<Widget> squares = [];
      for (int i = 0; i < 7; i++) {
        if (currentDay.isAfter(today)) {
          // Empty invisible squares for future days in the current week
          squares.add(Container(margin: const EdgeInsets.all(2), width: 14, height: 14));
        } else {
          final dateKey = DateFormat('yyyy-MM-dd').format(currentDay);
          final mins = dailyMinutes[dateKey] ?? 0;

          // Determine color based on focus time
          Color boxColor = secondaryTextGrey.withOpacity(0.15); 
          if (mins > 0 && mins <= 25) boxColor = dfLightSeafoam.withOpacity(0.4);
          else if (mins > 25 && mins <= 60) boxColor = dfLightSeafoam;
          else if (mins > 60 && mins <= 120) boxColor = dfTealCyan;
          else if (mins > 120) boxColor = dfDeepTeal;

          squares.add(Container(
            margin: const EdgeInsets.all(2),
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ));
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
      columns.add(Column(children: squares));
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: accentThemeColor, size: 24),
              const SizedBox(width: 8),
              Text('Activity Heatmap', style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), fontWeight: FontWeight.bold, color: primaryTextDark)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side Day Labels (Mon, Wed, Fri) aligned precisely with the boxes
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Column(
                  children: [
                    SizedBox(height: 18), // Sun
                    SizedBox(height: 18, child: Text('Mon', style: TextStyle(fontSize: 10, color: secondaryTextGrey))),
                    SizedBox(height: 18), // Tue
                    SizedBox(height: 18, child: Text('Wed', style: TextStyle(fontSize: 10, color: secondaryTextGrey))),
                    SizedBox(height: 18), // Thu
                    SizedBox(height: 18, child: Text('Fri', style: TextStyle(fontSize: 10, color: secondaryTextGrey))),
                    SizedBox(height: 18), // Sat
                  ],
                ),
              ),
              // The Scrollable Grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // This makes it automatically load scrolled to the most recent day!
                  child: Row(children: columns),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Gradient Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less ', style: TextStyle(fontSize: 10, color: secondaryTextGrey)),
              _legendBox(secondaryTextGrey.withOpacity(0.15)),
              _legendBox(dfLightSeafoam.withOpacity(0.4)),
              _legendBox(dfLightSeafoam),
              _legendBox(dfTealCyan),
              _legendBox(dfDeepTeal),
              const Text(' More', style: TextStyle(fontSize: 10, color: secondaryTextGrey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  // -----------------------------------------------------------------------------
  // BAR CHART FOR DAILY/WEEKLY
  // -----------------------------------------------------------------------------
  Widget _buildNativeBarChart(List<_ChartDataPoint> data) {
    int maxMins = 0;
    for (var d in data) { if (d.minutes > maxMins) maxMins = d.minutes; }
    if (maxMins == 0) maxMins = 1; 

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((point) {
        final heightFactor = point.minutes / maxMins;
        return Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (point.minutes > 0)
                Text('${point.minutes}m', style: const TextStyle(fontSize: 10, color: secondaryTextGrey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                height: 100 * heightFactor + 10, 
                width: 24, 
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [dfDeepTeal, dfTealCyan]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 14,
                child: Text(point.label, style: const TextStyle(fontSize: 11, color: secondaryTextGrey, fontWeight: FontWeight.w600)),
              ),
            ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: accentThemeColor, size: 24),
              const SizedBox(width: 8),
              Text('$period Focus Time', style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), fontWeight: FontWeight.bold, color: primaryTextDark)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildNativeBarChart(chartData)),
        ],
      ),
    );
  }

  Widget _buildInteractiveDataCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: accentThemeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), color: primaryTextDark, fontWeight: FontWeight.w600))),
            if (trailingWidget != null) trailingWidget
            else Text(value, style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), fontWeight: FontWeight.bold, color: primaryThemeColor)),
            if (onTap != null) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.chevron_right, color: secondaryTextGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBreakdown(List<Map<String, dynamic>> sessions) {
    int high = sessions.where((s) => s['progress_level'] == 'fully').length;
    int med = sessions.where((s) => s['progress_level'] == 'partially').length;
    int low = sessions.where((s) => s['progress_level'] == 'barely').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBackground, borderRadius: BorderRadius.circular(cardBorderRadius), boxShadow: subtleShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accentThemeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.track_changes_rounded, color: accentThemeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text('Progress Levels', style: TextStyle(fontSize: adaptiveFontSize(context, 0.04), color: primaryTextDark, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressPill('High', high, Colors.green),
              _progressPill('Medium', med, Colors.orange),
              _progressPill('Low', low, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _progressPill(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: secondaryTextGrey, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSessionHistoryList(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No sessions for this period.', style: TextStyle(color: secondaryTextGrey, fontSize: adaptiveFontSize(context, 0.035)))),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final start = DateTime.parse(session['start_time']);
        final isCompleted = session['session_status'] == 'completed';
        
        return GestureDetector(
          onTap: () => _showSessionDetailsBottomSheet(session),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: primaryBackground, shape: BoxShape.circle),
                  child: Icon(session['session_type'] == 'pomodoro' ? Icons.timer : Icons.tune, color: dfDeepBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM d, h:mm a').format(start), style: const TextStyle(fontWeight: FontWeight.bold, color: dfNavyIndigo)),
                      Text('${session['actual_duration'] ?? 0} mins • ${isCompleted ? "Completed" : "Incomplete"}', style: const TextStyle(color: secondaryTextGrey, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400])
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(BuildContext context, String period) {
    final filteredSessions = _getSessionsForPeriod(period);
    final completedSessions = filteredSessions.where((s) => s['session_status'] == 'completed').toList();
    
    final String productiveTime = _calculateTotalTime(filteredSessions); 
    final String completedCount = completedSessions.length.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SHOW HEATMAP FOR MONTHLY, BAR CHART FOR OTHERS
          if (period == 'Monthly')
            _buildHeatmapCard(context, _allSessions)
          else
            _buildChartCard(context, period, filteredSessions),

          Text('Summary', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
          const SizedBox(height: 16),

          _buildInteractiveDataCard(
            title: 'Total Focus Time',
            value: productiveTime,
            icon: Icons.access_time_filled_rounded,
          ),

          _buildInteractiveDataCard(
            title: 'Sessions Completed',
            value: completedCount,
            icon: Icons.check_circle_rounded,
            onTap: () => _showSessionBreakdownDialog(completedSessions),
          ),

          _buildProgressBreakdown(filteredSessions),

          const Divider(),
          const SizedBox(height: 10),
          Text('Session History', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
          const SizedBox(height: 10),

          _buildSessionHistoryList(filteredSessions),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final proportionalPadding = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        title: Text('Progress', style: TextStyle(fontSize: adaptiveFontSize(context, 0.045), fontWeight: FontWeight.bold, color: primaryTextDark)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: proportionalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Progress', style: TextStyle(fontSize: adaptiveFontSize(context, 0.055), fontWeight: FontWeight.w800, color: primaryTextDark)),
              Text('Track your productivity history', style: TextStyle(fontSize: adaptiveFontSize(context, 0.035), color: secondaryTextGrey)),
              const SizedBox(height: 20),

              _buildCustomTabToggle(context),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: accentThemeColor))
                  : TabBarView(
                      controller: _tabController,
                      children: tabs.map((period) => _buildTabContent(context, period)).toList(),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartDataPoint {
  final String label;
  final int minutes;
  _ChartDataPoint(this.label, this.minutes);
}