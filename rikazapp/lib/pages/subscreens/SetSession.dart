// ============================================================================
// FILE: SetSession.dart
// HomePage-consistent Set Session page.
// Changes included:
// - Set Session header font updated to size 30, normal weight, -0.5 letter spacing.
// - Duration numbers font updated to thin (w300), letter spacing 2.0.
// - Number of blocks reduced to 4. Previous blocks now shade dynamically.
// - Dialog buttons have explicitly centered text alignment to fix layout quirks.
// - Hardware SlideAction changed to white background with colored border.
// - Kept all logic, background themes, and structural integrations intact.
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '/services/rikaz_light_service.dart';
import '/widgets/rikaz_device_picker.dart';
import '/main.dart';
import 'create_preset.dart';

// --- DREAMY THEME COLORS ---
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color dfTealCyan = Color(0xFF68C29D); // Pomodoro
const Color customModeColor = Color(0xFF7E84D4); // Custom
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);

const Color primaryBackgroundTop = Color(0xFFF4F7F9);
const Color primaryBackgroundBottom = Color(0xFFE5ECEF);
const Color cardBackground = Color(0xFFFFFFFF);

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.04),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ];

List<BoxShadow> getActiveShadow(Color color) => [
      BoxShadow(
        color: color.withOpacity(0.2),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];

enum SessionMode { pomodoro, custom }

class _Constants {
  static const Duration connectionSuccessDuration = Duration(seconds: 2);
  static const Duration soundPreviewDuration = Duration(seconds: 5);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1000);
  static const Duration successAnimationDuration = Duration(milliseconds: 600);
  static const Duration connectionCheckInterval = Duration(seconds: 5);

  static const double minCustomDuration = 10;
  static const double maxCustomDuration = 120;
}

class SoundOption {
  final String id;
  final String name;
  final String? filePathUrl;
  final String iconName;
  final String colorHex;

  SoundOption({
    required this.id,
    required this.name,
    required this.filePathUrl,
    required this.iconName,
    required this.colorHex,
  });

  factory SoundOption.off() => SoundOption(
        id: 'off',
        name: 'Silent',
        filePathUrl: null,
        iconName: 'volume_off_rounded',
        colorHex: '#8B95A5',
      );

  IconData get icon {
    switch (iconName) {
      case 'water_drop_outlined':
      case 'Rain':
        return Icons.water_drop_outlined;
      case 'water_rounded':
        return Icons.water_rounded;
      case 'waves_rounded':
      case 'Wind':
      case 'River':
        return Icons.waves_rounded;
      case 'volume_off_rounded':
        return Icons.volume_off_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }
}

class SetSessionPage extends StatefulWidget {
  final SessionMode? initialMode;

  const SetSessionPage({super.key, this.initialMode});

