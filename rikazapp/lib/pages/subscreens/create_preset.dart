import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

const Color dfDeepTeal = Color(0xFF175B73);
const Color dfTealCyan = Color(0xFF287C85);
const Color dfLightSeafoam = Color(0xFF87ACA3);
const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);
const Color primaryTextDark = Color(0xFF0C1446);
const Color secondaryTextGrey = Color(0xFF6B6B78);
const Color errorIndicatorRed = Color(0xFFE57373);

class CreatePresetPage extends StatefulWidget {
  final Map<String, dynamic>? presetToEdit;

  const CreatePresetPage({super.key, this.presetToEdit});

  @override
  State<CreatePresetPage> createState() => _CreatePresetPageState();
}

class _CreatePresetPageState extends State<CreatePresetPage> {
  final supabase = sb.Supabase.instance.client;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();

  // Variables matching your schema
  bool _notificationLight = true;
  bool _notificationSound = true;
  String _sensitivityLevel = 'Medium'; // Low, Medium, High
  bool _triggerPhoneUse = true;
  bool _triggerAbsence = false;
  bool _triggerSleeping = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetToEdit != null) {
      _nameController.text = widget.presetToEdit!['preset_name'] ?? '';
      _notificationLight = widget.presetToEdit!['notification_light'] ?? true;
      _notificationSound = widget.presetToEdit!['notification_sound'] ?? true;
      _sensitivityLevel =
          widget.presetToEdit!['detection_sensitivity_level'] ?? 'Medium';
      _triggerPhoneUse = widget.presetToEdit!['trigger_phone_use'] ?? true;
      _triggerAbsence = widget.presetToEdit!['trigger_absence'] ?? false;
      _triggerSleeping = widget.presetToEdit!['trigger_sleeping'] ?? false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- VALIDATION LOGIC ---

  void _handleTriggerToggle(String type, bool value) {
    if (value == false) {
      int activeCount = 0;
      if (_triggerPhoneUse) activeCount++;
      if (_triggerAbsence) activeCount++;
      if (_triggerSleeping) activeCount++;

      if (activeCount <= 1) {
        _showLimitWarning('At least one distraction trigger must be active.');
        return;
      }
    }

    setState(() {
      if (type == 'phone') _triggerPhoneUse = value;
      if (type == 'absence') _triggerAbsence = value;
      if (type == 'sleeping') _triggerSleeping = value;
    });
  }

  void _handleNotificationToggle(String type, bool value) {
    int activeNotifs = 0;
    if (_notificationLight) activeNotifs++;
    if (_notificationSound) activeNotifs++;

    if (value == false && activeNotifs <= 1) {
      _showLimitWarning('At least one notification type must be active.');
      return;
    }

    setState(() {
      if (type == 'light') _notificationLight = value;
      if (type == 'sound') _notificationSound = value;
    });
  }

  void _showLimitWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorIndicatorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _savePreset() async {
    final presetName = _nameController.text.trim();

    if (presetName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please give your preset a name.'),
            backgroundColor: errorIndicatorRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");

      var query = supabase
          .from('Preset')
          .select('Preset_id')
          .eq('user_id', userId)
          .ilike('preset_name', presetName);

      if (widget.presetToEdit != null) {
        query =
            query.neq('Preset_id', widget.presetToEdit!['Preset_id']);
      }

      final existingPresets = await query;

      if (existingPresets.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'A preset named "$presetName" already exists, please choose another name.'),
              backgroundColor: errorIndicatorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      final presetData = {
        'user_id': userId,
        'preset_name': presetName,
        'notification_light': _notificationLight,
        'notification_sound': _notificationSound,
        'detection_sensitivity_level': _sensitivityLevel,
        'trigger_phone_use': _triggerPhoneUse,
        'trigger_absence': _triggerAbsence,
        'trigger_sleeping': _triggerSleeping,
      };

      if (widget.presetToEdit == null) {
        await supabase.from('Preset').insert(presetData);
      } else {
        await supabase
            .from('Preset')
            .update(presetData)
            .eq('Preset_id', widget.presetToEdit!['Preset_id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.presetToEdit == null
                ? 'Preset created!'
                : 'Preset updated!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving preset: $e'),
              backgroundColor: errorIndicatorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.presetToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Preset' : 'Create New Preset',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: primaryTextDark, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FIX 1: Preset Name ───────────────────────────────────────
              // font size reduced (16→14), weight lightened (w600→w400),
              // hint matches same size, field height capped via isDense + padding
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preset Name',
                        style: TextStyle(
                            fontSize: 12, color: secondaryTextGrey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Deep Focus, Light Reading',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB0B0B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: primaryTextDark,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Distraction Triggers ──────────────────────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DETECTION TRIGGERS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: secondaryTextGrey)),
                    const SizedBox(height: 12),
                    _TriggerTile(
                      label: 'Phone Activity',
                      subtitle: 'Detect when you pick up your phone',
                      icon: Icons.smartphone,
                      iconBgColor: const Color(0xFFD6F5E8),
                      iconColor: const Color(0xFF2ECC8E),
                      activeTrackColor: const Color(0xFF2ECC8E),
                      activeTileColor: const Color(0xFFEAFBF4),
                      activeBorderColor: const Color(0xFFB2EDDA),
                      value: _triggerPhoneUse,
                      onChanged: (val) => _handleTriggerToggle('phone', val),
                    ),
                    const SizedBox(height: 10),
                    _TriggerTile(
                      label: 'Sleep Detection',
                      subtitle: 'Pause when you fall asleep',
                      icon: Icons.bedtime,
                      iconBgColor: const Color(0xFFE8E4F8),
                      iconColor: const Color(0xFF7C6FCD),
                      activeTrackColor: const Color(0xFF7C6FCD),
                      activeTileColor: const Color(0xFFF0EEFB),
                      activeBorderColor: const Color(0xFFCDC7EF),
                      value: _triggerSleeping,
                      onChanged: (val) => _handleTriggerToggle('sleeping', val),
                    ),
                    const SizedBox(height: 10),
                    _TriggerTile(
                      label: 'Absence Alert',
                      subtitle: 'Notify if you leave your focus zone',
                      icon: Icons.person_off,
                      iconBgColor: const Color(0xFFFFE4EE),
                      iconColor: const Color(0xFFE8638A),
                      activeTrackColor: const Color(0xFFE8638A),
                      activeTileColor: const Color(0xFFFFF0F5),
                      activeBorderColor: const Color(0xFFF5BACE),
                      value: _triggerAbsence,
                      onChanged: (val) => _handleTriggerToggle('absence', val),
                    ),
                  ],
                ),
              ),

              // ── FIX 2: Detection Sensitivity – subtitle removed ───────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DETECTION SENSITIVITY',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: secondaryTextGrey)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SensitivityCard(
                          label: 'Low',
                          barCount: 1,
                          isSelected: _sensitivityLevel == 'Low',
                          onTap: () =>
                              setState(() => _sensitivityLevel = 'Low'),
                        ),
                        const SizedBox(width: 10),
                        _SensitivityCard(
                          label: 'Medium',
                          barCount: 2,
                          isSelected: _sensitivityLevel == 'Medium',
                          onTap: () =>
                              setState(() => _sensitivityLevel = 'Medium'),
                        ),
                        const SizedBox(width: 10),
                        _SensitivityCard(
                          label: 'High',
                          barCount: 3,
                          isSelected: _sensitivityLevel == 'High',
                          onTap: () =>
                              setState(() => _sensitivityLevel = 'High'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── FIX 3: Alert Style – subtitle removed ────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ALERT STYLE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: secondaryTextGrey)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _AlertStyleCard(
                          label: 'Light',
                          icon: Icons.lightbulb_outline,
                          isSelected: _notificationLight,
                          onTap: () =>
                              _handleNotificationToggle('light', !_notificationLight),
                        ),
                        const SizedBox(width: 10),
                        _AlertStyleCard(
                          label: 'Sound',
                          icon: Icons.volume_up,
                          isSelected: _notificationSound,
                          onTap: () =>
                              _handleNotificationToggle('sound', !_notificationSound),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Save Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePreset,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Update Preset' : 'Save Preset',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC8E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Cancel Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFDDE3E6)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryTextDark),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEE), width: 0.8),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger tile
// ─────────────────────────────────────────────────────────────────────────────

class _TriggerTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color activeTrackColor;
  final Color activeTileColor;
  final Color activeBorderColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TriggerTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.activeTrackColor,
    required this.activeTileColor,
    required this.activeBorderColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color tileBg =
        value ? activeTileColor : const Color(0xFFF8FAFB);
    final Color tileBorder =
        value ? activeBorderColor : const Color(0xFFEAEEF0);
    final double borderWidth = value ? 1.2 : 0.8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tileBorder, width: borderWidth),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: value ? iconBgColor : const Color(0xFFF0F2F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? iconColor : const Color(0xFFB0B8BC),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryTextDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: secondaryTextGrey)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: activeTrackColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDDE3E6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX 2: Sensitivity card – subtitle parameter removed
// ─────────────────────────────────────────────────────────────────────────────

class _SensitivityCard extends StatelessWidget {
  final String label;
  final int barCount; // 1=Low, 2=Medium, 3=High
  final bool isSelected;
  final VoidCallback onTap;

  const _SensitivityCard({
    required this.label,
    required this.barCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = const Color(0xFF2ECC8E);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FBF7) : const Color(0xFFF5F7F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFFE0E5E8),
              width: isSelected ? 1.6 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBarChart(barCount: barCount, isSelected: isSelected, accent: accent),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accent : primaryTextDark,
                ),
              ),
              // subtitle removed
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final int barCount;
  final bool isSelected;
  final Color accent;

  const _MiniBarChart(
      {required this.barCount, required this.isSelected, required this.accent});

  @override
  Widget build(BuildContext context) {
    final List<double> heights = [10, 16, 22];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final bool filled = i < barCount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: heights[i],
          decoration: BoxDecoration(
            color: filled
                ? (isSelected ? accent : const Color(0xFF9EC8B8))
                : const Color(0xFFD8E3E7),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX 3: Alert style card – subtitle parameter removed
// ─────────────────────────────────────────────────────────────────────────────

class _AlertStyleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlertStyleCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = const Color(0xFF2ECC8E);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FBF7) : const Color(0xFFF5F7F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFFE0E5E8),
              width: isSelected ? 1.6 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? accent : const Color(0xFF9AABB3),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accent : primaryTextDark,
                ),
              ),
              // subtitle removed
            ],
          ),
        ),
      ),
    );
  }
}
