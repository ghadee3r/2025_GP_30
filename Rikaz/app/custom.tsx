import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Switch,
  Platform,
} from 'react-native';
import { useRouter } from 'expo-router';
import type { Href } from 'expo-router';
import SliderComponent from '@react-native-community/slider';

const CustomScreen = () => {
  const router = useRouter();

  // state
  const [isLoading, setIsLoading] = useState(false);
  const [sessionDuration, setSessionDuration] = useState<number>(70);
  const [isConfigurationOpen, setIsConfigurationOpen] = useState(false);
  const [isCameraDetectionEnabled, setIsCameraDetectionEnabled] = useState(true);
  const [sensitivity, setSensitivity] = useState<0 | 0.5 | 1>(0.5);
  const [notificationStyle, setNotificationStyle] = useState<'Light' | 'Sound' | 'Both'>('Both');

  const resetForm = () => {
    setSessionDuration(70);
    setIsConfigurationOpen(false);
    setIsCameraDetectionEnabled(true);
    setSensitivity(0.5);
    setNotificationStyle('Both');
  };

  const handleStartSessionPress = () => {
    // ما نعرض أي معلومات، نعيد فتح صفحة الكست نفسها (ونصفّر الحقول)
    setIsLoading(true);
    resetForm();
    router.replace('/custom' as Href); // لو ملفك داخل تبويب غيّرها إلى '/(tabs)/custom'
    setIsLoading(false);
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.mainContainer}>
        <ScrollView contentContainerStyle={styles.scrollViewContent}>

          {/* Header */}
          <View style={styles.header}>
            <View style={styles.breadcrumb}>
              <Text style={styles.breadcrumbText}>Home &gt; Set Session</Text>
            </View>
            <Text style={styles.headerTitle}>Custom Session</Text>
            <Text style={styles.headerSubtitle}>Set your own timing</Text>
          </View>

          {/* Session Duration */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Session Duration</Text>
            <Text style={styles.durationValue}>{sessionDuration}:00</Text>
            <Text style={styles.noBreaksText}>No Breaks</Text>

            <SliderComponent
              style={styles.slider}
              minimumValue={25}
              maximumValue={120}
              step={1}
              value={sessionDuration}
              onValueChange={(value: number) => setSessionDuration(value)}
              minimumTrackTintColor="#000"
              maximumTrackTintColor="#ccc"
              thumbTintColor="#000"
            />

            <View style={styles.sliderLabels}>
              <Text style={styles.sliderLabel}>25 Minutes</Text>
              <Text style={styles.sliderLabel}>120 Minutes</Text>
            </View>
          </View>

          {/* Rikaz Tools Configuration */}
          <View style={styles.section}>
            <TouchableOpacity
              style={styles.dropdown}
              onPress={() => setIsConfigurationOpen(!isConfigurationOpen)}
            >
              <Text style={styles.dropdownText}>Rikaz Tools Configuration</Text>
              <Text style={styles.dropdownArrow}>{isConfigurationOpen ? '▲' : '▼'}</Text>
            </TouchableOpacity>

            {isConfigurationOpen && (
              <View style={[styles.configurationMenu, styles.shadowStyle]}>
                <View style={styles.configItem}>
                  <Text style={styles.configLabel}>Camera Detection</Text>
                  <Switch
                    trackColor={{ false: '#767577', true: '#81b0ff' }}
                    thumbColor={
                      Platform.OS === 'android'
                        ? (isCameraDetectionEnabled ? '#000' : '#f4f3f4')
                        : undefined
                    }
                    ios_backgroundColor="#3e3e3e"
                    onValueChange={setIsCameraDetectionEnabled}
                    value={isCameraDetectionEnabled}
                  />
                </View>

                <View style={styles.configItem}>
                  <Text style={styles.configLabel}>Triggers</Text>
                  <View style={styles.triggersContainer}>
                    <TouchableOpacity onPress={() => { /* toggle trigger */ }}>
                      <View style={[styles.checkbox, styles.triggerCheckbox]} />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => { /* toggle trigger */ }}>
                      <View style={[styles.checkbox, styles.triggerCheckbox]} />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => { /* toggle trigger */ }}>
                      <View style={[styles.checkbox, styles.triggerCheckbox]} />
                    </TouchableOpacity>
                  </View>
                </View>

                <View style={styles.configItem}>
                  <Text style={styles.configLabel}>Sensitivity</Text>
                  <View style={styles.sensitivityContainer}>
                    <Text style={styles.sensitivityText}>Low</Text>
                    <SliderComponent
                      style={styles.sensitivitySlider}
                      minimumValue={0}
                      maximumValue={1}
                      step={0.5}
                      value={sensitivity}
                      onValueChange={(v: number) => setSensitivity(v as 0 | 0.5 | 1)}
                      minimumTrackTintColor="#000"
                      maximumTrackTintColor="#ccc"
                      thumbTintColor="#000"
                    />
                    <Text style={styles.sensitivityText}>High</Text>
                  </View>
                </View>

                <View style={styles.configItem}>
                  <Text style={styles.configLabel}>Notification</Text>
                  <View style={styles.notificationContainer}>
                    <TouchableOpacity onPress={() => setNotificationStyle('Light')}>
                      <View style={[
                        styles.checkbox,
                        styles.radio,
                        notificationStyle === 'Light' && styles.checkboxSelected
                      ]} />
                      <Text style={styles.checkboxLabel}>Light</Text>
                    </TouchableOpacity>

                    <TouchableOpacity onPress={() => setNotificationStyle('Sound')}>
                      <View style={[
                        styles.checkbox,
                        styles.radio,
                        notificationStyle === 'Sound' && styles.checkboxSelected
                      ]} />
                      <Text style={styles.checkboxLabel}>Sound</Text>
                    </TouchableOpacity>

                    <TouchableOpacity onPress={() => setNotificationStyle('Both')}>
                      <View style={[
                        styles.checkbox,
                        styles.radio,
                        notificationStyle === 'Both' && styles.checkboxSelected
                      ]} />
                      <Text style={styles.checkboxLabel}>Both</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            )}
          </View>
        </ScrollView>

        {/* Start Session Button */}
        <View style={styles.bottomButtonContainer}>
          <TouchableOpacity
            style={styles.startSessionButton}
            onPress={handleStartSessionPress}
            disabled={isLoading}
          >
            {isLoading
              ? <ActivityIndicator color="#fff" />
              : <Text style={styles.startSessionButtonText}>Start Session</Text>}
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
};

