import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import type { ColorValue } from 'react-native';
import {
  Alert,
  Animated,
  BackHandler,
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

type Stops2 = readonly [string, string];
type Stops3 = readonly [string, string, string];

const BREAK_GRADIENT: Stops3 = ['#FFF7ED', '#FFFBEB', '#FEF3C7'];
const FOCUS_GRADIENT: Stops3 = ['#F3F6FF', '#EEF2FF', '#EDE9FE'];

const MODE_COLORS = {
  focus: { ringStart: '#60a5fa', ringEnd: '#2563eb' },
  break: { ringStart: '#fbbf24', ringEnd: '#f59e0b' },
} as const;

/* ──────────────────────────────────────────────────────────
  Animation helpers
────────────────────────────────────────────────────────── */
const usePressScale = () => {
  const scale = useRef(new Animated.Value(1)).current;
  const onPressIn = () => Animated.spring(scale, { toValue: 0.96, useNativeDriver: true }).start();
  const onPressOut = () => Animated.spring(scale, { toValue: 1, useNativeDriver: true }).start();
  return { scale, onPressIn, onPressOut };
};

/* ──────────────────────────────────────────────────────────
  Components
────────────────────────────────────────────────────────── */
const HueAura: React.FC<{ mode: 'focus' | 'break' }> = ({ mode }) => {
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
  const rotate = v.interpolate({ inputRange: [0, 1], outputRange: ['-8deg', '8deg'] });
  const scale = v.interpolate({ inputRange: [0, 1], outputRange: [1, 1.035] });
  const opacity = v.interpolate({ inputRange: [0, 1], outputRange: [0.18, 0.28] });
  const colors: Stops2 = mode === 'break' ? ['#f59e0b', '#fbbf24'] : ['#3b82f6', '#7c3aed'];
  return (
    <Animated.View pointerEvents="none" style={[styles.hueBlob, { opacity, transform: [{ rotate }, { scale }] }]}>
      <LinearGradient colors={colors} start={{ x: 0.1, y: 0.1 }} end={{ x: 0.9, y: 0.9 }} style={styles.hueGradient} />
      <BlurView intensity={30} style={styles.hueBlurOverlay} />
    </Animated.View>
  );
};

const BlockCard = ({
  blockNumber,
  isActive,
  isCompleted,
  isRunning,
  mode,
  status,
}: {
  blockNumber: number;
  isActive: boolean;
  isCompleted: boolean;
  isRunning: boolean;
  mode: 'focus' | 'break';
  status: 'idle' | 'running' | 'paused';
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
    pulse.stopAnimation();
    pulse.setValue(0);
  }, [isActive, isRunning]);

  const scale = pulse.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] });
  const bg = status === 'paused'
    ? isActive
      ? '#CBD5E1'
      : isCompleted
      ? '#10B981'
      : '#FFFFFF'
    : isActive
    ? '#2563EB'
    : isCompleted
    ? '#10B981'
    : '#FFFFFF';

  const textColor = isActive ? '#fff' : '#64748B';
  const label =
    status === 'paused' && isActive ? 'Pending' : isActive ? 'Active' : isCompleted ? 'Done' : 'Pending';
  const halo = mode === 'break' ? 'rgba(245,158,11,1)' : 'rgba(37,99,235,1)';

  return (
    <View style={{ alignItems: 'center' }}>
      <Animated.View style={{ transform: [{ scale }] }}>
        <View
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            justifyContent: 'center',
            alignItems: 'center',
            backgroundColor: bg,
            shadowColor: '#000',
            shadowOpacity: 0.15,
            shadowRadius: 8,
            shadowOffset: { width: 0, height: 6 },
          }}
        >
          {isCompleted ? (
            <MaterialCommunityIcons name="check" size={22} color="#fff" />
          ) : (
            <Text style={{ color: textColor, fontWeight: '700' }}>{blockNumber}</Text>
          )}
          {isActive && isRunning && (
            <Animated.View
              pointerEvents="none"
              style={{
                position: 'absolute',
                width: 72,
                height: 72,
                borderRadius: 36,
                backgroundColor: halo,
                opacity: 0.28,
              }}
            />
          )}
        </View>
      </Animated.View>
      <Text style={{ marginTop: 6, fontSize: 12, color: '#64748B' }}>{label}</Text>
    </View>
  );
};

