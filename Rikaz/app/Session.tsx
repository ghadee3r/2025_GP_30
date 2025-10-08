// app/Session.tsx
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import type { ColorValue } from 'react-native';
import {
  FlatList,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import Svg, { Circle, Defs, Stop, LinearGradient as SvgLinearGradient } from 'react-native-svg';

/* ──────────────────────────────────────────────────────────
   Fixed-length gradient tuples (TypeScript-safe)
   ────────────────────────────────────────────────────────── */
const BREAK_GRADIENT: readonly [ColorValue, ColorValue, ColorValue] =
  ['#FFF7ED', '#FFFBEB', '#FEF3C7'] as const;

const FOCUS_GRADIENT: readonly [ColorValue, ColorValue, ColorValue] =
  ['#F3F6FF', '#EEF2FF', '#EDE9FE'] as const;

/* ──────────────────────────────────────────────────────────
   Inline components (all in ONE file)
   ────────────────────────────────────────────────────────── */

// Block chip
const BlockCard = ({
  blockNumber,
  isActive,
  isCompleted,
}: {
  blockNumber: number;
  isActive: boolean;
  isCompleted: boolean;
}) => {
  const bg = isActive ? '#2563eb' : isCompleted ? '#10B981' : '#FFFFFF';
  const borderColor = isActive ? 'rgba(37,99,235,0.25)' : '#E5E7EB';
  const textColor = isActive ? '#fff' : '#64748B';
  const labelColor = isActive ? '#1e40af' : isCompleted ? '#065f46' : '#94A3B8';

  return (
    <View style={{ alignItems: 'center' }}>
      <View
        style={{
          width: 56,
          height: 56,
          borderRadius: 28,
          justifyContent: 'center',
          alignItems: 'center',
          backgroundColor: bg,
          borderWidth: isCompleted ? 0 : 1,
          borderColor,
          shadowColor: '#000',
          shadowOpacity: 0.15,
          shadowRadius: 8,
          shadowOffset: { width: 0, height: 6 },
          elevation: 4,
        }}
      >
        {isCompleted ? (
          <MaterialCommunityIcons name="check" size={22} color="#fff" />
        ) : (
          <Text style={{ color: textColor, fontWeight: '700' }}>{blockNumber}</Text>
        )}
      </View>
      <Text style={{ marginTop: 6, fontSize: 12, color: labelColor }}>
        {isActive ? 'Active' : isCompleted ? 'Done' : 'Pending'}
      </Text>
    </View>
  );
};

// Circular progress ring
const CircularProgress = ({
  progress,
  size = 240,
  strokeWidth = 8,
  isBreakMode = false,
}: {
  progress: number; // 0..100
  size?: number;
  strokeWidth?: number;
  isBreakMode?: boolean;
}) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const pct = Math.max(0, Math.min(100, progress)) / 100;
  const dashOffset = circumference - pct * circumference;
  const cx = size / 2;
  const cy = size / 2;

  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size} style={{ transform: [{ rotate: '-90deg' }] }}>
        <Defs>
          <SvgLinearGradient id="gradFocus" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor="#60a5fa" />
            <Stop offset="1" stopColor="#2563eb" />
          </SvgLinearGradient>
          <SvgLinearGradient id="gradBreak" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor="#fbbf24" />
            <Stop offset="1" stopColor="#f59e0b" />
          </SvgLinearGradient>
        </Defs>

        {/* background ring */}
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

// Sound selector card
const soundOptions = [
  { name: 'Nature Sounds', duration: '00:30:50', colors: ['#34d399', '#10b981'] as const, icon: 'leaf' },
  { name: 'Rain Drops', duration: '00:45:20', colors: ['#60a5fa', '#06b6d4'] as const, icon: 'weather-pouring' },
  { name: 'Ocean Waves', duration: '00:52:10', colors: ['#22d3ee', '#3b82f6'] as const, icon: 'waves' },
  { name: 'Forest Birds', duration: '00:38:45', colors: ['#34d399', '#22c55e'] as const, icon: 'bird' },
  { name: 'White Noise', duration: '01:00:00', colors: ['#9ca3af', '#475569'] as const, icon: 'circle-outline' },
];

