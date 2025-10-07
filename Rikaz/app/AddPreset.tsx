// app/AddPreset.tsx
import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

/**
 * AddPreset Screen
 * - UI only (no DB)
 * - Theme matches the "right" design (soft background, rounded cards)
 * - Structure matches the "left" design (form fields, checkboxes, etc.)
 * - Tabs are hidden since it’s outside (tabs)
 */

type DistractionKey = 'phone' | 'sleeping' | 'talking' | 'absent';
type SensitivityKey = 'low' | 'medium' | 'high';

export default function AddPreset(): React.JSX.Element {
  const [name, setName] = useState<string>('Study Session');
  const [distractions, setDistractions] = useState<Record<DistractionKey, boolean>>({
    phone: true,
    sleeping: true,
    talking: false,
    absent: true,
  });
  const [sensitivity, setSensitivity] = useState<SensitivityKey>('medium');
  const [lamp, setLamp] = useState<boolean>(true);
  const [sound, setSound] = useState<boolean>(false);

  const minutesLabel = useMemo(() => {
    switch (sensitivity) {
      case 'low': return '3 min';
      case 'medium': return '2 min';
      case 'high': return '1 min';
    }
  }, [sensitivity]);

  const toggleDistraction = (k: DistractionKey) =>
    setDistractions(prev => ({ ...prev, [k]: !prev[k] }));

  const handleSave = () => {
    // Later: replace this with DB integration
    router.replace('/(tabs)/profile');
  };

  const handleCancel = () => {
    router.replace('/(tabs)/profile');
  };

  return (
    <SafeAreaView style={styles.safe}>
      {/* Header */}
    {/* <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.headerBack}>
          <MaterialIcons name="arrow-back" size={22} color="#1E1E1E" />
        </Pressable>
        <Text style={styles.headerTitle}>Add Preset</Text>
        <View style={{ width: 22, marginLeft: 50}} />
      </View> */}

      {/* Breadcrumb */}
      <View style={styles.breadcrumb}>
        <Text style={styles.breadcrumbText}>Profile</Text>
        <MaterialIcons name="chevron-right" size={18} color="#9A9A9A" />
        <Text style={[styles.breadcrumbText, { color: '#1E1E1E' }]}>Add New Preset</Text>
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {/* Info banner */}
        <View style={styles.infoCard}>
          <MaterialIcons name="info" size={18} color="#5E6B73" style={{ marginRight: 8 }} />
          <Text style={styles.infoText}>
            This preset is only applicable when the camera is on
          </Text>
        </View>

        {/* Preset Name */}
        <View style={styles.card}>
          <Text style={styles.label}>Preset Name</Text>
          <TextInput
            style={styles.input}
            value={name}
            onChangeText={setName}
            placeholder="Study Session"
            returnKeyType="done"
          />
        </View>

        {/* Distraction Types */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Distraction Types to Detect</Text>

          <CheckRow
            label="Phone checking"
            checked={distractions.phone}
            onPress={() => toggleDistraction('phone')}
          />
          <CheckRow
            label="Sleeping"
            checked={distractions.sleeping}
            onPress={() => toggleDistraction('sleeping')}
          />
          <CheckRow
            label="Talking to someone else"
            checked={distractions.talking}
            onPress={() => toggleDistraction('talking')}
          />
          <CheckRow
            label="Not being present"
            checked={distractions.absent}
            onPress={() => toggleDistraction('absent')}
            last
          />
        </View>

        {/* Sensitivity */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Sensitivity</Text>
          <View style={styles.segment}>
            <SegmentButton
              label={`Low\n3 min`}
              active={sensitivity === 'low'}
              onPress={() => setSensitivity('low')}
            />
            <SegmentButton
              label={`Medium\n2 min`}
              active={sensitivity === 'medium'}
              onPress={() => setSensitivity('medium')}
            />
            <SegmentButton
              label={`High\n1 min`}
              active={sensitivity === 'high'}
              onPress={() => setSensitivity('high')}
            />
          </View>
          <Text style={styles.segmentNote}>Selected: {minutesLabel}</Text>
        </View>

        {/* Notification Method */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Notification Method</Text>

          <Row>
            <View style={styles.rowLeft}>
              <MaterialIcons name="emoji-objects" size={20} color="#1E1E1E" style={{ marginRight: 8 }} />
              <Text style={styles.rowLabel}>Lamp light</Text>
            </View>
            <Switch value={lamp} onValueChange={setLamp} />
          </Row>

          <Divider />

          <Row last>
            <View style={styles.rowLeft}>
              <MaterialIcons name="volume-up" size={20} color="#1E1E1E" style={{ marginRight: 8 }} />
              <Text style={styles.rowLabel}>Sound alerts</Text>
            </View>
            <Switch value={sound} onValueChange={setSound} />
          </Row>
        </View>

        {/* Bottom Buttons */}
        <View style={styles.actions}>
          <Pressable style={styles.primaryBtn} onPress={handleSave}>
            <Text style={styles.primaryText}>Save Preset</Text>
          </Pressable>
          <Pressable style={styles.secondaryBtn} onPress={handleCancel}>
            <Text style={styles.secondaryText}>Cancel</Text>
          </Pressable>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

/* ---------- Subcomponents ---------- */

function CheckRow({
  label,
  checked,
  onPress,
  last,
}: {
  label: string;
  checked: boolean;
  onPress: () => void;
  last?: boolean;
}) {
  return (
    <Pressable onPress={onPress} style={[styles.checkRow, last && { marginBottom: 0 }]}>
      <View style={[styles.checkbox, checked && styles.checkboxChecked]}>
        {checked && <MaterialIcons name="check" size={16} color="#FFFFFF" />}
      </View>
      <Text style={styles.checkLabel}>{label}</Text>
    </Pressable>
  );
}

function SegmentButton({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.segmentBtn, active && styles.segmentBtnActive]}
    >
      <Text style={[styles.segmentText, active && styles.segmentTextActive]}>{label}</Text>
    </Pressable>
  );
}

function Row({ children, last }: { children: React.ReactNode; last?: boolean }) {
  return <View style={[styles.row, !last && { marginBottom: 12 }]}>{children}</View>;
}

function Divider() {
  return <View style={styles.divider} />;
}

/* ---------- Styles ---------- */

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: '#F6F4F1',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  headerBack: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 18,
    fontWeight: '700',
    color: '#1E1E1E',
  },
  breadcrumb: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 18,
    marginBottom: 8,
  },
  breadcrumbText: {
    fontSize: 12,
    color: '#9A9A9A',
  },
  content: {
    paddingHorizontal: 16,
    paddingBottom: 32,
  },
  infoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EFF2F3',
    borderColor: '#E1E6E8',
    borderWidth: StyleSheet.hairlineWidth,
    padding: 12,
    borderRadius: 12,
    marginBottom: 16,
  },
  infoText: {
    flex: 1,
    color: '#5E6B73',
    fontSize: 13,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    padding: 14,
    marginBottom: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E6E2DC',
  },
  label: {
    fontSize: 12,
    color: '#7A7A7A',
    marginBottom: 8,
  },
  input: {
    fontSize: 16,
    paddingVertical: 10,
    color: '#1E1E1E',
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1E1E1E',
    marginBottom: 10,
  },
  checkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    borderWidth: 1.2,
    borderColor: '#D7D2CA',
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  checkboxChecked: {
    backgroundColor: '#1E1E1E',
    borderColor: '#1E1E1E',
  },
  checkLabel: {
    fontSize: 14,
    color: '#1E1E1E',
  },
  segment: {
    flexDirection: 'row',
    backgroundColor: '#F5F2EE',
    borderRadius: 12,
    padding: 4,
    gap: 6,
  },
  segmentBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  segmentBtnActive: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E6E2DC',
  },
  segmentText: {
    textAlign: 'center',
    fontSize: 12,
    color: '#7A7A7A',
  },
  segmentTextActive: {
    color: '#1E1E1E',
    fontWeight: '600',
  },
  segmentNote: {
    marginTop: 10,
    fontSize: 12,
    color: '#7A7A7A',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  rowLabel: {
    fontSize: 14,
    color: '#1E1E1E',
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: '#EEE9E2',
    marginVertical: 12,
  },
  actions: {
    marginTop: 8,
    gap: 10,
  },
  primaryBtn: {
    backgroundColor: '#000000',
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: 'center',
  },
  primaryText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
  secondaryBtn: {
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E6E2DC',
  },
  secondaryText: {
    color: '#1E1E1E',
    fontSize: 16,
    fontWeight: '600',
  },
});