const CircularProgress = ({
  progress,
  size = 240,
  strokeWidth = 8,
  isBreakMode = false,
}: {
  progress: number;
  size?: number;
  strokeWidth?: number;
  isBreakMode?: boolean;
}) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const pct = Math.max(0, Math.min(100, progress)) / 100;
  const dashOffset = circumference - pct * circumference;
  const cx = size / 2,
    cy = size / 2;

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
        <Circle cx={cx} cy={cy} r={radius} fill="#FFFFFF" />
        <Circle cx={cx} cy={cy} r={radius} stroke="#E5EAF2" strokeWidth={strokeWidth} fill="transparent" />
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

// Sounds section (unchanged)
const soundOptions: {
  name: string;
  duration: string;
  colors: readonly [ColorValue, ColorValue];
  icon: string;
}[] = [
  { name: 'Nature Sounds', duration: '00:30:50', colors: ['#34d399', '#10b981'], icon: 'leaf' },
  { name: 'Rain Drops', duration: '00:45:20', colors: ['#60a5fa', '#06b6d4'], icon: 'weather-pouring' },
  { name: 'Ocean Waves', duration: '00:52:10', colors: ['#22d3ee', '#3b82f6'], icon: 'waves' },
  { name: 'Forest Birds', duration: '00:38:45', colors: ['#34d399', '#22c55e'], icon: 'bird' },
  { name: 'White Noise', duration: '01:00:00', colors: ['#9ca3af', '#475569'], icon: 'circle-outline' },
];

const SoundSection = () => {
  const [selected, setSelected] = useState(soundOptions[0]);
  const [expanded, setExpanded] = useState(false);
  const [playing, setPlaying] = useState(false);
  const playBtn = usePressScale();
  return (
    <BlurView intensity={30} tint="light" style={styles.glassBase}>
      <View style={styles.glassInner}>
        <Pressable style={styles.soundHeader} onPress={() => setExpanded((e) => !e)}>
          <LinearGradient colors={selected.colors as any} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.soundThumb}>
            <MaterialCommunityIcons name={selected.icon as any} size={26} color="#fff" />
          </LinearGradient>
          <View style={{ flex: 1 }}>
            <Text style={styles.soundTitle}>{selected.name}</Text>
            <Text style={styles.soundSub}>{selected.duration}</Text>
          </View>
          <TouchableWithoutFeedback
            onPressIn={playBtn.onPressIn}
            onPressOut={playBtn.onPressOut}
            onPress={() => setPlaying((p) => !p)}
          >
            <Animated.View style={[styles.playBtn, { transform: [{ scale: playBtn.scale }] }]}>
              <MaterialCommunityIcons name={playing ? 'pause' : 'play'} size={18} color="#fff" />
            </Animated.View>
          </TouchableWithoutFeedback>
          <MaterialCommunityIcons name={expanded ? 'chevron-up' : 'chevron-down'} size={22} color="#9CA3AF" />
        </Pressable>
        {expanded && (
          <FlatList
            data={soundOptions.filter((s) => s.name !== selected.name)}
            keyExtractor={(item) => item.name}
            ItemSeparatorComponent={() => <View style={styles.sep} />}
            renderItem={({ item }) => (
              <Pressable
                style={styles.row}
                onPress={() => {
                  setSelected(item);
                  setExpanded(false);
                  setPlaying(false);
                }}
              >
                <LinearGradient colors={item.colors as any} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowThumb}>
                  <MaterialCommunityIcons name={item.icon as any} size={20} color="#fff" />
                </LinearGradient>
                <View style={{ flex: 1 }}>
                  <Text style={styles.rowName}>{item.name}</Text>
                  <Text style={styles.rowDuration}>{item.duration}</Text>
                </View>
              </Pressable>
            )}
          />
        )}
      </View>
    </BlurView>
  );
};

type AnimatedButtonProps = {
  onPress: () => void;
  icon: string;
  label: string;
  bg?: string;
  variant?: 'solid' | 'outline';
  style?: any;
};

const AnimatedButton: React.FC<AnimatedButtonProps> = ({
  onPress,
  icon,
  label,
  bg = '#2563EB',
  variant = 'solid',
  style,
}) => {
  const { scale, onPressIn, onPressOut } = usePressScale();
  const solid = variant === 'solid';

  return (
    <TouchableWithoutFeedback onPressIn={onPressIn} onPressOut={onPressOut} onPress={onPress}>
      <Animated.View
        style={[
          {
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            paddingVertical: 14,
            borderRadius: 14,
            backgroundColor: solid ? bg : 'rgba(255,255,255,0.85)',
            borderWidth: solid ? 0 : 1,
            borderColor: solid ? 'transparent' : '#FCA5A5',
          },
          { transform: [{ scale }] },
          style,
        ]}
      >
        <MaterialCommunityIcons
          name={icon as any}
          color={solid ? '#fff' : '#DC2626'}
          size={18}
          style={{ marginRight: 8 }}
        />
        <Text style={{ color: solid ? '#fff' : '#DC2626', fontWeight: '700' }}>{label}</Text>
      </Animated.View>
    </TouchableWithoutFeedback>
  );
};