const SoundSection = () => {
  const [selected, setSelected] = useState(soundOptions[0]);
  const [expanded, setExpanded] = useState(false);
  const [playing, setPlaying] = useState(false);

  return (
    <View style={styles.soundCard}>
      <Pressable style={styles.soundHeader} onPress={() => setExpanded((e) => !e)}>
        <LinearGradient colors={selected.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.soundThumb}>
          <MaterialCommunityIcons name={selected.icon as any} size={26} color="#fff" />
        </LinearGradient>

        <View style={{ flex: 1 }}>
          <Text style={styles.soundTitle}>{selected.name}</Text>
          <Text style={styles.soundSub}>{selected.duration}</Text>
        </View>

        <TouchableOpacity onPress={() => setPlaying((p) => !p)} style={styles.playBtn}>
          <MaterialCommunityIcons name={playing ? 'pause' : 'play'} size={18} color="#fff" />
        </TouchableOpacity>

        <MaterialCommunityIcons name={expanded ? 'chevron-up' : 'chevron-down'} size={22} color="#9CA3AF" />
      </Pressable>

      <View style={styles.track}>
        <View style={styles.fill} />
      </View>

      {expanded && (
        <View style={styles.soundList}>
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
    </View>
  );
};

/* ──────────────────────────────────────────────────────────
   Session Screen (default export)
   ────────────────────────────────────────────────────────── */

type TimerMode = 'focus' | 'break';
type TimerStatus = 'idle' | 'running' | 'paused';
type PomodoroSettings = { focusTime: number; breakTime: number };

export default function Session() {
  const router = useRouter();
  const { duration, numberOfBlocks } = useLocalSearchParams();

  // derive settings from params (fallbacks)
  const preset: PomodoroSettings =
    String(duration ?? '50min') === '25min' ? { focusTime: 25, breakTime: 5 } : { focusTime: 50, breakTime: 10 };

  const totalBlocks = Math.max(1, Math.min(8, Number(numberOfBlocks ?? 3)));

  const [settings] = useState<PomodoroSettings>(preset);
  const [mode, setMode] = useState<TimerMode>('focus');
  const [status, setStatus] = useState<TimerStatus>('running');
  const [timeLeft, setTimeLeft] = useState(settings.focusTime * 60); // seconds
  const [currentBlock, setCurrentBlock] = useState(1);
  const [completedBlocks, setCompletedBlocks] = useState<number[]>([]);

  // stable interval via refs
  const statusRef = useRef(status);
  const modeRef = useRef(mode);
  const timeRef = useRef(timeLeft);
  const blockRef = useRef(currentBlock);
  useEffect(() => {
    statusRef.current = status;
  }, [status]);
  useEffect(() => {
    modeRef.current = mode;
  }, [mode]);
  useEffect(() => {
    timeRef.current = timeLeft;
  }, [timeLeft]);
  useEffect(() => {
    blockRef.current = currentBlock;
  }, [currentBlock]);

  useEffect(() => {
    const id = setInterval(() => {
      if (statusRef.current !== 'running') return;
      const t = timeRef.current;

      if (t <= 1) {
        if (modeRef.current === 'focus') {
          setCompletedBlocks((prev) => (prev.includes(blockRef.current) ? prev : [...prev, blockRef.current]));
          setMode('break');
          setTimeLeft(settings.breakTime * 60);
        } else {
          const next = blockRef.current + 1;
          if (next > totalBlocks) {
            // session end → reset
            setStatus('idle');
            setMode('focus');
            setTimeLeft(settings.focusTime * 60);
            setCurrentBlock(1);
            setCompletedBlocks([]);
            return;
          }
          setCurrentBlock(next);
          setMode('focus');
          setTimeLeft(settings.focusTime * 60);
        }
      } else {
        setTimeLeft(t - 1);
      }
    }, 1000);

    return () => clearInterval(id);
  }, [settings.breakTime, settings.focusTime, totalBlocks]);

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  };

  const totalThisPhase = mode === 'focus' ? settings.focusTime * 60 : settings.breakTime * 60;
  const progressPct = ((totalThisPhase - timeLeft) / totalThisPhase) * 100;

  const onPauseOrGames = () => {
    if (mode === 'break') {
      router.push('/games'); // optional; ensure app/games.tsx exists if you use it
      return;
    }
    setStatus((prev) => (prev === 'running' ? 'paused' : 'running'));
  };

  const onQuit = () => {
    setStatus('idle');
    setMode('focus');
    setTimeLeft(settings.focusTime * 60);
    setCurrentBlock(1);
    setCompletedBlocks([]);
  };

  const gradient = mode === 'break' ? BREAK_GRADIENT : FOCUS_GRADIENT;

  return (
    <LinearGradient colors={gradient} start={{ x: 0.2, y: 0 }} end={{ x: 1, y: 1 }} style={{ flex: 1 }}>
      <SafeAreaView style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 16, paddingBottom: 24 }}>
          {/* Mode chip */}
          <View style={{ alignItems: 'center', marginBottom: 16 }}>
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                paddingHorizontal: 12,
                paddingVertical: 6,
                borderRadius: 999,
                backgroundColor: mode === 'break' ? 'rgba(251,191,36,0.25)' : 'rgba(59,130,246,0.2)',
              }}
            >
              <View
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: 4,
                  backgroundColor: mode === 'break' ? '#F59E0B' : '#3B82F6',
                  marginRight: 8,
                }}
              />
              <Text style={{ color: mode === 'break' ? '#92400E' : '#1E40AF', fontWeight: '700' }}>
                {mode === 'break' ? 'Break Time' : 'Focus Session'}
              </Text>
            </View>
          </View>

          {/* White circular timer card */}
          <View style={{ alignItems: 'center', marginBottom: 18 }}>
            <View
              style={{
                backgroundColor: '#fff',
                padding: 24,
                borderRadius: 9999,
                borderWidth: 1,
                borderColor: 'rgba(0,0,0,0.03)',
                shadowColor: '#000',
                shadowOpacity: 0.08,
                shadowRadius: 14,
                shadowOffset: { width: 0, height: 8 },
                elevation: 6,
              }}
            >
              <CircularProgress progress={progressPct} size={240} strokeWidth={8} isBreakMode={mode === 'break'} />
              <View
                style={{
                  position: 'absolute',
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Text style={{ fontSize: 36, color: '#0F172A', fontWeight: '300', letterSpacing: 0.5 }}>
                  {formatTime(timeLeft)}
                </Text>
                <Text style={{ color: '#64748B', fontSize: 12, fontWeight: '600', marginTop: 6 }}>
                  {mode === 'focus' ? 'Stay focused' : 'Relax & recharge'}
                </Text>
              </View>
            </View>
          </View>

          {/* Status card */}
          <View style={styles.statusCard}>
            <View style={{ alignItems: 'center', marginBottom: 14 }}>
              <Text style={{ color: '#0F172A', fontWeight: '700' }}>
                {mode === 'focus' ? `Block ${currentBlock} of ${totalBlocks}` : `Break • ${Math.ceil(timeLeft / 60)} min left`}
              </Text>
              <Text style={{ color: '#94A3B8', fontSize: 12, marginTop: 2 }}>
                {mode === 'focus' ? `Next break in ${Math.ceil(timeLeft / 60)} minutes` : 'Enjoy your well-deserved break'}
              </Text>
            </View>

            <View style={{ flexDirection: 'row' }}>
              <TouchableOpacity
                onPress={onPauseOrGames}
                style={{
                  flex: 1,
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                  paddingVertical: 14,
                  borderRadius: 14,
                  marginRight: 12,
                  backgroundColor: mode === 'break' ? '#7C3AED' : status === 'paused' ? '#10B981' : '#2563EB',
                  shadowColor: '#000',
                  shadowOpacity: 0.15,
                  shadowRadius: 8,
                  shadowOffset: { width: 0, height: 6 },
                  elevation: 4,
                }}
              >
                <MaterialCommunityIcons
                  name={mode === 'break' ? 'controller-classic' : status === 'paused' ? 'play' : 'pause'}
                  color="#fff"
                  size={18}
                  style={{ marginRight: 8 }}
                />
                <Text style={{ color: '#fff', fontWeight: '700' }}>
                  {mode === 'break' ? 'Games' : status === 'paused' ? 'Resume' : 'Pause'}
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                onPress={onQuit}
                style={{
                  flex: 1,
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                  paddingVertical: 14,
                  borderRadius: 14,
                  backgroundColor: '#fff',
                  borderWidth: 1,
                  borderColor: '#FCA5A5',
                  shadowColor: '#000',
                  shadowOpacity: 0.15,
                  shadowRadius: 8,
                  shadowOffset: { width: 0, height: 6 },
                  elevation: 4,
                }}
              >
                <MaterialCommunityIcons name="stop" color="#DC2626" size={18} style={{ marginRight: 8 }} />
                <Text style={{ color: '#DC2626', fontWeight: '700' }}>Quit</Text>
              </TouchableOpacity>
            </View>
          </View>

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
                  />
                </View>
              );
            })}
          </View>

          {/* Sounds section */}
          <SoundSection />
        </ScrollView>
      </SafeAreaView>
    </LinearGradient>
  );
}

/* ──────────────────────────────────────────────────────────
   Styles shared by SoundSection / status card
   ────────────────────────────────────────────────────────── */
const styles = StyleSheet.create({
  statusCard: {
    backgroundColor: '#fff',
    borderRadius: 18,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.04)',
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6,
    alignSelf: 'center',
    width: '92%',
    marginBottom: 18,
  },
  soundCard: {
    backgroundColor: '#fff',
    borderRadius: 18,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.04)',
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6,
  },
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
