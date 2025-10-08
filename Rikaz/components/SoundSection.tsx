import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import React, { useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

// Sound data (static)
const soundOptions = [
  { name: 'Nature Sounds', duration: '00:30:50', colors: ['#34d399', '#10b981'] as const, icon: 'leaf' },
  { name: 'Rain Drops', duration: '00:45:20', colors: ['#60a5fa', '#06b6d4'] as const, icon: 'weather-pouring' },
  { name: 'Ocean Waves', duration: '00:52:10', colors: ['#22d3ee', '#3b82f6'] as const, icon: 'waves' },
  { name: 'Forest Birds', duration: '00:38:45', colors: ['#34d399', '#22c55e'] as const, icon: 'bird' },
  { name: 'White Noise', duration: '01:00:00', colors: ['#9ca3af', '#475569'] as const, icon: 'circle-outline' },
];

export const SoundSection: React.FC = () => {
  const [selected, setSelected] = useState(soundOptions[0]);
  const [expanded, setExpanded] = useState(false);
  const [playing, setPlaying] = useState(false);

  return (
    <View style={styles.card}>
      {/* Header row */}
      <Pressable style={styles.header} onPress={() => setExpanded(e => !e)}>
        <LinearGradient colors={selected.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.thumb}>
          <MaterialCommunityIcons name={selected.icon as any} size={26} color="#fff" />
        </LinearGradient>

        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{selected.name}</Text>
          <Text style={styles.sub}>{selected.duration}</Text>
        </View>

        <TouchableOpacity onPress={() => setPlaying(p => !p)} style={styles.playBtn}>
          <MaterialCommunityIcons name={playing ? 'pause' : 'play'} size={18} color="#fff" />
        </TouchableOpacity>

        <MaterialCommunityIcons
          name={expanded ? 'chevron-up' : 'chevron-down'}
          size={22}
          color="#9CA3AF"
        />
      </Pressable>

      {/* Progress bar */}
      <View style={styles.track}>
        <View style={styles.fill} />
      </View>

      {/* Expanded list */}
      {expanded && (
        <View style={styles.list}>
          <FlatList
            data={soundOptions.filter(s => s.name !== selected.name)}
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
                <LinearGradient
                  colors={item.colors}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.rowThumb}
                >
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

// Styles
const styles = StyleSheet.create({
  card: {
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 24,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.5)',
    shadowColor: 'rgba(0,0,0,0.15)',
    shadowOpacity: 0.15,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
  header: { flexDirection: 'row', alignItems: 'center' },
  thumb: {
    width: 56,
    height: 56,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  title: { fontWeight: '700', color: '#111827' },
  sub: { color: '#6B7280', fontSize: 12, marginTop: 2 },
  playBtn: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: '#7C3AED',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  track: {
    height: 6,
    backgroundColor: '#E5E7EB',
    borderRadius: 6,
    marginTop: 10,
    overflow: 'hidden',
  },
  fill: { width: '33%', height: 6, backgroundColor: '#7C3AED', borderRadius: 6 },
  list: {
    marginTop: 12,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    overflow: 'hidden',
  },
  sep: { height: 1, backgroundColor: '#E5E7EB' },
  row: { flexDirection: 'row', alignItems: 'center', padding: 12 },
  rowThumb: {
    width: 40,
    height: 40,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  rowName: { fontWeight: '600', color: '#111827' },
  rowDuration: { color: '#6B7280', fontSize: 12 },
});