/* ──────────────────────────────────────────────────────────
  Screen
────────────────────────────────────────────────────────── */
export default function Session() {
  const router = useRouter();
  const { duration, numberOfBlocks, sessionType } = useLocalSearchParams();
  const isPomodoro = sessionType === 'pomodoro';

  // Custom naming to avoid conflict with your preset system
  const parsedDuration = Number(String(duration).replace(/\D/g, '')) || 50;
  const sessionTimes = isPomodoro
    ? (String(duration) === '25min'
        ? { focus: 25, break: 5 }
        : { focus: 50, break: 10 })
    : { focus: parsedDuration, break: 0 };

  const totalBlocks = isPomodoro ? Math.max(1, Math.min(8, Number(numberOfBlocks ?? 4))) : 1;

  const [mode, setMode] = useState<'focus' | 'break'>('focus');
  const [status, setStatus] = useState<'idle' | 'running' | 'paused'>('running');
  const [timeLeft, setTimeLeft] = useState(sessionTimes.focus * 60);
  const [currentBlock, setCurrentBlock] = useState(1);
  const [completedBlocks, setCompletedBlocks] = useState<number[]>([]);

  useFocusEffect(
    React.useCallback(() => {
      const onBackPress = () => true;
      const subscription = BackHandler.addEventListener('hardwareBackPress', onBackPress);
      return () => subscription.remove();
    }, [])
  );

  // Timer logic
  const statusRef = useRef(status);
  const modeRef = useRef(mode);
  const timeRef = useRef(timeLeft);
  const blockRef = useRef(currentBlock);
  useEffect(() => { statusRef.current = status; }, [status]);
  useEffect(() => { modeRef.current = mode; }, [mode]);
  useEffect(() => { timeRef.current = timeLeft; }, [timeLeft]);
  useEffect(() => { blockRef.current = currentBlock; }, [currentBlock]);

  useEffect(() => {
    const id = setInterval(() => {
      if (statusRef.current !== 'running') return;
      const t = timeRef.current;
      if (t <= 1) {
        if (!isPomodoro) {
          setStatus('idle');
          return;
        }
        if (modeRef.current === 'focus') {
          setCompletedBlocks((p) => (p.includes(blockRef.current) ? p : [...p, blockRef.current]));
          setMode('break');
          setTimeLeft(sessionTimes.break * 60);
        } else {
          const next = blockRef.current + 1;
          if (next > totalBlocks) {
            setStatus('idle');
            setMode('focus');
            setTimeLeft(sessionTimes.focus * 60);
            setCurrentBlock(1);
            setCompletedBlocks([]);
            return;
          }
          setCurrentBlock(next);
          setMode('focus');
          setTimeLeft(sessionTimes.focus * 60);
        }
      } else setTimeLeft(t - 1);
    }, 1000);
    return () => clearInterval(id);
  }, [sessionTimes.break, sessionTimes.focus, totalBlocks, isPomodoro]);

  const formatTime = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  const totalThisPhase = mode === 'focus' ? sessionTimes.focus * 60 : sessionTimes.break * 60;
  const progressPct = ((totalThisPhase - timeLeft) / totalThisPhase) * 100;

  const onPauseOrResume = () => {
    setStatus((prev) => (prev === 'running' ? 'paused' : 'running'));
  };

  const onQuit = () => {
    Alert.alert(
      'End Session?',
      'Are you sure you want to quit this session?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Quit',
          style: 'destructive',
          onPress: () => {
            setStatus('idle');
            setMode('focus');
            setTimeLeft(sessionTimes.focus * 60);
            setCurrentBlock(1);
            setCompletedBlocks([]);
            router.push('/');
          },
        },
      ],
      { cancelable: true },
    );
  };

  const bgColor = status === 'paused' ? '#E5E7EB' : mode === 'break' ? '#FEF3C7' : '#EEF2FF';

  return (
    <View style={{ flex: 1, backgroundColor: bgColor }}>
      <SafeAreaView style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 16, paddingBottom: 24 }}>
          <View style={{ alignItems: 'center', marginBottom: 16 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, backgroundColor: 'rgba(59,130,246,0.2)' }}>
              <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: '#3B82F6', marginRight: 8 }} />
              <Text style={{ color: '#1E40AF', fontWeight: '700' }}>
                {isPomodoro ? (mode === 'break' ? 'Break Time' : 'Focus Session') : 'Custom Session'}
              </Text>
            </View>
          </View>

          <View style={{ alignItems: 'center', marginBottom: 18 }}>
            <View style={styles.timerStack}>
              {status !== 'paused' && <HueAura mode={mode} />}
              <View style={styles.timerShell}>
                <CircularProgress progress={progressPct} size={240} strokeWidth={8} isBreakMode={mode === 'break'} />
                <View style={styles.timerCenter}>
                  <Text style={{ fontSize: 36, color: '#0F172A', fontWeight: '300', letterSpacing: 0.5 }}>{formatTime(timeLeft)}</Text>
                  <Text style={{ color: '#64748B', fontSize: 12, fontWeight: '600', marginTop: 6 }}>
                    {status === 'paused' ? 'Paused' : mode === 'focus' ? 'Stay focused' : 'Relax & recharge'}
                  </Text>
                </View>
              </View>
            </View>
          </View>

          <BlurView intensity={20} tint="light" style={[styles.glassBase, { marginBottom: 18 }]}>
            <View style={styles.glassInner}>
              <View style={{ alignItems: 'center', marginBottom: 14 }}>
                <Text style={{ color: '#0F172A', fontWeight: '700' }}>
                  {isPomodoro ? `Block ${currentBlock} of ${totalBlocks}` : 'Focus Duration'}
                </Text>
              </View>
              <View style={{ flexDirection: 'row' }}>
                <AnimatedButton
                  onPress={onPauseOrResume}
                  style={{ flex: 1, marginRight: 12 }}
                  bg={status === 'paused' ? '#10B981' : '#2563EB'}
                  icon={status === 'paused' ? 'play' : 'pause'}
                  label={status === 'paused' ? 'Resume' : 'Pause'}
                />
                <AnimatedButton onPress={onQuit} style={{ flex: 1 }} variant="outline" icon="stop" label="Quit" />
              </View>
            </View>
          </BlurView>

          {isPomodoro && (
            <View style={{ flexDirection: 'row', justifyContent: 'center', marginBottom: 18 }}>
              {Array.from({ length: totalBlocks }).map((_, i) => (
                <View key={i} style={{ marginHorizontal: 10 }}>
                  <BlockCard
                    blockNumber={i + 1}
                    isActive={mode === 'focus' && currentBlock === i + 1}
                    isCompleted={completedBlocks.includes(i + 1)}
                    isRunning={status === 'running'}
                    mode={mode}
                    status={status}
                  />
                </View>
              ))}
            </View>
          )}

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
  glassBase: { borderRadius: 18, overflow: 'hidden', borderWidth: 1, borderColor: 'rgba(255,255,255,0.35)' },
  glassInner: { padding: 16, backgroundColor: 'rgba(255,255,255,0.35)' },
  timerStack: { width: 288, height: 288, alignItems: 'center', justifyContent: 'center', position: 'relative' },
  hueBlob: { position: 'absolute', width: 260, height: 260, borderRadius: 130, overflow: 'hidden' },
  hueGradient: { ...StyleSheet.absoluteFillObject },
  hueBlurOverlay: { ...StyleSheet.absoluteFillObject },
  timerShell: { backgroundColor: '#FFFFFF', padding: 24, borderRadius: 9999, borderWidth: 1, borderColor: 'rgba(0,0,0,0.04)' },
  timerCenter: { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },
  soundHeader: { flexDirection: 'row', alignItems: 'center' },
  soundThumb: { width: 56, height: 56, borderRadius: 16, justifyContent: 'center', alignItems: 'center', marginRight: 12 },
  soundTitle: { fontWeight: '700', color: '#0F172A' },
  soundSub: { color: '#64748B', fontSize: 12, marginTop: 2 },
  playBtn: { width: 44, height: 44, borderRadius: 12, backgroundColor: '#7C3AED', alignItems: 'center', justifyContent: 'center', marginRight: 8 },
  sep: { height: 1, backgroundColor: '#E5E7EB' },
  row: { flexDirection: 'row', alignItems: 'center', padding: 12 },
  rowThumb: { width: 40, height: 40, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginRight: 10 },
  rowName: { fontWeight: '600', color: '#0F172A' },
  rowDuration: { color: '#6B7280', fontSize: 12 },
});
