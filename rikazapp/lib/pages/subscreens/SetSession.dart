// ============================================================================
// FILE: SetSession.dart
// PURPOSE: Session configuration page with BLE device connection + Camera
// FIXES:
// - Camera preview removed (no live feed on setup screen)
// - Camera toggle appears immediately after connection (no delay)
// - Trigger names consistent: Phone Use / Sleeping / Absence + icons
// - Sound preview fixed (5 seconds)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '/services/rikaz_light_service.dart';
import '/widgets/rikaz_device_picker.dart';
import '/main.dart';
import 'create_preset.dart';

// =============================================================================
// THEME CONSTANTS
// =============================================================================

const Color dfDeepTeal = Color(0xFF175B73);
const Color dfTealCyan = Color(0xFF287C85);
const Color dfLightSeafoam = Color(0xFF87ACA3);
const Color dfNavyIndigo = Color(0xFF0C1446);

const Color primaryThemeColor = dfDeepTeal;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;

const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);
const Color errorIndicatorRed = Color(0xFFE57373);

const double cardBorderRadius = 14.0;

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.06),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];

enum SessionMode { pomodoro, custom }

// =============================================================================
// DURATION CONSTANTS
// =============================================================================

class _Constants {
  static const Duration connectionSuccessDuration = Duration(seconds: 2);
  static const Duration soundPreviewDuration = Duration(seconds: 5);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1000);
  static const Duration successAnimationDuration = Duration(milliseconds: 600);
  static const Duration connectionCheckInterval = Duration(seconds: 5);

  static const double minCustomDuration = 10;
  static const double maxCustomDuration = 120;
  static const double minPomodoroBlocks = 1;
  static const double maxPomodoroBlocks = 8;

  static const Map<String, Color> soundColors = {
    'off': secondaryTextGrey,
    'default': Color.fromARGB(255, 48, 139, 117),
    'Rain': Color(0xFF5DADE2),
    'River': Color(0xFF4FC3F7),
    'White Noise': Color.fromARGB(255, 186, 156, 241),
  };
}