  @override
  State<SetSessionPage> createState() => _SetSessionPageState();
}

class _SetSessionPageState extends State<SetSessionPage>
    with SingleTickerProviderStateMixin {
  late SessionMode sessionMode;

  String pomodoroDuration = '25min';
  double numberOfBlocks = 0;
  double customDuration = 25;

  bool isCameraDetectionEnabled = false;
  double sensitivity = 0.5;
  String notificationStyle = 'subtle'; // 'subtle' or 'strong'
  String subtleAlertType = 'light'; // 'light' or 'sound'

  bool sleepTrigger = true;
  bool presenceTrigger = false;
  bool phoneTrigger = false;

  bool isConfigurationOpen = false;
  bool _blocksFieldError = false;

  List<Map<String, dynamic>> _userPresets = [];
  bool _isLoadingPresets = true;
  String? _selectedPresetId;

  SoundOption _selectedSound = SoundOption.off();
  List<SoundOption> _availableSounds = [];
  bool _soundsLoaded = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _previewTimer;
  bool _isPlayingPreview = false;
  String? _notificationSoundUrl;
  final AudioPlayer _notificationPlayer = AudioPlayer();

  bool get isRikazToolConnected => RikazConnectionState.isConnected;
  bool isLoading = false;
  bool _showRikazConfirmation = false;
  String? _connectedDeviceName;
  Timer? _connectionCheckTimer;
  bool _deviceWasConnected = false;
  bool _hasShownDisconnectWarning = false;
  String _cameraStatus = 'unknown';
  StreamSubscription? _cameraStatusSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final GlobalKey<SlideActionState> _slideKey = GlobalKey<SlideActionState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _blocksCounterKey = GlobalKey();

  bool get canStartSession => !isLoading;
  bool get showDisconnectButton => isRikazToolConnected && !_showRikazConfirmation;

  Color get _accentColor =>
      sessionMode == SessionMode.pomodoro ? dfTealCyan : customModeColor;

  @override
  void initState() {
    super.initState();

    sessionMode = widget.initialMode ?? SessionMode.pomodoro;

    _loadUserPresets();
    _loadSounds();
    _loadNotificationSound();

    _pulseController = AnimationController(
      duration: _Constants.pulseAnimationDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (RikazConnectionState.isConnected) {
      isConfigurationOpen = true;
      _startConnectionMonitoring();
      _setupCameraStatusListener();
    }
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _cameraStatusSubscription?.cancel();
    _previewTimer?.cancel();

    _audioPlayer.stop();
    _audioPlayer.dispose();

    _notificationPlayer.stop();
    _notificationPlayer.dispose();

    _pulseController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _loadUserPresets() async {
    try {
      final userId = sb.Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await sb.Supabase.instance.client
          .from('Preset')
          .select()
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _userPresets = List<Map<String, dynamic>>.from(response);
          _isLoadingPresets = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPresets = false);
      }
    }
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _selectedPresetId = preset['Preset_id'].toString();

      phoneTrigger = preset['trigger_phone_use'] ?? true;
      presenceTrigger = preset['trigger_absence'] ?? false;
      sleepTrigger = preset['trigger_sleeping'] ?? false;

      final sens = preset['detection_sensitivity_level'] ?? 'Mid';

      if (sens == 'High') {
        sensitivity = 0.0;
      } else if (sens == 'Mid') {
        sensitivity = 0.5;
      } else {
        sensitivity = 1.0;
      }

      final light = preset['notification_light'] ?? true;
      final sound = preset['notification_sound'] ?? true;

      if (light && sound) {
        notificationStyle = 'strong';
      } else {
        notificationStyle = 'subtle';
        subtleAlertType = light ? 'light' : 'sound';
      }
    });

