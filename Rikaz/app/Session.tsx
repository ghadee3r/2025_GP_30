// app/Session.tsx
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import type { ColorValue } from 'react-native';
import {
  // 1. IMPORT ALERT
  Alert,
  Animated,
  Easing,
  FlatList,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import Svg, { Circle, Defs, Stop, LinearGradient as SvgLinearGradient } from 'react-native-svg';

/* ──────────────────────────────────────────────────────────
  Types & palettes
  ────────────────────────────────────────────────────────── */
type Stops2 = readonly [ColorValue, ColorValue];
type Stops3 = readonly [ColorValue, ColorValue, ColorValue];

const BREAK_GRADIENT: Stops3 = ['#FFF7ED', '#FFFBEB', '#FEF3C7'];
const FOCUS_GRADIENT: Stops3 = ['#F3F6FF', '#EEF2FF', '#EDE9FE'];

const MODE_COLORS = {
  focus: { ringStart: '#60a5fa', ringEnd: '#2563eb' },
  break: { ringStart: '#fbbf24', ringEnd: '#f59e0b' },
} as const;

/* ──────────────────────────────────────────────────────────
  Small animation helpers
  ────────────────────────────────────────────────────────── */
const usePressScale = () => {
  const scale = useRef(new Animated.Value(1)).current;
  const onPressIn = () => Animated.spring(scale, { toValue: 0.96, useNativeDriver: true }).start();
  const onPressOut = () => Animated.spring(scale, { toValue: 1, useNativeDriver: true }).start();
  return { scale, onPressIn, onPressOut };
};

// Slow ambient hue motion behind the timer (rotate + light scale)
const useHueMotion = () => {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(v, { toValue: 1, duration: 8000, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
        Animated.timing(v, { toValue: 0, duration: 8000, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, []);
  return {
    rotate: v.interpolate({ inputRange: [0, 1], outputRange: ['-8deg', '8deg'] }),
    scale: v.interpolate({ inputRange: [0, 1], outputRange: [1, 1.035] }),
    opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.28] }),
  };
};

/* ──────────────────────────────────────────────────────────
  Inline UI pieces
  ────────────────────────────────────────────────────────── */

// Subtle animated hue behind the timer disc
const HueAura: React.FC<{ mode: 'focus' | 'break' }> = ({ mode }) => {
  const { rotate, scale, opacity } = useHueMotion();
  // Keep tuple type for expo-linear-gradient
  let colors: Stops2;
  if (mode === 'break') colors = ['#f59e0b', '#fbbf24'];
  else colors = ['#3b82f6', '#7c3aed'];

  return (
    <Animated.View
      pointerEvents="none"
      style={[styles.hueBlob, { opacity, transform: [{ rotate }, { scale }] }]}
    >
      <LinearGradient
        colors={colors}
        start={{ x: 0.1, y: 0.1 }}
        end={{ x: 0.9, y: 0.9 }}
        style={styles.hueGradient}
      />
      <BlurView intensity={30} style={styles.hueBlurOverlay} />
    </Animated.View>
  );
};

// Block chip (with pulse for active+running)
const BlockCard = ({
  blockNumber,
  isActive,
  isCompleted,
  isRunning,
  mode,
}: {
  blockNumber: number;
  isActive: boolean;
  isCompleted: boolean;
  isRunning: boolean;
  mode: 'focus' | 'break';
}) => {
  const pulse = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (isActive && isRunning) {
      const loop = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, { toValue: 1, duration: 900, easing: Easing.out(Easing.quad), useNativeDriver: true }),
          Animated.timing(pulse, { toValue: 0, duration: 900, easing: Easing.in(Easing.quad), useNativeDriver: true }),
        ]),
      );
      loop.start();
      return () => loop.stop();
    }
    pulse.stopAnimation(); pulse.setValue(0);
  }, [isActive, isRunning]);

  const scale = pulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] });
  const bg = isActive ? '#2563eb' : isCompleted ? '#10B981' : '#FFFFFF';
  const textColor = isActive ? '#fff' : '#64748B';
  const borderColor = isActive ? 'rgba(37,99,235,0.25)' : '#E5E7EB';
  const labelColor = isActive ? '#1e40af' : isCompleted ? '#065f46' : '#94A3B8';
  const halo = mode === 'break' ? 'rgba(245,158,11,1)' : 'rgba(37,99,235,1)';

  return (
    <View style={{ alignItems: 'center' }}>
      <Animated.View style={{ transform: [{ scale }] }}>
        <View
          style={{
            width: 56, height: 56, borderRadius: 28, justifyContent: 'center', alignItems: 'center',
            backgroundColor: bg, borderWidth: isCompleted ? 0 : 1, borderColor,
            shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 8, shadowOffset: { width: 0, height: 6 }, elevation: 4,
          }}
        >
          {isCompleted ? <MaterialCommunityIcons name="check" size={22} color="#fff" /> : <Text style={{ color: textColor, fontWeight: '700' }}>{blockNumber}</Text>}
          {isActive && isRunning && (
            <Animated.View
              pointerEvents="none"
              style={{
                position: 'absolute', width: 72, height: 72, borderRadius: 36, backgroundColor: halo, opacity: 0.28,
                shadowColor: halo, shadowOpacity: 0.9, shadowRadius: 16, shadowOffset: { width: 0, height: 0 },
              }}
            />
          )}
        </View>
      </Animated.View>
      <Text style={{ marginTop: 6, fontSize: 12, color: labelColor }}>{isActive ? 'Active' : isCompleted ? 'Done' : 'Pending'}</Text>
    </View>
  );
};

