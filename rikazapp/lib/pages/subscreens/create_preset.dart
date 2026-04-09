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
  String _sensitivityLevel = 'Mid'; // Low, Mid, High
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
      _sensitivityLevel = widget.presetToEdit!['detection_sensitivity_level'] ?? 'Mid';
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give your preset a name.'), backgroundColor: errorIndicatorRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in");

      final presetData = {
        'user_id': userId,
        'preset_name': _nameController.text.trim(),
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
        await supabase.from('Preset').update(presetData).eq('Preset_id', widget.presetToEdit!['Preset_id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.presetToEdit == null ? 'Preset created!' : 'Preset updated!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preset: $e'), backgroundColor: errorIndicatorRed),
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
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: primaryTextDark), onPressed: () => Navigator.pop(context)),
        title: Text(
          isEditing ? 'Edit Preset' : 'Create New Preset',
          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preset Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Deep Focus, Light Reading',
                  filled: true,
                  fillColor: cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryTextDark.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Distraction Triggers', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark, fontSize: 16)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Phone Use'),
                      secondary: const Icon(Icons.smartphone, color: dfTealCyan),
                      activeColor: dfDeepTeal,
                      value: _triggerPhoneUse,
                      onChanged: (val) => _handleTriggerToggle('phone', val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Sleeping'),
                      secondary: const Icon(Icons.bedtime, color: dfTealCyan),
                      activeColor: dfDeepTeal,
                      value: _triggerSleeping,
                      onChanged: (val) => _handleTriggerToggle('sleeping', val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Absence'),
                      secondary: const Icon(Icons.person_off, color: dfTealCyan),
                      activeColor: dfDeepTeal,
                      value: _triggerAbsence,
                      onChanged: (val) => _handleTriggerToggle('absence', val),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(height: 32),

                    const Text('Detection Sensitivity', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark, fontSize: 16)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _sensitivityLevel,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: primaryBackground,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      items: ['Low', 'Mid', 'High'].map((String level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: Text(level, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _sensitivityLevel = val!),
                    ),

                    const Divider(height: 32),

                    const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextDark, fontSize: 16)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Light Alert'),
                      secondary: const Icon(Icons.lightbulb_outline, color: dfTealCyan),
                      activeColor: dfDeepTeal,
                      value: _notificationLight,
                      onChanged: (val) => _handleNotificationToggle('light', val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Sound Alert'),
                      secondary: const Icon(Icons.volume_up, color: dfTealCyan),
                      activeColor: dfDeepTeal,
                      value: _notificationSound,
                      onChanged: (val) => _handleNotificationToggle('sound', val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePreset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dfDeepTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Update Preset' : 'Save Preset', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}