// =============================================================================
// SOUND OPTION MODEL
// =============================================================================

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

  factory SoundOption.off() {
    return SoundOption(
      id: 'off',
      name: 'No Sound',
      filePathUrl: null,
      iconName: 'volume_off_rounded',
      colorHex: '#6B6B78',
    );
  }

  IconData get icon {
    switch (iconName) {
      case 'water_drop_outlined':
        return Icons.water_drop_outlined;
      case 'water_rounded':
        return Icons.water_rounded;
      case 'waves_rounded':
        return Icons.waves_rounded;
      case 'volume_off_rounded':
        return Icons.volume_off_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

// =============================================================================
// SET SESSION PAGE
// =============================================================================

class SetSessionPage extends StatefulWidget {
  final SessionMode? initialMode;

  const SetSessionPage({super.key, this.initialMode});

  @override
  State<SetSessionPage> createState() => _SetSessionPageState();
}

class _SetSessionPageState extends State<SetSessionPage>
    with SingleTickerProviderStateMixin {
  // Session configuration
  late SessionMode sessionMode;
  String pomodoroDuration = '25min';
  double numberOfBlocks = 0;
  double customDuration = 70;

  // Camera configuration
  bool isCameraDetectionEnabled = false;
  double sensitivity = 0.5;
  String notificationStyle = 'subtle';
  String subtleAlertType = 'light'; // 'light' or 'sound'

  // Triggers
  bool sleepTrigger = true;
  bool presenceTrigger = false;
  bool phoneTrigger = false;

  bool isConfigurationOpen = false;
  bool _blocksFieldError = false;

// --- Presets State ---
  List<Map<String, dynamic>> _userPresets = [];
  bool _isLoadingPresets = true;
  String? _selectedPresetId;

  // Sound selection
  SoundOption _selectedSound = SoundOption.off();
  List<SoundOption> _availableSounds = [];
  bool _soundsLoaded = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _previewTimer;
  bool _isPlayingPreview = false;

  // Notification sound
  String? _notificationSoundUrl;
  final AudioPlayer _notificationPlayer = AudioPlayer();

  // BLE connection state
  bool get isRikazToolConnected => RikazConnectionState.isConnected;
  bool isLoading = false;
  bool _showRikazConfirmation = false;
  String? _connectedDeviceName;
  Timer? _connectionCheckTimer;
  bool _deviceWasConnected = false;
  bool _hasShownDisconnectWarning = false;

  // Camera status
  String _cameraStatus = 'unknown';
  StreamSubscription? _cameraStatusSubscription;

  final GlobalKey<SlideActionState> _slideKey = GlobalKey<SlideActionState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _blocksCounterKey = GlobalKey();

  // Pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Cached screen dimensions
  late double _screenWidth;
  late double _screenHeight;

  // Computed properties
  bool get canStartSession => !isLoading;
  bool get showDisconnectButton => isRikazToolConnected && !_showRikazConfirmation;
  bool get shouldShowHardwareTip => !isRikazToolConnected;
  // FIX: Camera toggle shows immediately when connected
  bool get canEnableCamera => isRikazToolConnected;

  // Spacing helpers
  double get horizontalPadding => _screenWidth * 0.04;
  double get smallGap => _screenHeight * 0.008;
  double get mediumGap => _screenHeight * 0.012;
  double get largeGap => _screenHeight * 0.02;
  EdgeInsets get cardPadding => EdgeInsets.all(horizontalPadding);

  // Text style helpers
  TextStyle get headingStyle => TextStyle(
        fontSize: _adaptiveFontSize(0.048),
        fontWeight: FontWeight.w700,
        color: primaryTextDark,
      );

  TextStyle get subheadingStyle => TextStyle(
        fontSize: _adaptiveFontSize(0.037),
        fontWeight: FontWeight.bold,
        color: primaryTextDark,
      );

  TextStyle get bodyStyle => TextStyle(
        fontSize: _adaptiveFontSize(0.032),
        color: secondaryTextGrey,
      );

  TextStyle get captionStyle => TextStyle(
        fontSize: _adaptiveFontSize(0.029),
        color: secondaryTextGrey,
        fontWeight: FontWeight.w500,
      );

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
      debugPrint('🔌 Restored connection state from previous session');
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

  // =============================================================================
  // DATA LOADING
  // =============================================================================
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
    } catch (e) {
      if (mounted) setState(() => _isLoadingPresets = false);
    }
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _selectedPresetId = preset['Preset_id'].toString();
      
      // 1. Map Triggers
      phoneTrigger = preset['trigger_phone_use'] ?? true;
      presenceTrigger = preset['trigger_absence'] ?? false;
      sleepTrigger = preset['trigger_sleeping'] ?? false;

      // 2. Map Database String to Local Slider Double
      String sens = preset['detection_sensitivity_level'] ?? 'Mid';
      if (sens == 'High') sensitivity = 0.0;
      else if (sens == 'Mid') sensitivity = 0.5;
      else sensitivity = 1.0;

      // 3. Map Notification Booleans to Local UI Strings
      bool light = preset['notification_light'] ?? true;
      bool sound = preset['notification_sound'] ?? true;
      if (light && sound) {
        notificationStyle = 'strong';
      } else {
        notificationStyle = 'subtle';
        subtleAlertType = light ? 'light' : 'sound';
      }
    });

    _updateCameraSettings(); // Instantly apply to the hardware

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preset "${preset['preset_name']}" applied'),
        backgroundColor: dfDeepTeal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

 void _handleNewPresetRedirect() {
    // Redirect immediately without showing a warning dialog
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePresetPage()),
    ).then((_) => _loadUserPresets());
  }

  Future<void> _loadSounds() async {
    final List<SoundOption> fallbackSounds = [
      SoundOption.off(),
      SoundOption(
        id: 'Rain',
        name: 'Rain',
        filePathUrl:
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
        iconName: 'water_drop_outlined',
        colorHex: '#5DADE2',
      ),
      SoundOption(
        id: 'River',
        name: 'River',
        filePathUrl:
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3',
        iconName: 'waves_rounded',
        colorHex: '#4FC3F7',
      ),
      SoundOption(
        id: 'White Noise',
        name: 'White Noise',
        filePathUrl:
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3',
        iconName: 'waves_rounded',
        colorHex: '#BA9CF1',
      ),
    ];

    try {
      final supabase = sb.Supabase.instance.client;
      final response = await supabase
          .from('Sound_Option')
          .select('sound_name, sound_file_path, icon_name, color_hex');

      if (response.isEmpty) {
        if (mounted) setState(() { _availableSounds = fallbackSounds; _soundsLoaded = true; });
        return;
      }

      final List<SoundOption> fetchedSounds = [SoundOption.off()];
      for (var item in response) {
        fetchedSounds.add(SoundOption(
          id: item['sound_name'],
          name: item['sound_name'],
          filePathUrl: item['sound_file_path'],
          iconName: item['icon_name'],
          colorHex: item['color_hex'],
        ));
      }

      if (mounted) setState(() { _availableSounds = fetchedSounds; _soundsLoaded = true; });
    } catch (e) {
      debugPrint('❌ Error fetching sounds: $e');
      if (mounted) setState(() { _availableSounds = fallbackSounds; _soundsLoaded = true; });
    }
  }

  Future<void> _loadNotificationSound() async {
    try {
      final supabase = sb.Supabase.instance.client;
      final url = supabase.storage.from('sounds').getPublicUrl('notify.mp3');
      if (mounted) setState(() => _notificationSoundUrl = url);
      debugPrint('✅ Notification sound loaded: $url');
    } catch (e) {
      debugPrint('❌ Error loading notification sound: $e');
    }
  }

  // =============================================================================
  // FIX: SOUND PREVIEW — stop previous, play new, auto-stop after 5s
  // =============================================================================

  Future<void> _playPreview(SoundOption sound) async {
    // Cancel any existing preview timer first
    _previewTimer?.cancel();
    _previewTimer = null;

    // Always stop whatever is playing
    await _audioPlayer.stop();

    if (sound.id == 'off' || sound.filePathUrl == null) {
      if (mounted) setState(() => _isPlayingPreview = false);
      return;
    }

    String urlToPlay = sound.filePathUrl!;

    try {
      await _audioPlayer.setSourceUrl(urlToPlay);
      await _audioPlayer.resume();
      debugPrint('🎵 Playing preview: ${sound.name} — ${sound.filePathUrl}');

      if (mounted) setState(() => _isPlayingPreview = true);

      // Auto-stop after 5 seconds
      _previewTimer = Timer(_Constants.soundPreviewDuration, () async {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingPreview = false);
        debugPrint('⏹️ Preview stopped after 5s');
      });
    } catch (e) {
      debugPrint('❌ Error playing sound preview: $e');
      // Try fallback URL based on sound name
      String? fallbackUrl;
      if (sound.name == 'Rain' || sound.name == 'River') {
        fallbackUrl =
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/rain-v2.mp3';
      } else if (sound.name == 'White Noise') {
        fallbackUrl =
            'https://fbjxvlzhxsxiyxuuvefu.supabase.co/storage/v1/object/public/sounds/White-Noise.mp3';
      }

      if (fallbackUrl != null) {
        try {
          await _audioPlayer.setSourceUrl(fallbackUrl);
          await _audioPlayer.resume();
          if (mounted) setState(() => _isPlayingPreview = true);

          _previewTimer = Timer(_Constants.soundPreviewDuration, () async {
            await _audioPlayer.stop();
            if (mounted) setState(() => _isPlayingPreview = false);
          });
        } catch (_) {
          if (mounted) setState(() => _isPlayingPreview = false);
        }
      } else {
        if (mounted) setState(() => _isPlayingPreview = false);
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
      debugPrint('🔔 Playing notification preview');
    } catch (e) {
      debugPrint('❌ Error playing notification preview: $e');
    }
  }

  // =============================================================================
  // CAMERA CONTROL
  // =============================================================================

  void _setupCameraStatusListener() {
    RikazLightService.onCameraStatusChanged = (String status) {
      if (mounted) {
        setState(() => _cameraStatus = status);
        debugPrint('📷 Camera status updated: $status');
      }
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
      final bool success = await RikazLightService.enableCameraDetection(
        sensitivity: _getSensitivityLevel(),
        notificationStyle: notificationStyle,
        sleepTrigger: sleepTrigger,
        presenceTrigger: presenceTrigger,
        phoneTrigger: phoneTrigger,
      );
      if (success) {
        debugPrint('✅ Camera detection enabled');
        _showSnackBar('Camera detection enabled', Colors.green.shade600);
      } else {
        setState(() => isCameraDetectionEnabled = false);
        _showSnackBar('Failed to enable camera', errorIndicatorRed);
      }
    } else {
      final bool success = await RikazLightService.disableCameraDetection();
      if (success) {
        debugPrint('📷 Camera detection disabled');
        _showSnackBar('Camera detection disabled', secondaryTextGrey);
      }
    }
  }

  String _getSensitivityLevel() {
    if (sensitivity <= 0.33) return 'high';
    if (sensitivity <= 0.67) return 'medium';
    return 'low';
  }

  String _getSensitivityLabel() {
    if (sensitivity <= 0.33) return 'High (30s)';
    if (sensitivity <= 0.67) return 'Medium (60s)';
    return 'Low (90s)';
  }