// Progress ring (white interior + colored ring)
const CircularProgress = ({
  progress, size = 240, strokeWidth = 8, isBreakMode = false,
}: { progress: number; size?: number; strokeWidth?: number; isBreakMode?: boolean }) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const pct = Math.max(0, Math.min(100, progress)) / 100;
  const dashOffset = circumference - pct * circumference;
  const cx = size / 2, cy = size / 2;

  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size} style={{ transform: [{ rotate: '-90deg' }] }}>
        <Defs>
          <SvgLinearGradient id="gradFocus" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={MODE_COLORS.focus.ringStart} />
            <Stop offset="1" stopColor={MODE_COLORS.focus.ringEnd} />
          </SvgLinearGradient>
          <SvgLinearGradient id="gradBreak" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={MODE_COLORS.break.ringStart} />
            <Stop offset="1" stopColor={MODE_COLORS.break.ringEnd} />
          </SvgLinearGradient>
        </Defs>

        {/* white center */}
        <Circle cx={cx} cy={cy} r={radius} fill="#FFFFFF" />
        {/* background track */}
        <Circle cx={cx} cy={cy} r={radius} stroke="#E5EAF2" strokeWidth={strokeWidth} fill="transparent" />
        {/* progress ring */}
        <Circle
          cx={cx}
          cy={cy}
          r={radius}
          stroke={isBreakMode ? 'url(#gradBreak)' : 'url(#gradFocus)'}
          strokeWidth={strokeWidth}
          fill="transparent"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          strokeLinecap="round"
        />
      </Svg>
    </View>
  );
};

// Sound selector (glass)
type SoundOption = { name: string; duration: string; colors: Stops2; icon: string };
const soundOptions: SoundOption[] = [
  { name: 'Nature Sounds', duration: '00:30:50', colors: ['#34d399', '#10b981'], icon: 'leaf' },
  { name: 'Rain Drops', duration: '00:45:20', colors: ['#60a5fa', '#06b6d4'], icon: 'weather-pouring' },
  { name: 'Ocean Waves', duration: '00:52:10', colors: ['#22d3ee', '#3b82f6'], icon: 'waves' },
  { name: 'Forest Birds', duration: '00:38:45', colors: ['#34d399', '#22c55e'], icon: 'bird' },
  { name: 'White Noise', duration: '01:00:00', colors: ['#9ca3af', '#475569'], icon: 'circle-outline' },
];