    _updateCameraSettings();
    _showSnackBar('Preset "${preset['preset_name']}" applied', _accentColor);
  }

  void _handleNewPresetRedirect() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePresetPage()),
    ).then((_) => _loadUserPresets());
  }

  Future<void> _loadSounds() async {
    final fallback = [
      SoundOption.off(),
      SoundOption(
        id: 'Rain',
        name: 'Rain',
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
        iconName: 'water_drop_outlined',
        colorHex: '#5DADE2',
      ),
      SoundOption(
        id: 'Wind',
        name: 'Wind',
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
        iconName: 'waves_rounded',
        colorHex: '#4FC3F7',
      ),
      SoundOption(
        id: 'Waves',
        name: 'Waves',
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3',
        iconName: 'waves_rounded',
        colorHex: '#BA9CF1',
      ),
      SoundOption(
        id: 'Lo-Fi',
        name: 'Lo-Fi',
        filePathUrl: 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3',
        iconName: 'music_note_rounded',
        colorHex: '#F08080',
      ),
    ];

    try {
      final response = await sb.Supabase.instance.client
          .from('Sound_Option')
          .select('sound_name, sound_file_path, icon_name, color_hex');

      if (response.isEmpty) {
        if (mounted) {
          setState(() {
            _availableSounds = fallback;
            _soundsLoaded = true;
          });
        }
        return;
      }

      final List<SoundOption> fetched = [SoundOption.off()];

      for (final item in response) {
        fetched.add(
          SoundOption(
            id: item['sound_name'],
            name: item['sound_name'],
            filePathUrl: item['sound_file_path'],
            iconName: item['icon_name'],
            colorHex: item['color_hex'],
          ),
        );
      }

      if (mounted) {
        setState(() {
          _availableSounds = fetched;
          _soundsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableSounds = fallback;
          _soundsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadNotificationSound() async {
    try {
      final url = sb.Supabase.instance.client.storage
          .from('sounds')
          .getPublicUrl('notify.mp3');

      if (mounted) {
        setState(() => _notificationSoundUrl = url);
      }
    } catch (e) {
      debugPrint('Notification sound load error: $e');
    }
  }

  Future<void> _playPreview(SoundOption sound) async {
    _previewTimer?.cancel();
    await _audioPlayer.stop();

    if (sound.id == 'off' || sound.filePathUrl == null) {
      if (mounted) {
        setState(() => _isPlayingPreview = false);
      }
      return;
    }

    try {
      await _audioPlayer.setSourceUrl(sound.filePathUrl!);
      await _audioPlayer.resume();

      if (mounted) {
        setState(() => _isPlayingPreview = true);
      }

      _previewTimer = Timer(_Constants.soundPreviewDuration, () async {
        await _audioPlayer.stop();

        if (mounted) {
          setState(() => _isPlayingPreview = false);
        }
      });
    } catch (_) {
      String? fallback;

      if (sound.name == 'Rain' || sound.name == 'River') {
        fallback = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3';
      } else if (sound.name == 'White Noise' || sound.name == 'Waves') {
        fallback = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3';
      }

      if (fallback != null) {
        try {
          await _audioPlayer.setSourceUrl(fallback);
          await _audioPlayer.resume();

          if (mounted) {
            setState(() => _isPlayingPreview = true);
          }

          _previewTimer = Timer(_Constants.soundPreviewDuration, () async {
            await _audioPlayer.stop();

            if (mounted) {
              setState(() => _isPlayingPreview = false);
            }
          });
        } catch (_) {
          if (mounted) {
            setState(() => _isPlayingPreview = false);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isPlayingPreview = false);
        }
      }
    }
  }

  Future<void> _playNotificationPreview() async {
    try {
      await _notificationPlayer.stop();
      final url = _notificationSoundUrl ??
          'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/notify.mp3';
      await _notificationPlayer.setSourceUrl(url);
      await _notificationPlayer.resume();
    } catch (e) {
      debugPrint('Notification preview error: $e');
    }
  }

  void _setupCameraStatusListener() {
    RikazLightService.onCameraStatusChanged = (String status) {
      if (mounted) setState(() => _cameraStatus = status);
    };

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && isRikazToolConnected) {
        RikazLightService.requestCameraStatus();
      }
    });
  }

  void _updateCameraSettings() async {
    if (!isCameraDetectionEnabled || !isRikazToolConnected) return;

    await RikazLightService.enableCameraDetection(
      sensitivity: _getSensitivityLevel(),
      notificationStyle: notificationStyle,
      sleepTrigger: sleepTrigger,
      presenceTrigger: presenceTrigger,
      phoneTrigger: phoneTrigger,
    );
  }

  Future<void> _toggleCameraDetection(bool value) async {
    if (!isRikazToolConnected) return;

    setState(() => isCameraDetectionEnabled = value);

    if (value) {
      final success = await RikazLightService.enableCameraDetection(
        sensitivity: _getSensitivityLevel(),
        notificationStyle: notificationStyle,
        sleepTrigger: sleepTrigger,
        presenceTrigger: presenceTrigger,
        phoneTrigger: phoneTrigger,
      );

      if (success) {
        _showSnackBar('Camera detection enabled', _accentColor);
      } else {
        setState(() => isCameraDetectionEnabled = false);
        _showSnackBar('Failed to enable camera', errorIndicatorRed);
      }
    } else {
      await RikazLightService.disableCameraDetection();
      _showSnackBar('Camera detection disabled', secondaryTextGrey);
    }
  }

  String _getSensitivityLevel() {
    if (sensitivity <= 0.33) return 'high';
    if (sensitivity <= 0.67) return 'medium';
    return 'low';
  }

  Future<void> _updateCameraSensitivity(double value) async {
    setState(() {
      sensitivity = value;
      _selectedPresetId = null;
    });
    _updateCameraSettings();
  }

  void handleStartSessionPress() {
    if (sessionMode == SessionMode.pomodoro && numberOfBlocks == 0) {
      setState(() => _blocksFieldError = true);

      if (_blocksCounterKey.currentContext != null) {
        Scrollable.ensureVisible(
          _blocksCounterKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }

      return;
    }

    if (!isRikazToolConnected) {
      _showAlertDialog(
        title: 'Hardware Not Connected',
        content: 'You haven\'t connected your Rikaz Tools hardware yet.',
        icon: Icons.lightbulb_outline,
        iconColor: dfTealCyan,
        cancelText: 'Connect Now',
        confirmText: 'Start Anyway',
        onCancel: _handleRikazConnect,
        onConfirm: _navigateToSession,
      );

      return;
    }

    if (isRikazToolConnected && !isCameraDetectionEnabled) {
      _showAlertDialog(
        title: 'Camera Not Available',
        content: 'Camera detection is off. Start without distraction monitoring?',
        icon: Icons.videocam_off_rounded,
        iconColor: _accentColor,
        cancelText: 'Enable Camera',
        confirmText: 'Start Anyway',
        onCancel: () {
          _toggleCameraDetection(true);
        },
        onConfirm: _navigateToSession,
      );

      return;
    }

    _navigateToSession();
  }

  void _navigateToSession() {
    final sessionType =
        sessionMode == SessionMode.pomodoro ? 'pomodoro' : 'custom';

    final durationValue = sessionMode == SessionMode.pomodoro
        ? pomodoroDuration
        : customDuration.toInt().toString();

    final blocks = sessionMode == SessionMode.pomodoro
        ? numberOfBlocks.toInt().toString()
        : null;

    final cameraEnabled = isCameraDetectionEnabled && isRikazToolConnected;

    _previewTimer?.cancel();
    _audioPlayer.stop();

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': sessionType,
        'duration': durationValue,
        'numberOfBlocks': blocks,
        'isCameraDetectionEnabled': cameraEnabled,
        'sensitivity': sensitivity,
        'notificationStyle': notificationStyle,
        'subtleAlertType': subtleAlertType,
        'sleepTrigger': cameraEnabled ? sleepTrigger : false,
        'presenceTrigger': cameraEnabled ? presenceTrigger : false,
        'phoneTrigger': cameraEnabled ? phoneTrigger : false,
        'rikazConnected': RikazConnectionState.isConnected,
        'selectedSoundId': _selectedSound.id,
        'selectedSoundName': _selectedSound.name,
        'selectedSoundUrl': _selectedSound.filePathUrl,
        'notificationSoundUrl': _notificationSoundUrl,
      },
    );
  }

 void _startDemoSession() {
    // 1. Check if the user selected Pomodoro but forgot to pick the number of blocks
    if (sessionMode == SessionMode.pomodoro && numberOfBlocks == 0) {
      setState(() => _blocksFieldError = true);

      if (_blocksCounterKey.currentContext != null) {
        Scrollable.ensureVisible(
          _blocksCounterKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
      return;
    }

    _previewTimer?.cancel();
    _audioPlayer.stop();

    // 2. Read the actual selected mode and blocks from the UI
    final sessionType =
        sessionMode == SessionMode.pomodoro ? 'pomodoro' : 'custom';

    final blocks = sessionMode == SessionMode.pomodoro
        ? numberOfBlocks.toInt().toString()
        : null;

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': sessionType, // Now passes 'pomodoro' if selected
        'duration': '1', // Hardcoded 1 minute for demo purposes
        'numberOfBlocks': blocks, // Now passes the correct number of blocks
        'isCameraDetectionEnabled': false,
        'sensitivity': 0.5,
        'notificationStyle': 'subtle',
        'subtleAlertType': 'light',
        'sleepTrigger': false,
        'presenceTrigger': false,
        'phoneTrigger': false,
        'rikazConnected': RikazConnectionState.isConnected,
        'selectedSoundId': 'off',
        'selectedSoundName': 'No Sound',
        'selectedSoundUrl': null,
        'notificationSoundUrl': _notificationSoundUrl,
      },
    );
  }

  Future<void> _handleRikazConnect() async {
    if (RikazConnectionState.isConnected) return;

    setState(() => isLoading = true);

    final RikazDevice? device = await showDialog<RikazDevice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RikazDevicePicker(),
    );

    if (!mounted) return;

    if (device != null) {
      RikazConnectionState.setConnected(true);
      _connectedDeviceName = device.name;

      setState(() {
        isLoading = false;
        _showRikazConfirmation = true;
        isConfigurationOpen = true;
      });

      _pulseController.forward().then((_) => _pulseController.reverse());

      _startConnectionMonitoring();
      _setupCameraStatusListener();

      Future.delayed(_Constants.connectionSuccessDuration, () {
        if (mounted) {
          setState(() => _showRikazConfirmation = false);
        }
      });
    } else {
      if (mounted) {
        setState(() => isLoading = false);
        Future.microtask(() {
          if (mounted && _slideKey.currentState != null) {
            _slideKey.currentState!.reset();
          }
        });
      }
    }
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();

    _deviceWasConnected = true;
    _hasShownDisconnectWarning = false;

    _connectionCheckTimer = Timer.periodic(
      _Constants.connectionCheckInterval,
      (timer) async {
        if (!mounted || !RikazConnectionState.isConnected) {
          timer.cancel();
          return;
        }

        final stillConnected = await RikazLightService.isConnected();

        if (!stillConnected) {
          timer.cancel();

          await RikazLightService.disconnect();
          RikazConnectionState.reset();

          if (mounted) {
            setState(() {
              isConfigurationOpen = false;
              _connectedDeviceName = null;
              _deviceWasConnected = false;
              isCameraDetectionEnabled = false;
              _cameraStatus = 'unknown';
            });

            _showDeviceLostWarning();
          }
        }
      },
    );
  }

  void _showDeviceLostWarning() {
    if (!mounted) return;

    _showAlertDialog(
      title: 'Hardware Disconnected',
      content:
          'Bluetooth connection lost. Please check your device and try reconnecting.',
      icon: Icons.bluetooth_disabled_rounded,
      iconColor: errorIndicatorRed,
      cancelText: 'Close',
      confirmText: 'Reconnect',
      onConfirm: _handleRikazConnect,
      barrierDismissible: false,
    );
  }

  Future<void> _handleRikazDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      barrierDismissible: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _buildDisconnectDialog(),
      ),
    );

    if (confirmed == true) {
      _connectionCheckTimer?.cancel();

      await RikazLightService.turnOff();
      await RikazLightService.disconnect();

      RikazConnectionState.reset();

      if (mounted) {
        setState(() {
          isConfigurationOpen = false;
          _connectedDeviceName = null;
          _deviceWasConnected = false;
          _hasShownDisconnectWarning = false;
          isCameraDetectionEnabled = false;
          _cameraStatus = 'unknown';
        });

        _showSnackBar('Hardware disconnected', secondaryTextGrey);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAlertDialog({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required String cancelText,
    required String confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '',
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: dfNavyIndigo.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dfNavyIndigo,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: secondaryTextGrey,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: cancelText,
                        textColor: secondaryTextGrey,
                        backgroundColor: secondaryTextGrey.withOpacity(0.1),
                        onTap: () {
                          Navigator.pop(context);
                          if (onCancel != null) onCancel();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: confirmText,
                        textColor: Colors.white,
                        backgroundColor: iconColor,
                        shadowColor: iconColor.withOpacity(0.3),
                        onTap: () {
                          Navigator.pop(context);
                          if (onConfirm != null) onConfirm();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) => Transform.scale(
        scale: Curves.easeOutBack.transform(anim.value),
        child: Opacity(
          opacity: Curves.easeOut.transform(anim.value),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDisconnectDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: dfNavyIndigo.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorIndicatorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: errorIndicatorRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Disconnect Hardware?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: dfNavyIndigo,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'This will disable hardware features. You can reconnect anytime.',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextGrey,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    textColor: secondaryTextGrey,
                    backgroundColor: secondaryTextGrey.withOpacity(0.1),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    label: 'Disconnect',
                    textColor: Colors.white,
                    backgroundColor: errorIndicatorRed,
                    shadowColor: errorIndicatorRed.withOpacity(0.3),
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primaryBackgroundTop, primaryBackgroundBottom],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomHeader(),
                  const SizedBox(height: 36),
                  
                  const _SectionLabel('RHYTHM'),
                  const SizedBox(height: 16),
                  _buildModeToggle(),
                  const SizedBox(height: 32),
                  
                  const _SectionLabel('DURATION'),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: sessionMode == SessionMode.pomodoro
                        ? Column(
                            key: const ValueKey('pomo'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPomodoroDurationSection(),
                              const SizedBox(height: 24),
                              _buildBlocksSection(),
                            ],
                          )
                        : Column(
                            key: const ValueKey('custom'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCustomDurationSection(),
                            ],
                          ),
                  ),
                  const SizedBox(height: 36),
                  
                  const _SectionLabel('ATMOSPHERE'),
                  const SizedBox(height: 16),
                  _buildSoundSection(),
                  
                  const SizedBox(height: 36),
                  const _SectionLabel('ENVIRONMENT'),
                  const SizedBox(height: 16),
                  _buildHardwareSection(),
                  if (isRikazToolConnected) ...[
                    const SizedBox(height: 16),
                    _buildCameraSection(),
                  ],
                ],
              ),
            ),
          ),
          
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: _Tappable(
              onTap: canStartSession ? handleStartSessionPress : () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Start Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Tappable(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: dfNavyIndigo, size: 18),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: _accentColor),
                const SizedBox(width: 6),
                Text(
                  'SESSION SETUP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _accentColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Set Session',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.normal,
                color: dfNavyIndigo,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      const Spacer(), // ADD THIS
      // ADD THIS BUTTON
      _Tappable(
        onTap: _startDemoSession,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bug_report_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 6),
              Text(
                'Demo',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Row(
      children: [
        _buildModeTab(
          mode: SessionMode.pomodoro,
          title: 'Pomodoro',
          subtitle: 'Structured flow',
          icon: Icons.adjust_rounded,
        ),
        const SizedBox(width: 16),
        _buildModeTab(
          mode: SessionMode.custom,
          title: 'Custom',
          subtitle: 'Your own duration',
          icon: Icons.all_inclusive_rounded,
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required SessionMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = sessionMode == mode;
    final color = mode == SessionMode.pomodoro ? dfTealCyan : customModeColor;
    
    return Expanded(
      child: _Tappable(
        onTap: () {
          setState(() {
            sessionMode = mode;
            if (mode == SessionMode.custom) _blocksFieldError = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color.withOpacity(0.12), Colors.white.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: Colors.white, width: 1.5) : Border.all(color: Colors.transparent),
            boxShadow: isSelected ? getActiveShadow(color) : subtleShadow,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isSelected)
                Positioned(
                  left: -14,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              if (isSelected)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.5) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isSelected ? color : secondaryTextGrey.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? dfNavyIndigo : secondaryTextGrey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? color.withOpacity(0.8) : secondaryTextGrey.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  Widget _buildPomodoroDurationSection() {
    return Row(
      children: [
        _buildDurationTile('25min', '5 min break'),
        const SizedBox(width: 16),
        _buildDurationTile('50min', '10 min break'),
      ],
    );
  }

  Widget _buildDurationTile(String label, String breakText) {
    final isSelected = pomodoroDuration == label;
    final minutes = label.replaceAll('min', '');
    final activeColor = isSelected ? _accentColor : secondaryTextGrey;
    final darkerThemeColor = Color.lerp(activeColor, Colors.black, 0.4) ?? activeColor;

    return Expanded(
      child: _Tappable(
        onTap: () => setState(() => pomodoroDuration = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? subtleShadow : null,
            border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isSelected
                            ? [Colors.black, darkerThemeColor]
                            : [secondaryTextGrey.withOpacity(0.6), secondaryTextGrey.withOpacity(0.6)],
                      ).createShader(bounds),
                      child: Text(
                        minutes,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2.0,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'min',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _accentColor : secondaryTextGrey.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                breakText,
                style: TextStyle(
                  color: isSelected ? secondaryTextGrey : secondaryTextGrey.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlocksSection() {
    final dur = pomodoroDuration == '25min' ? 25 : 50;
    final total = numberOfBlocks > 0 ? numberOfBlocks.toInt() * dur : 0;

    return Column(
      key: _blocksCounterKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('BLOCKS'),
            AnimatedOpacity(
              opacity: total > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                '$total min total',
                style: TextStyle(
                  fontSize: 12,
                  color: _accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBlockRow(1, 4),
        if (_blocksFieldError) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: errorIndicatorRed, size: 14),
              SizedBox(width: 6),
              Text(
                'Please select number of blocks to continue',
                style: TextStyle(
                  color: errorIndicatorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBlockRow(int start, int end) {
    return Row(
      children: List.generate(end - start + 1, (i) {
        final n = start + i;
        final isSelected = numberOfBlocks.toInt() == n;
        final isShaded = n < numberOfBlocks.toInt();
        final isLast = i == (end - start);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: _Tappable(
              onTap: () {
                setState(() {
                  numberOfBlocks = n.toDouble();
                  _blocksFieldError = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accentColor
                      : isShaded
                          ? _accentColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected ? getActiveShadow(_accentColor) : null,
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isShaded ? _accentColor : dfNavyIndigo),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCustomDurationSection() {
    final darkerThemeColor = Color.lerp(_accentColor, Colors.black, 0.4) ?? _accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, darkerThemeColor],
                ).createShader(bounds),
                child: Text(
                  '${customDuration.toInt()}',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2.0,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'min',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accentColor,
              inactiveTrackColor: primaryBackgroundTop,
              trackHeight: 6,
              thumbColor: Colors.white,
              overlayColor: _accentColor.withOpacity(0.1),
            ),
            child: Slider(
              value: customDuration,
              min: _Constants.minCustomDuration,
              max: _Constants.maxCustomDuration,
              onChanged: (v) => setState(() => customDuration = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_Constants.minCustomDuration.toInt()} min',
                  style: const TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_Constants.maxCustomDuration.toInt()} min',
                  style: const TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: subtleShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: primaryBackgroundTop,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRikazToolConnected
                      ? Icons.check_rounded
                      : Icons.settings_remote_rounded,
                  color: isRikazToolConnected ? dfTealCyan : secondaryTextGrey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRikazToolConnected
                          ? (_connectedDeviceName ?? 'Rikaz Device')
                          : 'Rikaz Hardware',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dfNavyIndigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRikazToolConnected
                          ? 'Device connected securely.'
                          : 'Awaiting sync',
                      style: const TextStyle(
                        fontSize: 12,
                        color: secondaryTextGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showDisconnectButton)
                _Tappable(
                  onTap: _handleRikazDisconnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: errorIndicatorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Disconnect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: errorIndicatorRed,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!isRikazToolConnected) ...[
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _accentColor.withOpacity(0.4), width: 1.5),
              ),
              child: SlideAction(
                key: _slideKey,
                text: isLoading ? 'Scanning...' : 'Slide to Connect',
                textStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
                innerColor: _accentColor,
                outerColor: Colors.white,
                elevation: 0,
                sliderButtonIcon: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                sliderButtonIconPadding: 10,
                height: 56,
                borderRadius: 20,
                onSubmit: isLoading
                    ? null
                    : () async {
                        await _handleRikazConnect();
                        return null;
                      },
              ),
            ),
          ],
          if (_showRikazConfirmation) ...[
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: _Constants.successAnimationDuration,
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(
                scale: v.clamp(0.5, 1.2),
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Connection Successful!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: subtleShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: primaryBackgroundTop,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: isCameraDetectionEnabled ? _accentColor : secondaryTextGrey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera Detection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dfNavyIndigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCameraDetectionEnabled
                          ? 'Monitoring active'
                          : 'Optional monitoring',
                      style: const TextStyle(
                        fontSize: 12,
                        color: secondaryTextGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isCameraDetectionEnabled,
                onChanged: _toggleCameraDetection,
                activeColor: _accentColor,
                inactiveThumbColor: secondaryTextGrey,
              ),
            ],
          ),
          if (isCameraDetectionEnabled) ...[
            const SizedBox(height: 24),
            _buildCameraOptions(),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: primaryBackgroundTop),
        const SizedBox(height: 20),
        _buildPresetRow(),
        const SizedBox(height: 20),
        _buildCameraSettingsCard(
          title: 'Detect When',
          child: Column(
            children: [
              _buildCameraCheckRow(
                icon: Icons.bedtime_rounded,
                label: 'Sleeping',
                checked: sleepTrigger,
                onTap: () {
                  if (sleepTrigger && !phoneTrigger && !presenceTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
                  }
                  setState(() {
                    sleepTrigger = !sleepTrigger;
                    _selectedPresetId = null;
                  });
                  _updateCameraSettings();
                },
              ),
              _buildCameraCheckRow(
                icon: Icons.person_off_rounded,
                label: 'Absence',
                checked: presenceTrigger,
                onTap: () {
                  if (presenceTrigger && !phoneTrigger && !sleepTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
                  }
                  setState(() {
                    presenceTrigger = !presenceTrigger;
                    _selectedPresetId = null;
                  });
                  _updateCameraSettings();
                },
              ),
              _buildCameraCheckRow(
                icon: Icons.smartphone_rounded,
                label: 'Phone Use',
                checked: phoneTrigger,
                last: true,
                onTap: () {
                  if (phoneTrigger && !sleepTrigger && !presenceTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
                  }
                  setState(() {
                    phoneTrigger = !phoneTrigger;
                    _selectedPresetId = null;
                  });
                  _updateCameraSettings();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildCameraSettingsCard(
          title: 'Sensitivity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryBackgroundTop,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildSensitivitySegment('Low\n90 sec', 1.0, dfTealCyan),
                    _buildSensitivitySegment('Medium\n60 sec', 0.5, Colors.orange),
                    _buildSensitivitySegment('High\n30 sec', 0.0, errorIndicatorRed),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildCameraSettingsCard(
          title: 'Notification',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryBackgroundTop,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildToggleSegment(
                      label: 'Subtle',
                      isSelected: notificationStyle == 'subtle',
                      onTap: () => setState(() {
                        notificationStyle = 'subtle';
                        _updateCameraSettings();
                      })
                    ),
                    _buildToggleSegment(
                      label: 'Strong',
                      isSelected: notificationStyle == 'strong',
                      onTap: () => setState(() {
                        notificationStyle = 'strong';
                        _updateCameraSettings();
                      })
                    ),
                  ],
                ),
              ),
              
              if (notificationStyle == 'subtle') ...[
                const SizedBox(height: 16),
                const Text(
                  'Choose your alert method:',
                  style: TextStyle(fontSize: 12, color: secondaryTextGrey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: primaryBackgroundTop,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildToggleSegment(
                        label: 'Lamp Light',
                        icon: Icons.lightbulb_outline_rounded,
                        isSelected: subtleAlertType == 'light',
                        onTap: () {
                          setState(() => subtleAlertType = 'light');
                          _updateCameraSettings();
                        }
                      ),
                      _buildToggleSegment(
                        label: 'Sound Alert',
                        icon: Icons.volume_up_rounded,
                        isSelected: subtleAlertType == 'sound',
                        onTap: () {
                          setState(() => subtleAlertType = 'sound');
                          _updateCameraSettings();
                          _playNotificationPreview();
                        }
                      ),
                    ],
                  ),
                ),
              ],
              
              if (notificationStyle == 'strong') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _accentColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: _accentColor, size: 18),
                      const SizedBox(width: 4),
                      Icon(Icons.add_rounded, color: _accentColor, size: 14),
                      const SizedBox(width: 4),
                      Icon(Icons.volume_up_rounded, color: _accentColor, size: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Light + Sound Cues',
                            style: TextStyle(
                              fontSize: 13,
                              color: _accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Expanded(
      child: _Tappable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? [BoxShadow(color: _accentColor.withOpacity(0.1), blurRadius: 10)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: isSelected ? _accentColor : secondaryTextGrey),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? _accentColor : secondaryTextGrey,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSettingsCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryBackgroundTop, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallSectionLabel(title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildCameraCheckRow({
    required IconData icon,
    required String label,
    required bool checked,
    required VoidCallback onTap,
    bool last = false,
  }) {
    return _Tappable(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: last ? 0 : 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: checked ? _accentColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: checked ? _accentColor.withOpacity(0.3) : primaryBackgroundTop,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: checked ? _accentColor : secondaryTextGrey),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: checked ? dfNavyIndigo : secondaryTextGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: checked ? _accentColor : secondaryTextGrey.withOpacity(0.3),
                  width: 1.5,
                ),
                color: checked ? _accentColor : Colors.white,
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensitivitySegment(String label, double value, Color activeColor) {
    final isSelected = (sensitivity - value).abs() < 0.1;

    return Expanded(
      child: _Tappable(
        onTap: () => _updateCameraSensitivity(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.1), blurRadius: 10)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: isSelected ? activeColor : secondaryTextGrey,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallSectionLabel('Preset'),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Tappable(
                  onTap: _userPresets.length >= 5 ? () {} : _handleNewPresetRedirect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _userPresets.length >= 5 ? secondaryTextGrey.withOpacity(0.1) : _accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: _userPresets.length >= 5 ? secondaryTextGrey : _accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'New',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _userPresets.length >= 5 ? secondaryTextGrey : _accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoadingPresets)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: dfTealCyan),
                    ),
                  ),
                )
              else
                ..._userPresets.map((preset) {
                  final isSelected = _selectedPresetId == preset['Preset_id'].toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Tappable(
                      onTap: () => _applyPreset(preset),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _accentColor.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _accentColor.withOpacity(0.4) : primaryBackgroundTop,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          preset['preset_name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? _accentColor : secondaryTextGrey,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSection() {
    if (!_soundsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: dfTealCyan, strokeWidth: 2.5),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 8.0;
        final totalSpacing = spacing * 4; 
        final itemWidth = (constraints.maxWidth - totalSpacing) / 5;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _availableSounds.take(5).map((sound) {
            final isSelected = _selectedSound.id == sound.id;
            
            return _Tappable(
              onTap: () {
                setState(() => _selectedSound = sound);
                _playPreview(sound);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: itemWidth,
                height: itemWidth * 1.25,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? getActiveShadow(_accentColor) : null,
                  border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected && _isPlayingPreview)
                      SizedBox(
                        width: itemWidth * 0.4,
                        height: itemWidth * 0.4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _accentColor,
                        ),
                      )
                    else
                      Icon(
                        sound.icon,
                        color: isSelected ? _accentColor : secondaryTextGrey.withOpacity(0.8),
                        size: itemWidth * 0.4,
                      ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        sound.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? dfNavyIndigo : secondaryTextGrey.withOpacity(0.8),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: secondaryTextGrey.withOpacity(0.9),
            letterSpacing: 2.0,
          ),
        ),
      );
}

class _SmallSectionLabel extends StatelessWidget {
  final String text;

  const _SmallSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: secondaryTextGrey.withOpacity(0.9),
          letterSpacing: 1.5,
        ),
      );
}

class _Tappable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Tappable({
    required this.child,
    required this.onTap,
  });

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? shadowColor;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: shadowColor != null
              ? [
                  BoxShadow(
                    color: shadowColor!,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center, // Ensured explicitly centered text
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}