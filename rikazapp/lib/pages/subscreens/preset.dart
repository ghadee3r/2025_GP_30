// lib/screens/preset.dart
import 'package:flutter/material.dart';

class AddPresetScreen extends StatefulWidget {
  const AddPresetScreen({super.key});

  @override
  State<AddPresetScreen> createState() => _AddPresetScreenState();
}

class _AddPresetScreenState extends State<AddPresetScreen> {
  String name = 'Study Session';
  Map<String, bool> distractions = {
    'phone': true,
    'sleeping': true,
    'talking': false,
    'absent': true,
  };
  String sensitivity = 'medium';
  bool lamp = true;
  bool sound = false;

  String get minutesLabel {
    switch (sensitivity) {
      case 'low':
        return '3 min';
      case 'medium':
        return '2 min';
      case 'high':
        return '1 min';
      default:
        return '';
    }
  }

  void toggleDistraction(String key) {
    setState(() => distractions[key] = !(distractions[key] ?? false));
  }

  void handleSave() {
    // TODO: integrate DB later
    Navigator.of(context).pop();
  }

  void handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F4F1),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              Row(
                children: const [
                  Text(
                    'Profile',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: Color(0xFF9A9A9A)),
                  Text(
                    'Add New Preset',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E1E1E)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE1E6E8), width: 0.5),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info, size: 18, color: Color(0xFF5E6B73)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This preset is only applicable when the camera is on',
                        style: TextStyle(fontSize: 13, color: Color(0xFF5E6B73)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Preset Name
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preset Name',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: name),
                      onChanged: (val) => name = val,
                      decoration: const InputDecoration(
                        hintText: 'Study Session',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 16, color: Color(0xFF1E1E1E)),
                    ),
                  ],
                ),
              ),

              // Distractions
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distraction Types to Detect',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    _CheckRow(
                      label: 'Phone checking',
                      checked: distractions['phone']!,
                      onTap: () => toggleDistraction('phone'),
                    ),
                    _CheckRow(
                      label: 'Sleeping',
                      checked: distractions['sleeping']!,
                      onTap: () => toggleDistraction('sleeping'),
                    ),
                    _CheckRow(
                      label: 'Talking to someone else',
                      checked: distractions['talking']!,
                      onTap: () => toggleDistraction('talking'),
                    ),
                    _CheckRow(
                      label: 'Not being present',
                      checked: distractions['absent']!,
                      onTap: () => toggleDistraction('absent'),
                      last: true,
                    ),
                  ],
                ),
              ),

              // Sensitivity
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sensitivity',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F2EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _SegmentButton(
                            label: 'Low\n3 min',
                            active: sensitivity == 'low',
                            onTap: () => setState(() => sensitivity = 'low'),
                          ),
                          _SegmentButton(
                            label: 'Medium\n2 min',
                            active: sensitivity == 'medium',
                            onTap: () => setState(() => sensitivity = 'medium'),
                          ),
                          _SegmentButton(
                            label: 'High\n1 min',
                            active: sensitivity == 'high',
                            onTap: () => setState(() => sensitivity = 'high'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Selected: $minutesLabel',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                    ),
                  ],
                ),
              ),

              // Notification Methods
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Method',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      icon: Icons.emoji_objects,
                      label: 'Lamp light',
                      value: lamp,
                      onChanged: (val) => setState(() => lamp = val),
                    ),
                    const Divider(height: 20, color: Color(0xFFEEE9E2)),
                    _SwitchRow(
                      icon: Icons.volume_up,
                      label: 'Sound alerts',
                      value: sound,
                      onChanged: (val) => setState(() => sound = val),
                    ),
                  ],
                ),
              ),

              // Buttons
              const SizedBox(height: 8),
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: handleSave,
                    child: const Text(
                      'Save Preset',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: Color(0xFFE6E2DC)),
                    ),
                    onPressed: handleCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                      ),
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
}

/* ---------- Components ---------- */

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E2DC), width: 0.5),
      ),
      child: child,
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;
  final bool last;
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? Colors.black : const Color(0xFFD7D2CA),
                  width: 1.2,
                ),
                color: checked ? Colors.black : Colors.white,
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E))),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: const Color(0xFFE6E2DC), width: 1)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: active ? const Color(0xFF1E1E1E) : const Color(0xFF7A7A7A),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF1E1E1E), size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E))),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.black,
        ),
      ],
    );
  }
}