const SoundSection = () => {
  const [selected, setSelected] = useState<SoundOption>(soundOptions[0]);
  const [expanded, setExpanded] = useState(false);
  const [playing, setPlaying] = useState(false);
  const playBtn = usePressScale();

  return (
    <GlassCard intensity={30}>
      <Pressable style={styles.soundHeader} onPress={() => setExpanded(e => !e)}>
        <LinearGradient colors={selected.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.soundThumb}>
          <MaterialCommunityIcons name={selected.icon as any} size={26} color="#fff" />
        </LinearGradient>
        <View style={{ flex: 1 }}>
          <Text style={styles.soundTitle}>{selected.name}</Text>
          <Text style={styles.soundSub}>{selected.duration}</Text>
        </View>
        <TouchableWithoutFeedback onPressIn={playBtn.onPressIn} onPressOut={playBtn.onPressOut} onPress={() => setPlaying(p => !p)}>
          <Animated.View style={[styles.playBtn, { transform: [{ scale: playBtn.scale }] }]}>
            <MaterialCommunityIcons name={playing ? 'pause' : 'play'} size={18} color="#fff" />
          </Animated.View>
        </TouchableWithoutFeedback>
        <MaterialCommunityIcons name={expanded ? 'chevron-up' : 'chevron-down'} size={22} color="#9CA3AF" />
      </Pressable>

      <View style={styles.track}><View style={styles.fill} /></View>

      {expanded && (
        <View style={styles.soundList}>
          <FlatList
            data={soundOptions.filter(s => s.name !== selected.name)}
            keyExtractor={(item) => item.name}
            ItemSeparatorComponent={() => <View style={styles.sep} />}
            renderItem={({ item }) => (
              <Pressable
                style={styles.row}
                onPress={() => { setSelected(item); setExpanded(false); setPlaying(false); }}
              >
                <LinearGradient colors={item.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowThumb}>
                  <MaterialCommunityIcons name={item.icon as any} size={20} color="#fff" />
                </LinearGradient>
                <View style={{ flex: 1 }}>
                  <Text style={styles.rowName}>{item.name}</Text>
                  <Text style={styles.rowDuration}>{item.duration}</Text>
                </View>
              </Pressable>
            )}
          />
        </View>
      )}
    </GlassCard>
  );
};

// Glass card wrapper
const GlassCard: React.FC<{ children: React.ReactNode; intensity?: number; style?: any }> = ({ children, intensity = 25, style }) => (
  <BlurView intensity={intensity} tint="light" style={[styles.glassBase, style]}>
    <View style={styles.glassInner}>{children}</View>
  </BlurView>
);

// Reusable animated button
const AnimatedButton: React.FC<{
  onPress: () => void; icon: any; label: string; bg?: string; variant?: 'solid' | 'outline'; style?: any;
}> = ({ onPress, icon, label, bg = '#2563EB', variant = 'solid', style }) => {
  const { scale, onPressIn, onPressOut } = usePressScale();
  const solid = variant === 'solid';
  return (
    <TouchableWithoutFeedback onPressIn={onPressIn} onPressOut={onPressOut} onPress={onPress}>
      <Animated.View
        style={[
          {
            flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
            paddingVertical: 14, borderRadius: 14,
            backgroundColor: solid ? bg : 'rgba(255,255,255,0.85)',
            borderWidth: solid ? 0 : 1, borderColor: solid ? 'transparent' : '#FCA5A5',
            shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 8, shadowOffset: { width: 0, height: 6 }, elevation: 4,
          },
          { transform: [{ scale }] },
          style,
        ]}
      >
        <MaterialCommunityIcons name={icon} color={solid ? '#fff' : '#DC2626'} size={18} style={{ marginRight: 8 }} />
        <Text style={{ color: solid ? '#fff' : '#DC2626', fontWeight: '700' }}>{label}</Text>
      </Animated.View>
    </TouchableWithoutFeedback>
  );
};

/* ──────────────────────────────────────────────────────────
  Screen
  ────────────────────────────────────────────────────────── */
type TimerMode = 'focus' | 'break';
type TimerStatus = 'idle' | 'running' | 'paused';
type PomodoroSettings = { focusTime: number; breakTime: number };