Future<void> _updateCameraSensitivity(double value) async {
    setState(() { 
      sensitivity = value;
      _selectedPresetId = null; // <--- ADDED HERE
    });
    _updateCameraSettings();
  }

Future<void> _updateNotificationStyle(String style) async {
    setState(() { 
      notificationStyle = style;
      _selectedPresetId = null; // <--- ADDED HERE
    });
    _updateCameraSettings();
    if (style == 'strong') await _playNotificationPreview();
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  double _adaptiveFontSize(double baseScreenWidthMultiplier) {
    final baseSize = _screenWidth * baseScreenWidthMultiplier;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return baseSize / (1.0 + (textScaleFactor - 1.0) * 0.9);
  }

  Color _getSoundColor(String soundName) {
    return _Constants.soundColors[soundName] ??
        _Constants.soundColors['default']!;
  }

  void _scrollToBlocksCounter() {
    if (_blocksCounterKey.currentContext != null) {
      Scrollable.ensureVisible(
        _blocksCounterKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  // =============================================================================
  // SESSION START HANDLING
  // =============================================================================

  void handleStartSessionPress() {
    if (sessionMode == SessionMode.pomodoro && numberOfBlocks == 0) {
      setState(() => _blocksFieldError = true);
      _scrollToBlocksCounter();
      return;
    }

    if (!isRikazToolConnected) {
      _showDialog(
        title: 'Hardware Not Connected',
        content: 'You haven\'t connected your Rikaz Tools hardware yet.',
        icon: Icons.lightbulb_outline,
        iconColor: accentThemeColor,
        cancelText: 'Connect Now',
        confirmText: 'Start Anyway',
        onConfirm: _navigateToSession,
        
      );
      // =============================================================================
  // TEMPORARY DEMO FUNCTION (REMOVE AFTER DASHBOARD DEVELOPMENT)
  // =============================================================================
  void _startDemoSession() {
    _previewTimer?.cancel();
    _audioPlayer.stop();

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': 'custom',
        'duration': '1', // Forces a 1-minute session
        'numberOfBlocks': null,
        'isCameraDetectionEnabled': false, // Turn off camera to skip hardware checks
        'sensitivity': 0.5,
        'notificationStyle': 'subtle',
        'subtleAlertType': 'light',
        'sleepTrigger': true,
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
      return;
    }

    if (_deviceWasConnected && !isRikazToolConnected && _hasShownDisconnectWarning) {
      _showDialog(
        title: 'Device Unplugged',
        content:
            'Rikaz Tools device appears to be unplugged.\n\nThe session will start without hardware control.',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange.shade600,
        cancelText: 'Cancel',
        confirmText: 'Start Anyway',
        onConfirm: _navigateToSession,
      );
      return;
    }

    _navigateToSession();
  }

  void _navigateToSession() {
    final String sessionType =
        sessionMode == SessionMode.pomodoro ? 'pomodoro' : 'custom';
    final String durationValue = sessionMode == SessionMode.pomodoro
        ? pomodoroDuration
        : customDuration.toInt().toString();
    final String? blocks = sessionMode == SessionMode.pomodoro
        ? numberOfBlocks.toInt().toString()
        : null;

    _previewTimer?.cancel();
    _audioPlayer.stop();

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': sessionType,
        'duration': durationValue,
        'numberOfBlocks': blocks,
        'isCameraDetectionEnabled': isCameraDetectionEnabled,
        'sensitivity': sensitivity,
        'notificationStyle': notificationStyle,
        'subtleAlertType': subtleAlertType,
        'sleepTrigger': sleepTrigger,
        'presenceTrigger': presenceTrigger,
        'phoneTrigger': phoneTrigger,
        'rikazConnected': RikazConnectionState.isConnected,
        'selectedSoundId': _selectedSound.id,
        'selectedSoundName': _selectedSound.name,
        'selectedSoundUrl': _selectedSound.filePathUrl,
        'notificationSoundUrl': _notificationSoundUrl,
      },
    );
  }

  // =============================================================================
  // BLE CONNECTION HANDLING
  // =============================================================================

  Future<void> _handleRikazConnect() async {
    if (RikazConnectionState.isConnected) return;
    setState(() => isLoading = true);

    final RikazDevice? selectedDevice = await showDialog<RikazDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RikazDevicePicker(),
    );

    if (!mounted) return;

    if (selectedDevice != null) {
      RikazConnectionState.setConnected(true);
      _connectedDeviceName = selectedDevice.name;

      // FIX: Show confirmation AND camera toggle immediately — no blocking await
      setState(() {
        isLoading = false;
        _showRikazConfirmation = true;
        isConfigurationOpen = true; // Show camera section immediately
      });

      debugPrint('✅ Rikaz Tools: Connected to ${selectedDevice.name}');

      // Run pulse animation without blocking
      _pulseController.forward().then((_) => _pulseController.reverse()).then((_) {
        if (mounted) _pulseController.forward().then((_) => _pulseController.reverse());
      });

      _startConnectionMonitoring();
      _setupCameraStatusListener();

      // Hide confirmation banner after 2 seconds
      Future.delayed(_Constants.connectionSuccessDuration, () {
        if (mounted) setState(() => _showRikazConfirmation = false);
      });
    } else {
      if (mounted) {
        setState(() => isLoading = false);
        Future.microtask(() {
          if (mounted &&
              _slideKey.currentState != null &&
              _slideKey.currentContext != null) {
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

    _connectionCheckTimer =
        Timer.periodic(_Constants.connectionCheckInterval, (timer) async {
      if (!mounted || !RikazConnectionState.isConnected) {
        timer.cancel();
        return;
      }

      final bool stillConnected = await RikazLightService.isConnected();
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
      } else if (stillConnected && !_deviceWasConnected) {
        _deviceWasConnected = true;
        _showSnackBar('Rikaz device reconnected!', Colors.green.shade600);
      }
    });
  }

  void _showDeviceLostWarning() {
    if (!mounted) return;
    _showDialog(
      title: 'Hardware Disconnected',
      content:
          'The Bluetooth connection to your Rikaz device was lost. Please check your device and try reconnecting.',
      icon: Icons.bluetooth_disabled_rounded,
      iconColor: errorIndicatorRed,
      cancelText: 'Close',
      confirmText: 'Reconnect Now',
      onConfirm: _handleRikazConnect,
      barrierDismissible: false,
    );
    debugPrint('⚠️ RIKAZ: Connection lost');
  }

  Future<void> _handleRikazDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _buildDisconnectDialog(dialogContext),
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
        _showSnackBar('Hardware disconnected', Colors.green.shade600);
      }
      debugPrint('🔌 Rikaz Tools: Disconnected');
    }
  }

  // =============================================================================
  // UI HELPER WIDGETS
  // =============================================================================

  void _showDialog({
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
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius)),
        backgroundColor: cardBackground,
        child: Padding(
          padding: EdgeInsets.all(_screenWidth * 0.045),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.035),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child:
                    Icon(icon, color: iconColor, size: _screenWidth * 0.10),
              ),
              SizedBox(height: _screenHeight * 0.018),
              Text(
                title,
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.042),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: mediumGap),
              Text(
                content,
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.032),
                    color: secondaryTextGrey,
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: _screenHeight * 0.022),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onCancel ?? () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            vertical: _screenHeight * 0.013),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: secondaryTextGrey.withOpacity(0.3)),
                        ),
                      ),
                      child: Text(cancelText,
                          style: TextStyle(
                              color: secondaryTextGrey,
                              fontSize: _adaptiveFontSize(0.033),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(width: _screenWidth * 0.025),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (onConfirm != null) onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryThemeColor,
                        padding: EdgeInsets.symmetric(
                            vertical: _screenHeight * 0.013),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: Text(confirmText,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: _adaptiveFontSize(0.033),
                              fontWeight: FontWeight.bold)),
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

  Widget _buildDisconnectDialog(BuildContext dialogContext) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius)),
      backgroundColor: cardBackground,
      child: Padding(
        padding: EdgeInsets.all(_screenWidth * 0.045),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(_screenWidth * 0.035),
              decoration: BoxDecoration(
                  color: errorIndicatorRed.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.power_settings_new_rounded,
                  color: errorIndicatorRed, size: _screenWidth * 0.10),
            ),
            SizedBox(height: _screenHeight * 0.018),
            Text('Disconnect Hardware?',
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.042),
                    fontWeight: FontWeight.bold,
                    color: primaryTextDark),
                textAlign: TextAlign.center),
            SizedBox(height: mediumGap),
            Text(
              'This will disable hardware features for your sessions. You can reconnect anytime.',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.032),
                  color: secondaryTextGrey,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: _screenHeight * 0.022),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: _screenHeight * 0.013),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: secondaryTextGrey.withOpacity(0.3)),
                      ),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: secondaryTextGrey,
                            fontSize: _adaptiveFontSize(0.033),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: _screenWidth * 0.025),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: errorIndicatorRed,
                      padding: EdgeInsets.symmetric(
                          vertical: _screenHeight * 0.013),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Text('Disconnect',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: _adaptiveFontSize(0.033),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildIconLabel({
    required IconData icon,
    required String label,
    required Color iconColor,
    double? iconSize,
    TextStyle? textStyle,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize ?? _adaptiveFontSize(0.045)),
        SizedBox(width: _screenWidth * 0.015),
        Text(label, style: textStyle ?? subheadingStyle),
      ],
    );
  }

  Widget _buildCircularIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    final adjustedSize = size * 0.7;
    return Container(
      width: adjustedSize,
      height: adjustedSize,
      decoration: BoxDecoration(
        color: onPressed != null
            ? accentThemeColor
            : secondaryTextGrey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: onPressed != null
              ? Colors.white
              : secondaryTextGrey.withOpacity(0.5),
          size: adjustedSize * 0.42,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    Color? backgroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? dfDeepTeal,
          padding:
              EdgeInsets.symmetric(vertical: _screenHeight * 0.018),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: (backgroundColor ?? dfDeepTeal).withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: _adaptiveFontSize(0.055)),
              SizedBox(width: _screenWidth * 0.015),
            ],
            Text(
              text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: _adaptiveFontSize(0.038),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // CONFIGURATION WIDGETS
  // =============================================================================
Widget _buildPresetRow() {
    // Only show if Rikaz is connected and camera is enabled
    if (!isRikazToolConnected || !isCameraDetectionEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: largeGap),
        Text('Quick Select Preset', style: subheadingStyle),
        SizedBox(height: mediumGap),
        SizedBox(
          height: 45,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              //Disabled at 5 max)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(
                    Icons.add_circle_outline, 
                    size: 18, 
                    color: _userPresets.length >= 5 ? secondaryTextGrey : Colors.white
                  ),
                  label: Text(
                    'New', 
                    style: TextStyle(
                      color: _userPresets.length >= 5 ? secondaryTextGrey : Colors.white, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  backgroundColor: _userPresets.length >= 5 
                      ? secondaryTextGrey.withOpacity(0.2) 
                      : dfTealCyan,
                  // Disable the button entirely if they hit the limit of 5
                  onPressed: _userPresets.length >= 5 ? null : _handleNewPresetRedirect,
                ),
              ),
              if (_isLoadingPresets)
                const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CircularProgressIndicator(strokeWidth: 2)))
              else
                ..._userPresets.map((preset) {
                  final isSelected = _selectedPresetId == preset['Preset_id'].toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(preset['preset_name']),
                      selected: isSelected,
                      selectedColor: dfDeepTeal,
                      backgroundColor: cardBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : primaryTextDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      ),
                      onSelected: (selected) {
                        if (selected) _applyPreset(preset);
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPomodoroSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration Options', style: subheadingStyle),
        SizedBox(height: mediumGap),
        _buildDurationOption('25min', '+ 5 min break'),
        _buildDurationOption('50min', '+ 10 min break'),
        SizedBox(height: largeGap),
        _buildBlocksCounter(),
      ],
    );
  }

  Widget _buildDurationOption(String label, String breakText) {
    final isSelected = pomodoroDuration == label;
    return GestureDetector(
      onTap: () => setState(() => pomodoroDuration = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: _screenHeight * 0.01),
        padding: EdgeInsets.all(_screenWidth * 0.038),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentThemeColor
                : secondaryTextGrey.withOpacity(0.2),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _screenWidth * 0.058,
              height: _screenWidth * 0.058,
              decoration: BoxDecoration(
                color: isSelected ? accentThemeColor : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: secondaryTextGrey.withOpacity(0.35), width: 1.8),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      color: Colors.white, size: _screenWidth * 0.035)
                  : null,
            ),
            SizedBox(width: _screenWidth * 0.035),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: _adaptiveFontSize(0.039),
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentThemeColor : primaryTextDark)),
                  SizedBox(height: _screenHeight * 0.002),
                  Text(breakText, style: captionStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlocksCounter() {
    return Column(
      key: _blocksCounterKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconLabel(
          icon: Icons.grid_view_rounded,
          label: 'Number of Blocks',
          iconColor: accentThemeColor,
        ),
        SizedBox(height: mediumGap),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              horizontal: _screenWidth * 0.025,
              vertical: _screenHeight * 0.008),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(
              color: _blocksFieldError
                  ? errorIndicatorRed
                  : secondaryTextGrey.withOpacity(0.2),
              width: _blocksFieldError ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircularIconButton(
                icon: Icons.remove_rounded,
                onPressed: numberOfBlocks > _Constants.minPomodoroBlocks
                    ? () => setState(() => numberOfBlocks--)
                    : null,
                size: _screenWidth * 0.11,
              ),
              Text(
                numberOfBlocks == 0 ? '-' : numberOfBlocks.toInt().toString(),
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.14),
                    fontWeight: FontWeight.w500,
                    color: _blocksFieldError
                        ? errorIndicatorRed
                        : primaryTextDark,
                    height: 1.1),
              ),
              _buildCircularIconButton(
                icon: Icons.add_rounded,
                onPressed: numberOfBlocks < _Constants.maxPomodoroBlocks
                    ? () => setState(() {
                          numberOfBlocks++;
                          if (numberOfBlocks > 0) _blocksFieldError = false;
                        })
                    : null,
                size: _screenWidth * 0.11,
              ),
            ],
          ),
        ),
        SizedBox(height: mediumGap),
        Padding(
          padding: EdgeInsets.only(left: _screenWidth * 0.01),
          child: Row(
            children: [
              Icon(
                _blocksFieldError
                    ? Icons.error_outline
                    : Icons.info_outline_rounded,
                color: _blocksFieldError ? errorIndicatorRed : accentThemeColor,
                size: _adaptiveFontSize(0.035),
              ),
              SizedBox(width: _screenWidth * 0.012),
              Expanded(
                child: Text(
                  _blocksFieldError
                      ? 'Please select number of blocks to continue'
                      : 'One block = focus session + break',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.029),
                      color: _blocksFieldError
                          ? errorIndicatorRed
                          : secondaryTextGrey,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDurationSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(_screenWidth * 0.022),
              decoration: BoxDecoration(
                  color: accentThemeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.schedule_rounded,
                  color: accentThemeColor, size: _adaptiveFontSize(0.045)),
            ),
            SizedBox(width: _screenWidth * 0.025),
            Text('Session Duration', style: subheadingStyle),
          ],
        ),
        SizedBox(height: largeGap),
        Center(
          child: Column(
            children: [
              Text('${customDuration.toInt()}',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.14),
                      fontWeight: FontWeight.w500,
                      color: primaryTextDark,
                      height: 1)),
              SizedBox(height: smallGap),
              Text('minutes',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.035),
                      fontWeight: FontWeight.w500,
                      color: secondaryTextGrey)),
            ],
          ),
        ),
        SizedBox(height: mediumGap),
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: _screenWidth * 0.035,
                vertical: _screenHeight * 0.006),
            decoration: BoxDecoration(
              color: secondaryTextGrey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: secondaryTextGrey.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded,
                    color: secondaryTextGrey,
                    size: _adaptiveFontSize(0.032)),
                SizedBox(width: _screenWidth * 0.012),
                Text('No Breaks',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.03),
                        fontWeight: FontWeight.w600,
                        color: secondaryTextGrey)),
              ],
            ),
          ),
        ),
        SizedBox(height: largeGap),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentThemeColor,
            inactiveTrackColor: lightestAccentColor.withOpacity(0.4),
            thumbColor: accentThemeColor,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 2),
            overlayColor: accentThemeColor.withOpacity(0.18),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
            trackHeight: 5,
          ),
          child: Slider(
            value: customDuration,
            min: _Constants.minCustomDuration,
            max: _Constants.maxCustomDuration,
            divisions:
                (_Constants.maxCustomDuration - _Constants.minCustomDuration)
                    .toInt(),
            label: '${customDuration.toInt()} min',
            onChanged: (v) => setState(() => customDuration = v),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _screenWidth * 0.015),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10 min',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.026),
                      color: secondaryTextGrey,
                      fontWeight: FontWeight.w600)),
              Text('120 min',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.026),
                      color: secondaryTextGrey,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        SizedBox(height: mediumGap),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: accentThemeColor, size: _adaptiveFontSize(0.037)),
            SizedBox(width: _screenWidth * 0.015),
            Expanded(
                child: Text('Continuous focus without interruptions',
                    style: captionStyle)),
          ],
        ),
      ],
    );
  }

  // =============================================================================
  // HARDWARE CONNECTION WIDGETS
  // =============================================================================

  Widget _buildRikazConnect() {
    return Container(
      padding: cardPadding,
      margin: EdgeInsets.only(bottom: largeGap),
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
              Icon(
                isRikazToolConnected
                    ? Icons.check_circle
                    : Icons.bluetooth,
                color: isRikazToolConnected
                    ? Colors.green.shade600
                    : accentThemeColor,
                size: _adaptiveFontSize(0.05),
              ),
              SizedBox(width: _screenWidth * 0.015),
              Expanded(
                child: Text(
                  isRikazToolConnected
                      ? 'Hardware Connected'
                      : 'Connect Hardware',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.04),
                      fontWeight: FontWeight.bold,
                      color: primaryTextDark),
                ),
              ),
              if (showDisconnectButton)
                IconButton(
                  icon: const Icon(Icons.power_settings_new,
                      color: errorIndicatorRed, size: 20),
                  onPressed: _handleRikazDisconnect,
                  tooltip: 'Disconnect',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: mediumGap),
          _buildHardwareStatusVisual(),

          // FIX: Success banner and camera section shown together immediately
          if (_showRikazConfirmation) ...[
            SizedBox(height: mediumGap),
            _buildSuccessMessage(),
          ],

          if (isRikazToolConnected) ...[
            SizedBox(height: mediumGap),
            Text(
              'Your Rikaz Tools hardware is ready.',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.031),
                  color: secondaryTextGrey,
                  height: 1.3),
            ),
            SizedBox(height: largeGap),
            // FIX: Camera toggle always visible once connected, no delay
            _buildCameraToggle(),
          ] else ...[
            SizedBox(height: _screenHeight * 0.015),
            SlideAction(
              key: _slideKey,
              text: isLoading ? "Scanning..." : "Slide to Connect",
              textStyle: TextStyle(
                  fontSize: _adaptiveFontSize(0.035),
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              innerColor: cardBackground,
              outerColor: accentThemeColor,
              sliderButtonIcon: Container(
                decoration: const BoxDecoration(
                    color: cardBackground, shape: BoxShape.circle),
                child: Icon(Icons.bluetooth_searching,
                    color: accentThemeColor, size: _screenWidth * 0.055),
              ),
              sliderButtonIconPadding: 10,
              height: _screenHeight * 0.058,
              borderRadius: cardBorderRadius,
              onSubmit: isLoading
                  ? null
                  : () async {
                      await _handleRikazConnect();
                      return null;
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraToggle() {
    return Container(
      padding: EdgeInsets.all(_screenWidth * 0.035),
      decoration: BoxDecoration(
        color: accentThemeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: accentThemeColor.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(_screenWidth * 0.02),
                decoration: BoxDecoration(
                    color: accentThemeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.videocam_rounded,
                    color: accentThemeColor, size: _adaptiveFontSize(0.045)),
              ),
              SizedBox(width: _screenWidth * 0.025),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Camera Detection',
                        style: TextStyle(
                            fontSize: _adaptiveFontSize(0.038),
                            fontWeight: FontWeight.bold,
                            color: primaryTextDark)),
                    if (_cameraStatus == 'connected') ...[
                      SizedBox(height: _screenHeight * 0.003),
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600,
                              size: _adaptiveFontSize(0.03)),
                          SizedBox(width: _screenWidth * 0.008),
                          Text('Camera Ready',
                              style: TextStyle(
                                  fontSize: _adaptiveFontSize(0.028),
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // FIX: Camera preview button removed entirely
              Switch(
                value: isCameraDetectionEnabled,
                onChanged: _toggleCameraDetection,
                activeThumbColor: accentThemeColor,
                inactiveThumbColor: secondaryTextGrey,
              ),
            ],
          ),
            if (isCameraDetectionEnabled) ...[
            SizedBox(height: largeGap),
            _buildPresetRow(), 
            SizedBox(height: largeGap),
            const Divider(height: 32), 
            _buildCameraOptions(),
          ],
        ],
      ),
    );
  }

  // =============================================================================
  // FIX: Trigger names consistent + icons added
  // =============================================================================

  Widget _buildCameraOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Triggers
        Container(
          padding: EdgeInsets.all(_screenWidth * 0.03),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secondaryTextGrey.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.radar_rounded,
                      color: accentThemeColor, size: _adaptiveFontSize(0.04)),
                  SizedBox(width: _screenWidth * 0.02),
                  Text('Detection Triggers',
                      style: TextStyle(
                          fontSize: _adaptiveFontSize(0.033),
                          fontWeight: FontWeight.bold,
                          color: primaryTextDark)),
                ],
              ),
              SizedBox(height: _screenHeight * 0.004),
              Text('Select at least one trigger',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.028),
                      color: secondaryTextGrey)),
              SizedBox(height: _screenHeight * 0.008),

              // --- Sleeping ---
              _buildTriggerTile(
                icon: Icons.bedtime_rounded,
                label: 'Sleeping',
                value: sleepTrigger,
                onChanged: (val) {
                  if (val == false && !presenceTrigger && !phoneTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
                  }
           setState(() { 
                    sleepTrigger = val ?? true;
                    _selectedPresetId = null; // <--- ADDED HERE
                  });
                  _updateCameraSettings();
                },
              ),

              // --- Absence ---
              _buildTriggerTile(
                icon: Icons.person_off_rounded,
                label: 'Absence',
                value: presenceTrigger,
                onChanged: (val) {
                  if (val == false && !sleepTrigger && !phoneTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
       }
                  setState(() { 
                    presenceTrigger = val ?? false;
                    _selectedPresetId = null; // <--- ADDED HERE
                  });
                  _updateCameraSettings();
                },
              ),

              // --- Phone Use ---
              _buildTriggerTile(
                icon: Icons.smartphone_rounded,
                label: 'Phone Use',
                value: phoneTrigger,
                onChanged: (val) {
                  if (val == false && !sleepTrigger && !presenceTrigger) {
                    _showSnackBar('Select at least one trigger.', errorIndicatorRed);
                    return;
}
                  setState(() { 
                    phoneTrigger = val ?? false;
                    _selectedPresetId = null; // <--- ADDED HERE
                  });
                  _updateCameraSettings();
                },
              ),
            ],
          ),
        ),
        SizedBox(height: largeGap),

        // Sensitivity
        Text('Sensitivity',
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.035),
                fontWeight: FontWeight.bold,
                color: primaryTextDark)),
        SizedBox(height: smallGap),
        Text(_getSensitivityLabel(),
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.032),
                color: accentThemeColor,
                fontWeight: FontWeight.w600)),
        SizedBox(height: mediumGap),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentThemeColor,
            inactiveTrackColor: lightestAccentColor.withOpacity(0.4),
            thumbColor: accentThemeColor,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
            overlayColor: accentThemeColor.withOpacity(0.18),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            trackHeight: 4,
          ),
          child: Slider(
            value: sensitivity,
            min: 0.0,
            max: 1.0,
            divisions: 2,
            onChanged: _updateCameraSensitivity,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _screenWidth * 0.01),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('High (30s)',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.026),
                      color: secondaryTextGrey,
                      fontWeight: FontWeight.w500)),
              Text('Low (90s)',
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.026),
                      color: secondaryTextGrey,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        SizedBox(height: largeGap),

        // Notification Style
        Text('Notification Style',
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.035),
                fontWeight: FontWeight.bold,
                color: primaryTextDark)),
        SizedBox(height: mediumGap),
        Row(
          children: [
            Expanded(
                child: _buildNotificationStyleOption(
                    'subtle', Icons.volume_down_rounded, 'Subtle')),
            SizedBox(width: _screenWidth * 0.025),
            Expanded(
                child: _buildNotificationStyleOption(
                    'strong', Icons.volume_up_rounded, 'Strong')),
          ],
        ),
        SizedBox(height: mediumGap),

        // Subtle sub-options (radio)
        if (notificationStyle == 'subtle') ...[
          Container(
            padding: EdgeInsets.all(_screenWidth * 0.03),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: secondaryTextGrey.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subtle Alert Type',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.032),
                        fontWeight: FontWeight.bold,
                        color: primaryTextDark)),
                SizedBox(height: smallGap),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Light Only',
                            style: TextStyle(
                                fontSize: _adaptiveFontSize(0.03),
                                color: primaryTextDark,
                                fontWeight: FontWeight.w600)),
                        value: 'light',
                        groupValue: subtleAlertType,
                        activeColor: accentThemeColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) {
                          setState(() { 
                            subtleAlertType = v!;
                            _selectedPresetId = null; // <--- ADDED HERE
                          });
                          _updateCameraSettings();
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Sound Only',
                            style: TextStyle(
                                fontSize: _adaptiveFontSize(0.03),
                                color: primaryTextDark,
                                fontWeight: FontWeight.w600)),
                        value: 'sound',
                        groupValue: subtleAlertType,
                        activeColor: accentThemeColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (v) {
                          setState(() => subtleAlertType = v!);
                          _updateCameraSettings();
                        },
                      ),
                    ),
                  ],
                ),
                Text('Applied during the session.',
                    style: TextStyle(
                        fontSize: _adaptiveFontSize(0.028),
                        color: secondaryTextGrey)),
              ],
            ),
          ),
          SizedBox(height: mediumGap),
        ],

        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: accentThemeColor, size: _adaptiveFontSize(0.033)),
            SizedBox(width: _screenWidth * 0.012),
            Expanded(
              child: Text(
                notificationStyle == 'subtle'
                    ? 'Non-intrusive alerts (customizable above)'
                    : 'Combined light + audio alerts',
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.028), color: secondaryTextGrey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Single trigger row with icon + label + checkbox
  Widget _buildTriggerTile({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: accentThemeColor,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Row(
        children: [
          Icon(icon,
              color: value ? accentThemeColor : secondaryTextGrey,
              size: _adaptiveFontSize(0.038)),
          SizedBox(width: _screenWidth * 0.02),
          Text(
            label,
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.032),
                color: value ? primaryTextDark : secondaryTextGrey,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationStyleOption(
      String value, IconData icon, String label) {
    final isSelected = notificationStyle == value;
    return GestureDetector(
      onTap: () => _updateNotificationStyle(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
            horizontal: _screenWidth * 0.03, vertical: _screenHeight * 0.012),
        decoration: BoxDecoration(
          color: isSelected
              ? accentThemeColor.withOpacity(0.15)
              : cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? accentThemeColor : secondaryTextGrey.withOpacity(0.2),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? accentThemeColor : secondaryTextGrey,
                size: _adaptiveFontSize(0.042)),
            SizedBox(width: _screenWidth * 0.015),
            Text(label,
                style: TextStyle(
                    fontSize: _adaptiveFontSize(0.033),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? accentThemeColor : secondaryTextGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareStatusVisual() {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: _screenHeight * 0.015),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRikazToolConnected
              ? [
                  accentThemeColor.withOpacity(0.12),
                  lightestAccentColor.withOpacity(0.08)
                ]
              : [
                  secondaryTextGrey.withOpacity(0.06),
                  secondaryTextGrey.withOpacity(0.04)
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isRikazToolConnected
                ? accentThemeColor.withOpacity(0.3)
                : secondaryTextGrey.withOpacity(0.18),
            width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AnimatedHardwareIcon(
            icon: Icons.lightbulb_rounded,
            label: 'Smart Light',
            isActive: isRikazToolConnected,
            pulseAnimation: _pulseAnimation,
            showConfirmation: _showRikazConfirmation,
            screenWidth: _screenWidth,
            screenHeight: _screenHeight,
            adaptiveFontSize: _adaptiveFontSize,
          ),
          Container(
            width: 1.2,
            height: _screenHeight * 0.04,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  secondaryTextGrey.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          _AnimatedHardwareIcon(
            icon: Icons.computer_rounded,
            label: 'Screen Monitor',
            isActive: isRikazToolConnected,
            pulseAnimation: _pulseAnimation,
            showConfirmation: _showRikazConfirmation,
            screenWidth: _screenWidth,
            screenHeight: _screenHeight,
            adaptiveFontSize: _adaptiveFontSize,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: _Constants.successAnimationDuration,
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final clampedValue = value.clamp(0.0, 1.0);
          final clampedScale = value.clamp(0.5, 1.2);
          return Transform.scale(
            scale: clampedScale,
            child: Opacity(
              opacity: clampedValue,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600,
                      size: _adaptiveFontSize(0.045)),
                  SizedBox(width: _screenWidth * 0.02),
                  Text('Connection Successful!',
                      style: TextStyle(
                          fontSize: _adaptiveFontSize(0.037),
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: EdgeInsets.all(_screenHeight * 0.004),
      decoration: BoxDecoration(
          color: secondaryTextGrey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(11)),
      child: Row(
        children: [
          _buildToggleButton(SessionMode.pomodoro, 'Pomodoro', Icons.timer),
          SizedBox(width: _screenWidth * 0.015),
          _buildToggleButton(
              SessionMode.custom, 'Custom Focus', Icons.tune),
        ],
      ),
    );
  }

  Widget _buildToggleButton(SessionMode mode, String text, IconData icon) {
    final isSelected = sessionMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            sessionMode = mode;
            if (mode == SessionMode.custom) _blocksFieldError = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              EdgeInsets.symmetric(vertical: _screenHeight * 0.013),
          decoration: BoxDecoration(
            color: isSelected ? dfDeepTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: dfDeepTeal.withOpacity(0.25),
                        blurRadius: 6)
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: _screenWidth * 0.045,
                  color:
                      isSelected ? Colors.white : secondaryTextGrey),
              SizedBox(width: _screenWidth * 0.015),
              Text(text,
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.033),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : secondaryTextGrey)),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================================
  // FIX: Sound Selection — preview indicator shown
  // =============================================================================

  Widget _buildSoundSelection() {
    return Container(
      padding: cardPadding,
      decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          boxShadow: subtleShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconLabel(
            icon: Icons.music_note_rounded,
            label: 'Background Sound',
            iconColor: accentThemeColor,
            iconSize: _adaptiveFontSize(0.05),
            textStyle: TextStyle(
                fontSize: _adaptiveFontSize(0.04),
                fontWeight: FontWeight.bold,
                color: primaryTextDark),
          ),
          SizedBox(height: smallGap),
          Text('Select a sound to play during your focus session',
              style: TextStyle(
                  fontSize: _adaptiveFontSize(0.031),
                  color: secondaryTextGrey)),
          SizedBox(height: _screenHeight * 0.015),
          if (!_soundsLoaded)
            Center(
              child: Padding(
                padding: EdgeInsets.all(_screenHeight * 0.015),
                child: CircularProgressIndicator(
                    color: accentThemeColor, strokeWidth: 2.5),
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: _screenWidth * 0.035, vertical: smallGap),
              decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: accentThemeColor.withOpacity(0.25), width: 1.3)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSound.id,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: accentThemeColor, size: _screenWidth * 0.065),
                  style: TextStyle(
                      fontSize: _adaptiveFontSize(0.037),
                      fontWeight: FontWeight.w600,
                      color: primaryTextDark),
                  dropdownColor: cardBackground,
                  onChanged: (String? newSoundId) {
                    if (newSoundId != null) {
                      final newSound = _availableSounds.firstWhere(
                          (s) => s.id == newSoundId,
                          orElse: () => SoundOption.off());
                      setState(() => _selectedSound = newSound);
                      _playPreview(newSound); // FIX: always calls fixed preview
                    }
                  },
                  items: _availableSounds
                      .map<DropdownMenuItem<String>>((sound) {
                    final soundColor = _getSoundColor(sound.name);
                    return DropdownMenuItem<String>(
                      value: sound.id,
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(_screenWidth * 0.018),
                            decoration: BoxDecoration(
                                color: soundColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(7)),
                            child: Icon(sound.icon,
                                color: soundColor,
                                size: _screenWidth * 0.045),
                          ),
                          SizedBox(width: _screenWidth * 0.025),
                          Expanded(
                              child: Text(sound.name,
                                  style: TextStyle(
                                      fontSize: _adaptiveFontSize(0.037),
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextDark))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (_soundsLoaded && _selectedSound.id != 'off') ...[
            SizedBox(height: mediumGap),
            Row(
              children: [
                // FIX: Show live indicator while preview plays
                if (_isPlayingPreview)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: accentThemeColor, strokeWidth: 2),
                      ),
                      SizedBox(width: _screenWidth * 0.015),
                      Text('Playing preview...',
                          style: TextStyle(
                              fontSize: _adaptiveFontSize(0.028),
                              color: accentThemeColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.volume_up_rounded,
                          color: accentThemeColor,
                          size: _adaptiveFontSize(0.037)),
                      SizedBox(width: _screenWidth * 0.015),
                      Text('5-second preview plays on selection',
                          style: TextStyle(
                              fontSize: _adaptiveFontSize(0.028),
                              color: secondaryTextGrey,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =============================================================================
  // MAIN BUILD
  // =============================================================================
// =============================================================================
  // TEMPORARY DEMO FUNCTION (REMOVE AFTER DASHBOARD DEVELOPMENT)
  // =============================================================================
  void _startDemoSession() {
    _previewTimer?.cancel();
    _audioPlayer.stop();

    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': 'custom',
        'duration': '1', 
        'numberOfBlocks': null,
        'isCameraDetectionEnabled': false, 
        'sensitivity': 0.5,
        'notificationStyle': 'subtle',
        'subtleAlertType': 'light',
        'sleepTrigger': true,
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
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    final proportionalHorizontalPadding = _screenWidth * 0.06;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: primaryTextDark, size: _adaptiveFontSize(0.055)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Set Session',
            style: TextStyle(
                fontSize: _adaptiveFontSize(0.042),
                fontWeight: FontWeight.bold,
                color: primaryTextDark)),
        centerTitle: true,
        
        // DEMO BUTTON
        actions: [
          TextButton.icon(
            onPressed: _startDemoSession,
            icon: const Icon(Icons.bug_report_rounded, color: Colors.orange),
            label: const Text('Demo', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                  left: proportionalHorizontalPadding,
                  right: proportionalHorizontalPadding,
                  top: _screenHeight * 0.015,
                  bottom: _screenHeight * 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      sessionMode == SessionMode.pomodoro
                          ? 'Pomodoro Session'
                          : 'Custom Session',
                      style: headingStyle),
                  SizedBox(height: _screenHeight * 0.003),
                  Text(
                      sessionMode == SessionMode.pomodoro
                          ? 'Structured focus and break sessions'
                          : 'Set your own uninterrupted timing',
                      style: bodyStyle),
                  SizedBox(height: largeGap),
                  _buildModeToggle(),
                  SizedBox(height: largeGap),
                  _buildRikazConnect(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: sessionMode == SessionMode.pomodoro
                        ? Column(
                            key: const ValueKey(SessionMode.pomodoro),
                            children: [_buildPomodoroSettings()])
                        : Column(
                            key: const ValueKey(SessionMode.custom),
                            children: [_buildCustomDurationSlider()]),
                  ),
                  SizedBox(height: largeGap),
                  _buildSoundSelection(),
                  SizedBox(height: _screenHeight * 0.015),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                    color: primaryBackground,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -3))
                    ]),
                padding: EdgeInsets.only(
                    left: proportionalHorizontalPadding,
                    right: proportionalHorizontalPadding,
                    top: _screenHeight * 0.015,
                    bottom: _screenHeight * 0.025),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shouldShowHardwareTip)
                      Container(
                        margin: EdgeInsets.only(bottom: mediumGap),
                        padding: EdgeInsets.symmetric(
                            horizontal: _screenWidth * 0.03,
                            vertical: _screenHeight * 0.01),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            accentThemeColor.withOpacity(0.08),
                            lightestAccentColor.withOpacity(0.12)
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accentThemeColor.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                color: accentThemeColor,
                                size: _adaptiveFontSize(0.04)),
                            SizedBox(width: _screenWidth * 0.02),
                            Expanded(
                                child: Text(
                                    'Connect hardware for enhanced features',
                                    style: TextStyle(
                                        fontSize: _adaptiveFontSize(0.03),
                                        color: primaryTextDark,
                                        fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    _buildPrimaryButton(
                        text: 'Start Session',
                        onPressed: canStartSession
                            ? handleStartSessionPress
                            : null,
                        icon: Icons.play_arrow_rounded),
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
// ANIMATED HARDWARE ICON WIDGET
// =============================================================================

class _AnimatedHardwareIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Animation<double> pulseAnimation;
  final bool showConfirmation;
  final double screenWidth;
  final double screenHeight;
  final double Function(double) adaptiveFontSize;

  const _AnimatedHardwareIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.pulseAnimation,
    required this.showConfirmation,
    required this.screenWidth,
    required this.screenHeight,
    required this.adaptiveFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return TweenAnimationBuilder<double>(
              tween:
                  Tween(begin: showConfirmation ? 0.0 : 1.0, end: 1.0),
              duration:
                  Duration(milliseconds: showConfirmation ? 600 : 0),
              curve: Curves.elasticOut,
              builder: (context, popScale, child) {
                final double pulseValue =
                    (showConfirmation ? pulseAnimation.value : 1.0)
                        .clamp(1.0, 1.15);
                final double finalScale =
                    (popScale * pulseValue).clamp(0.8, 1.3);
                final double glowOpacity =
                    (showConfirmation ? 0.6 : 0.4).clamp(0.0, 1.0);
                final double glowBlur = showConfirmation ? 16.0 : 12.0;
                final double glowSpread = showConfirmation ? 2.0 : 1.0;

                return Transform.scale(
                  scale: finalScale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(screenWidth * 0.025),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentThemeColor,
                                accentThemeColor.withOpacity(0.7),
                              ],
                            )
                          : null,
                      color: isActive
                          ? null
                          : secondaryTextGrey.withOpacity(0.12),
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: accentThemeColor
                                      .withOpacity(glowOpacity),
                                  blurRadius: glowBlur,
                                  spreadRadius: glowSpread),
                            ]
                          : null,
                    ),
                    child: Icon(icon,
                        color: isActive ? Colors.white : secondaryTextGrey,
                        size: screenWidth * 0.052),
                  ),
                );
              },
            );
          },
        ),
        SizedBox(height: screenHeight * 0.006),
        Text(label,
            style: TextStyle(
                fontSize: adaptiveFontSize(0.026),
                fontWeight: FontWeight.w600,
                color: isActive ? accentThemeColor : secondaryTextGrey)),
      ],
    );
  }
}