/* ===================== Styles ===================== */
const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: '#f5f5f5' },
  mainContainer: { flex: 1 },
  scrollViewContent: { paddingHorizontal: 20, paddingTop: 20, paddingBottom: 100 },

  header: { marginBottom: 20 },
  breadcrumb: { marginBottom: 10 },
  breadcrumbText: { fontSize: 14, color: '#666' },
  headerTitle: { fontSize: 24, fontWeight: 'bold' },
  headerSubtitle: { fontSize: 16, color: '#888' },

  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 18, fontWeight: 'bold', marginBottom: 10 },

  durationValue: { fontSize: 48, fontWeight: 'bold', textAlign: 'center' },
  noBreaksText: { fontSize: 16, color: '#888', textAlign: 'center', marginBottom: 10 },
  slider: { width: '100%', height: 40 },
  sliderLabels: { flexDirection: 'row', justifyContent: 'space-between' },
  sliderLabel: { fontSize: 12, color: '#888' },

  dropdown: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 15,
    marginBottom: 15,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#ccc',
  },
  dropdownText: { color: '#000' },
  dropdownArrow: { fontSize: 18, color: '#000' },
  configurationMenu: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 15,
    marginBottom: 15,
    borderWidth: 1,
    borderColor: '#ccc',
  },
  configItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  configLabel: { fontSize: 16 },
  triggersContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    flex: 1,
  },
  triggerCheckbox: { width: 20, height: 20, borderWidth: 2, borderColor: '#000', borderRadius: 4 },
  sensitivityContainer: { flexDirection: 'row', alignItems: 'center', flex: 1, marginLeft: 10 },
  sensitivitySlider: { flex: 1, marginHorizontal: 10 },
  sensitivityText: { fontSize: 12 },

  notificationContainer: { flexDirection: 'row', justifyContent: 'space-around', flex: 1 },
  checkboxWrapper: { flexDirection: 'row', alignItems: 'center' },
  checkbox: { width: 20, height: 20, borderWidth: 2, borderColor: '#ccc', marginRight: 5 },
  radio: { borderRadius: 10 },
  checkboxSelected: { backgroundColor: '#000', borderColor: '#000' },
  checkboxLabel: { fontSize: 14 },

  bottomButtonContainer: { position: 'absolute', bottom: 20, left: 20, right: 20 },
  startSessionButton: {
    backgroundColor: '#000',
    paddingVertical: 15,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  startSessionButtonText: { color: '#fff', fontWeight: 'bold', fontSize: 16 },

  shadowStyle: {
    ...Platform.select({
      ios: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.1, shadowRadius: 5 },
      android: { elevation: 3 },
    }),
  },
});

export default CustomScreen;