export default function Session() {
  const router = useRouter();
  const { duration, numberOfBlocks } = useLocalSearchParams();

  const preset: PomodoroSettings = String(duration ?? '50min') === '25min' ? { focusTime: 25, breakTime: 5 } : { focusTime: 50, breakTime: 10 };
  const totalBlocks = Math.max(1, Math.min(8, Number(numberOfBlocks ?? 4)));

  const [settings] = useState<PomodoroSettings>(preset);
  const [mode, setMode] = useState<TimerMode>('focus');
  const [status, setStatus] = useState<TimerStatus>('running');
  const [timeLeft, setTimeLeft] = useState(settings.focusTime * 60);
  const [currentBlock, setCurrentBlock] = useState(1);
  const [completedBlocks, setCompletedBlocks] = useState<number[]>([]);

  // animated background crossfade
  const bgAnim = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(bgAnim, { toValue: mode === 'break' ? 1 : 0, duration: 600, easing: Easing.inOut(Easing.quad), useNativeDriver: true }).start();
  }, [mode]);

  // timer tick
  const statusRef = useRef(status), modeRef = useRef(mode), timeRef = useRef(timeLeft), blockRef = useRef(currentBlock);
  useEffect(() => { statusRef.current = status; }, [status]);
  useEffect(() => { modeRef.current = mode; }, [mode]);
  useEffect(() => { timeRef.current = timeLeft; }, [timeLeft]);
  useEffect(() => { blockRef.current = currentBlock; }, [currentBlock]);

  useEffect(() => {
    const id = setInterval(() => {
      if (statusRef.current !== 'running') return;
      const t = timeRef.current;
      if (t <= 1) {
        if (modeRef.current === 'focus') {
          setCompletedBlocks(p => (p.includes(blockRef.current) ? p : [...p, blockRef.current]));
          setMode('break'); setTimeLeft(settings.breakTime * 60);
        } else {
          const next = blockRef.current + 1;
          if (next > totalBlocks) { setStatus('idle'); setMode('focus'); setTimeLeft(settings.focusTime * 60); setCurrentBlock(1); setCompletedBlocks([]); return; }
          setCurrentBlock(next); setMode('focus'); setTimeLeft(settings.focusTime * 60);
        }
      } else setTimeLeft(t - 1);
    }, 1000);
    return () => clearInterval(id);
  }, [settings.breakTime, settings.focusTime, totalBlocks]);

  const formatTime = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  const totalThisPhase = mode === 'focus' ? settings.focusTime * 60 : settings.breakTime * 60;
  const progressPct = ((totalThisPhase - timeLeft) / totalThisPhase) * 100;

  const onPauseOrGames = () => {
    if (mode === 'break') { router.push('/games'); return; }
    setStatus(prev => (prev === 'running' ? 'paused' : 'running'));
  };
  
  // 2. UPDATED onQuit function with confirmation dialog
  const onQuit = () => {
    Alert.alert(
      'End Session?',
      'Are you sure you want to quit the current Pomodoro session? Your progress for this block will be lost.',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Quit',
          style: 'destructive',
          onPress: () => {
            // Reset state
            setStatus('idle');
            setMode('focus');
            setTimeLeft(settings.focusTime * 60);
            setCurrentBlock(1);
            setCompletedBlocks([]);
            
            // Navigate home
            router.push('/');
          },
        },
      ],
      { cancelable: true }
    );
  };

  const gradientFocus: Stops3 = FOCUS_GRADIENT, gradientBreak: Stops3 = BREAK_GRADIENT;

  return (
    <View style={{ flex: 1 }}>
      {/* background gradients crossfade */}
      <Animated.View style={{ ...StyleSheet.absoluteFillObject, opacity: bgAnim.interpolate({ inputRange: [0, 1], outputRange: [1, 0] }) }}>
        <LinearGradient colors={gradientFocus} start={{ x: 0.2, y: 0 }} end={{ x: 1, y: 1 }} style={{ flex: 1 }} />
      </Animated.View>
      <Animated.View style={{ ...StyleSheet.absoluteFillObject, opacity: bgAnim.interpolate({ inputRange: [0, 1], outputRange: [0, 1] }) }}>
        <LinearGradient colors={gradientBreak} start={{ x: 0.2, y: 0 }} end={{ x: 1, y: 1 }} style={{ flex: 1 }} />
      </Animated.View>

      <SafeAreaView style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 16, paddingBottom: 24 }}>
          {/* Mode chip */}
          <View style={{ alignItems: 'center', marginBottom: 16 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, backgroundColor: mode === 'break' ? 'rgba(251,191,36,0.25)' : 'rgba(59,130,246,0.2)' }}>
              <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: mode === 'break' ? '#F59E0B' : '#3B82F6', marginRight: 8 }} />
              <Text style={{ color: mode === 'break' ? '#92400E' : '#1E40AF', fontWeight: '700' }}>{mode === 'break' ? 'Break Time' : 'Focus Session'}</Text>
            </View>
          </View>

          {/* Timer: aura behind + static white disc */}
          <View style={{ alignItems: 'center', marginBottom: 18 }}>
            <View style={styles.timerStack}>
              <HueAura mode={mode} />
              <View style={styles.timerShell}>
                <CircularProgress progress={progressPct} size={240} strokeWidth={8} isBreakMode={mode === 'break'} />
                <View style={styles.timerCenter}>
                  <Text style={{ fontSize: 36, color: '#0F172A', fontWeight: '300', letterSpacing: 0.5 }}>{formatTime(timeLeft)}</Text>
                  <Text style={{ color: '#64748B', fontSize: 12, fontWeight: '600', marginTop: 6 }}>{mode === 'focus' ? 'Stay focused' : 'Relax & recharge'}</Text>
                </View>
              </View>
            </View>
          </View>

          {/* Status card */}
          <GlassCard intensity={20} style={{ marginBottom: 18 }}>
            <View style={{ alignItems: 'center', marginBottom: 14 }}>
              <Text style={{ color: '#0F172A', fontWeight: '700' }}>
                {mode === 'focus' ? `Block ${currentBlock} of ${totalBlocks}` : `Break • ${Math.ceil(timeLeft / 60)} min left`}
              </Text>
              <Text style={{ color: '#94A3B8', fontSize: 12, marginTop: 2 }}>
                {mode === 'focus' ? `Next break in ${Math.ceil(timeLeft / 60)} minutes` : 'Enjoy your well-deserved break'}
              </Text>
            </View>
            <View style={{ flexDirection: 'row' }}>
              <AnimatedButton
                onPress={onPauseOrGames}
                style={{ flex: 1, marginRight: 12 }}
                bg={mode === 'break' ? '#7C3AED' : status === 'paused' ? '#10B981' : '#2563EB'}
                icon={mode === 'break' ? 'controller-classic' : status === 'paused' ? 'play' : 'pause'}
                label={mode === 'break' ? 'Games' : status === 'paused' ? 'Resume' : 'Pause'}
              />
              <AnimatedButton onPress={onQuit} style={{ flex: 1 }} variant="outline" icon="stop" label="Quit" />
            </View>
          </GlassCard>

          {/* Blocks line */}
          <View style={{ flexDirection: 'row', justifyContent: 'center', marginBottom: 18 }}>
            {Array.from({ length: totalBlocks }).map((_, i) => {
              const idx = i + 1;
              return (
                <View key={idx} style={{ marginHorizontal: 10 }}>
                  <BlockCard
                    blockNumber={idx}
                    isActive={mode === 'focus' && currentBlock === idx}
                    isCompleted={completedBlocks.includes(idx)}
                    isRunning={status === 'running'}
                    mode={mode}
                  />
                </View>
              );
            })}
          </View>

          {/* Sounds */}
          <SoundSection />
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

/* ──────────────────────────────────────────────────────────
  Styles
  ────────────────────────────────────────────────────────── */
const styles = StyleSheet.create({
  // glass
  glassBase: {
    borderRadius: 18, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.35)',
    shadowColor: '#000', shadowOpacity: 0.12, shadowRadius: 14, shadowOffset: { width: 0, height: 8 }, elevation: 6,
  },
  glassInner: { padding: 16, backgroundColor: 'rgba(255,255,255,0.35)' },

  // timer
  timerStack: { width: 288, height: 288, alignItems: 'center', justifyContent: 'center', position: 'relative' },
  hueBlob: {
    position: 'absolute', width: 260, height: 260, borderRadius: 130,
    overflow: 'hidden', // Crucial for clipping children to the circle
  },
  hueGradient: {
    ...StyleSheet.absoluteFillObject,
  },
  hueBlurOverlay: {
    ...StyleSheet.absoluteFillObject,
  },
  timerShell: {
    backgroundColor: '#FFFFFF', padding: 24, borderRadius: 9999, borderWidth: 1, borderColor: 'rgba(0,0,0,0.04)',
    shadowColor: '#000', shadowOpacity: 0.18, shadowRadius: 30, shadowOffset: { width: 0, height: 20 }, elevation: 18,
  },
  timerCenter: { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },

  // sounds
  soundHeader: { flexDirection: 'row', alignItems: 'center' },
  soundThumb: { width: 56, height: 56, borderRadius: 16, justifyContent: 'center', alignItems: 'center', marginRight: 12 },
  soundTitle: { fontWeight: '700', color: '#0F172A' },
  soundSub: { color: '#64748B', fontSize: 12, marginTop: 2 },
  playBtn: { width: 44, height: 44, borderRadius: 12, backgroundColor: '#7C3AED', alignItems: 'center', justifyContent: 'center', marginRight: 8 },
  track: { height: 6, backgroundColor: '#E5E7EB', borderRadius: 6, marginTop: 10, overflow: 'hidden' },
  fill: { width: '33%', height: 6, backgroundColor: '#7C3AED', borderRadius: 6 },
  soundList: { marginTop: 12, borderRadius: 14, borderWidth: 1, borderColor: '#E5E7EB', overflow: 'hidden' },
  sep: { height: 1, backgroundColor: '#E5E7EB' },
  row: { flexDirection: 'row', alignItems: 'center', padding: 12 },
  rowThumb: { width: 40, height: 40, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginRight: 10 },
  rowName: { fontWeight: '600', color: '#0F172A' },
  rowDuration: { color: '#6B7280', fontSize: 12 },
});