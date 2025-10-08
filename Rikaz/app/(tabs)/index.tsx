import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Image,
  ImageBackground,
  Modal,
  Platform,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View
} from 'react-native';
import {
  Gesture,
  GestureDetector,
  GestureHandlerRootView,
} from 'react-native-gesture-handler';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

// height of the top illustration & how much the handle peeks
const BG_HEIGHT = 360;
const HANDLE_OVERLAP = 12;

const COLORS = {
  bgBeige: '#F7F2E9',
  card: '#FFFFFF',
  line: '#E6E2DC',
  text: '#1E1E1E',
  subText: '#9A9A9A',
  primaryLavender: '#8b5353ff',
  primaryLavenderDim: '#EEEAFD',
  peachLight: '#EED0C5',
  peachDeep: '#E7B7A6',
  oliveLight: '#C9D8A6',
  oliveDeep: '#B7C88A',
};

const HomeScreen = () => {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const [isPresetsVisible, setIsPresetsVisible] = useState(false);
  const [selectedPreset, setSelectedPreset] = useState('Choose Preset');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedMode, setSelectedMode] =
    useState<'Pomodoro Mode' | 'Custom Mode'>('Pomodoro Mode');

  const presets = ['Deep Work', 'Morning Focus', 'Study Session'];

  const handleConnectPress = async () => {
    setIsLoading(true);
    try {
      console.log('Connecting to Rikaz Tools...');
      console.log('Connection successful!');
    } catch (error) {
      console.error('Failed to connect:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSetSessionPress = () => {
    if (selectedMode === 'Pomodoro Mode') router.push('/pomodoro');
    else router.push('/custom');
  };

  const handleEditPress = (sessionType: string) => {
    console.log(`Edit pressed for ${sessionType} session.`);
  };

  const handlePresetSelect = (preset: string) => {
    setSelectedPreset(preset);
    setIsPresetsVisible(false);
    console.log(`Selected preset: ${preset}`);
  };

  const handleAddSessionPress = () => console.log('Add a new session pressed!');
  const handleAddPreset = () => {
    console.log('Navigating to Add New Preset screen');
    setIsPresetsVisible(false);
  };

  const getDaysInMonth = (year: number, month: number) =>
    new Date(year, month, 0).getDate();

  const today = new Date();
  const currentYear = today.getFullYear();
  const currentDay = today.getDate();
  const daysInMonth = getDaysInMonth(currentYear, today.getMonth() + 1);
  const calendarDates = Array.from({ length: daysInMonth }, (_, i) => i + 1);

  // ===== Draggable sheet (handle-only)

const BG_HEIGHT = 360;        // height of the top illustration
const HANDLE_OVERLAP = 12;    // how much of the handle peeks above the image

const MIN_TOP = 80;                           // expanded (fully up)
const MAX_TOP = BG_HEIGHT - HANDLE_OVERLAP;   // collapsed (just photo visible)
const MID_TOP = (MIN_TOP + MAX_TOP) / 2;

const top = useSharedValue(MID_TOP);
const dragCtx = useSharedValue({ startY: top.value });

const pan = Gesture.Pan()
  .onBegin(() => {
    dragCtx.value.startY = top.value;
  })
  .onUpdate((e) => {
    let next = dragCtx.value.startY + e.translationY;
    if (next < MIN_TOP) next = MIN_TOP;
    if (next > MAX_TOP) next = MAX_TOP;
    top.value = next;
  })
  .onEnd(() => {
    const snap = top.value > (MIN_TOP + MAX_TOP) / 2 ? MAX_TOP : MIN_TOP;
    top.value = withSpring(snap, { damping: 20, stiffness: 180 });
  });

const sheetStyle = useAnimatedStyle(() => ({ top: top.value }));


  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaView style={styles.safeArea}>
        {/* Fixed illustration */}
        <ImageBackground
          source={require('../../assets/images/illus.jpg')}
          style={styles.bg}
          resizeMode="cover"
        />

        {/* Rounded sheet pinned to bottom */}
        <Animated.View style={[styles.sheet, sheetStyle]}>
          {/* Handle owns the pan */}
          <GestureDetector gesture={pan}>
            <View style={styles.dragHandleArea}>
              <View style={styles.dragPill} />
            </View>
          </GestureDetector>

          {/* Content scrolls freely */}
          <ScrollView
            contentContainerStyle={[
              styles.scrollContent,
              { paddingBottom: insets.bottom + 180 }, // always enough room
            ]}
            showsVerticalScrollIndicator={false}
            nestedScrollEnabled
            // bounces={false} // uncomment if you dislike rubber-band
          >
            {/* Logo above header */}
            <View style={styles.logoWrapper}>
              <View style={styles.logoCircle}>
                <Image
                  source={require('../../assets/images/RikazLogo.png')}
                  style={{ width: 100, height: 100, resizeMode: 'contain' }}
                />
              </View>
            </View>

            {/* Header */}
            <View style={styles.header}>
              <Image
                source={{ uri: 'https://via.placeholder.com/50' }}
                style={styles.logoSmall}
              />
              <View style={styles.headerTextContainer}>
                <Text style={styles.greetingText}>Welcome back, User!</Text>
                <Text style={styles.statusText}>Ready for a productive day?</Text>
              </View>
              <View style={styles.profileImageContainer}>
                <Image
                  source={{ uri: 'https://via.placeholder.com/50' }}
                  style={styles.profileImage}
                />
              </View>
            </View>

            {/* Rikaz Tools */}
            <View style={[styles.card, styles.shadowStyle]}>
              <Text style={styles.cardTitle}>Connect Rikaz Tools</Text>
              <View style={styles.cardContentRow}>
                <Text style={styles.cardDescription}>
                  Connect to unlock custom presets and advanced features
                </Text>
              </View>
              <TouchableOpacity
                style={styles.primaryButton}
                onPress={handleConnectPress}
                disabled={isLoading}
              >
                {isLoading ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={styles.primaryButtonText}>Connect</Text>
                )}
              </TouchableOpacity>
            </View>

            {/* Start Focus Session */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Start Focus Session</Text>
              <TouchableOpacity
                style={styles.dropdown}
                onPress={() => setIsPresetsVisible(true)}
              >
                <Text style={styles.dropdownText}>{selectedPreset}</Text>
                <MaterialIcons
                  name="keyboard-arrow-down"
                  size={22}
                  color={COLORS.subText}
                />
              </TouchableOpacity>

              {/* Modes — deepen selected color */}
              <View style={styles.modeContainer}>
                <TouchableOpacity
                  style={[
                    styles.modeCard,
                    {
                      backgroundColor:
                        selectedMode === 'Pomodoro Mode'
                          ? COLORS.peachDeep
                          : COLORS.peachLight,
                      borderColor:
                        selectedMode === 'Pomodoro Mode'
                          ? '#D8A594'
                          : COLORS.line,
                      borderWidth: selectedMode === 'Pomodoro Mode' ? 2 : 1,
                    },
                  ]}
                  onPress={() => setSelectedMode('Pomodoro Mode')}
                >
                  <Text style={styles.modeTitle}>Pomodoro Mode</Text>
                  <Text style={styles.modeDescription}>
                    Structured focus and break sessions
                  </Text>
                </TouchableOpacity>

                <TouchableOpacity
                  style={[
                    styles.modeCard,
                    {
                      backgroundColor:
                        selectedMode === 'Custom Mode'
                          ? COLORS.oliveDeep
                          : COLORS.oliveLight,
                      borderColor:
                        selectedMode === 'Custom Mode' ? '#A7B97A' : COLORS.line,
                      borderWidth: selectedMode === 'Custom Mode' ? 2 : 1,
                    },
                  ]}
                  onPress={() => setSelectedMode('Custom Mode')}
                >
                  <Text style={styles.modeTitle}>Custom Mode</Text>
                  <Text style={styles.modeDescription}>Set your own duration</Text>
                </TouchableOpacity>
              </View>

              <TouchableOpacity
                style={styles.primaryButton}
                onPress={handleSetSessionPress}
                disabled={isLoading}
              >
                <Text style={styles.primaryButtonText}>Set Session</Text>
              </TouchableOpacity>
            </View>

            {/* Schedule Sessions */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Schedule Sessions</Text>
              <View style={styles.calendarHeader}>
                <Text style={styles.calendarMonth}>January {currentYear}</Text>
                <View style={styles.calendarNav}>
                  <MaterialIcons name="chevron-left" size={24} color={COLORS.subText} />
                  <MaterialIcons name="chevron-right" size={24} color={COLORS.subText} />
                </View>
              </View>
              <View style={styles.daysContainer}>
                {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
                  <Text key={`${d}-${i}`} style={styles.dayText}>
                    {d}
                  </Text>
                ))}
              </View>
              <View style={styles.datesContainer}>
                {calendarDates.map((date) => (
                  <View
                    key={date}
                    style={[styles.dateCircle, date === currentDay && styles.selectedDate]}
                  >
                    <Text style={[styles.dateText, date === currentDay && styles.selectedDateText]}>
                      {date}
                    </Text>
                  </View>
                ))}
              </View>
            </View>

            {/* Upcoming Sessions */}
            <View style={styles.section}>
              <View style={styles.sectionTitleContainer}>
                <Text style={styles.sectionTitle}>Upcoming Sessions</Text>
                <TouchableOpacity onPress={handleAddSessionPress}>
                  <MaterialIcons name="add" size={24} color={COLORS.text} />
                </TouchableOpacity>
              </View>

              <View style={[styles.upcomingSessionCard, styles.shadowStyle]}>
                <View>
                  <Text style={styles.upcomingSessionTitle}>Focus Session</Text>
                  <Text style={styles.upcomingSessionDetails}>Today, 2:00 PM - Pomodoro</Text>
                </View>
                <TouchableOpacity onPress={() => handleEditPress('Focus Session')}>
                  <Text style={styles.editButtonText}>Edit</Text>
                </TouchableOpacity>
              </View>

              <View style={[styles.upcomingSessionCard, styles.shadowStyle]}>
                <View>
                  <Text style={styles.upcomingSessionTitle}>Deep Work</Text>
                  <Text style={styles.upcomingSessionDetails}>Tomorrow, 9:00 AM - Custom</Text>
                </View>
                <TouchableOpacity onPress={() => handleEditPress('Deep Work')}>
                  <Text style={styles.editButtonText}>Edit</Text>
                </TouchableOpacity>
              </View>
            </View>
          </ScrollView>
        </Animated.View>

        {/* Presets Modal */}
        <Modal
          animationType="slide"
          transparent
          visible={isPresetsVisible}
          onRequestClose={() => setIsPresetsVisible(false)}
        >
          <TouchableOpacity
            style={styles.modalOverlay}
            activeOpacity={1}
            onPress={() => setIsPresetsVisible(false)}
          >
            <View style={styles.modalView}>
              <FlatList
                data={presets}
                keyExtractor={(item, index) => `${item}-${index}`}
                renderItem={({ item }) => (
                  <TouchableOpacity
                    style={styles.presetItem}
                    onPress={() => handlePresetSelect(item)}
                  >
                    <Text style={styles.presetText}>{item}</Text>
                  </TouchableOpacity>
                )}
              />
              <TouchableOpacity onPress={handleAddPreset}>
                <Text style={styles.addPresetLink}>+ Add New Preset</Text>
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        </Modal>
      </SafeAreaView>
    </GestureHandlerRootView>
  );
};

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: COLORS.bgBeige },

  // top illustration
bg: { position: 'absolute', top: 0, left: 0, right: 0, height: BG_HEIGHT },


  // sheet pinned to bottom
  sheet: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0, // <-- THIS is the key so height = screenHeight - top
    backgroundColor: COLORS.bgBeige,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOpacity: 0.12,
        shadowRadius: 8,
        shadowOffset: { width: 0, height: -4 },
      },
      android: { elevation: 8 },
    }),
  },

  // drag handle
  dragHandleArea: { alignItems: 'center', paddingTop: 8, paddingBottom: 6 },
  dragPill: { width: 54, height: 6, borderRadius: 3, backgroundColor: '#D9D7D2' },

  scrollContent: { paddingHorizontal: 18, paddingTop: 12 },

  // header
  logoWrapper: { alignItems: 'center', marginBottom: 6 },
  logoCircle: {
    width: 64, height: 64, borderRadius: 32,
   
    justifyContent: 'center', alignItems: 'center',
  },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  logoSmall: { width: 5, height: 30, resizeMode: 'contain', marginRight: 10 },
  headerTextContainer: { flex: 1 },
  greetingText: { fontSize: 22, fontWeight: '700', color: COLORS.text },
  statusText: { fontSize: 14, color: COLORS.subText },
  profileImageContainer: {
    width: 50, height: 50, borderRadius: 25, backgroundColor: '#D7D2CA',
    justifyContent: 'center', alignItems: 'center',
  },
  profileImage: { width: 48, height: 48, borderRadius: 24 },

  // card
  card: {
    backgroundColor: COLORS.card,
    borderRadius: 16,
    padding: 16,
    marginBottom: 18,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  cardTitle: { fontSize: 18, fontWeight: '700', marginBottom: 6, color: COLORS.text },
  cardContentRow: { flexDirection: 'row', alignItems: 'center' },
  cardDescription: { flex: 1, fontSize: 14, color: '#7A7A7A', marginBottom: 12 },

  primaryButton: {
    backgroundColor: COLORS.primaryLavender,
    paddingVertical: 14,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryButtonText: { color: '#FFF', fontWeight: '700' },

  // sections
  section: { marginBottom: 18 },
  sectionTitle: { fontSize: 18, fontWeight: '700', marginBottom: 10, color: COLORS.text },

  dropdown: {
    backgroundColor: COLORS.card,
    borderRadius: 12,
    padding: 14,
    marginBottom: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderColor: COLORS.line,
    borderWidth: 1,
  },
  dropdownText: { color: COLORS.text },

  modeContainer: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 12 },
  modeCard: {
    flex: 1,
    borderRadius: 14,
    padding: 14,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  modeTitle: { fontSize: 14, fontWeight: '700', marginBottom: 4, color: COLORS.text },
  modeDescription: { fontSize: 11, textAlign: 'center', color: '#6F6F6F' },

  calendarHeader: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10,
  },
  calendarMonth: { fontSize: 16, fontWeight: '700', color: COLORS.text },
  calendarNav: { flexDirection: 'row', width: 50, justifyContent: 'space-around' },
  daysContainer: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 10 },
  dayText: { flex: 1, textAlign: 'center', color: COLORS.subText },
  datesContainer: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-around' },
  dateCircle: { width: 40, height: 40, borderRadius: 20, justifyContent: 'center', alignItems: 'center', margin: 4 },
  dateText: { fontSize: 16, color: COLORS.text },
  selectedDate: { backgroundColor: COLORS.primaryLavender },
  selectedDateText: { color: '#FFFFFF', fontWeight: 'bold' },

  sectionTitleContainer: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  upcomingSessionCard: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    backgroundColor: COLORS.card, borderRadius: 14, padding: 16, marginBottom: 12,
    borderWidth: 1, borderColor: COLORS.line,
  },
  upcomingSessionTitle: { fontSize: 14, fontWeight: '700', color: COLORS.text },
  upcomingSessionDetails: { fontSize: 12, color: '#7A7A7A' },
  editButtonText: { color: COLORS.primaryLavender, fontWeight: '700' },

  modalOverlay: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: 'rgba(0,0,0,0.5)' },
  modalView: { backgroundColor: COLORS.bgBeige, borderRadius: 16, width: '80%', maxHeight: '50%', padding: 20 },
  presetItem: { paddingVertical: 15, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#EEE9E2' },
  presetText: { fontSize: 16, color: COLORS.text },
  addPresetLink: { color: COLORS.primaryLavender, fontSize: 16, textAlign: 'center', marginTop: 15, fontWeight: '700' },

  shadowStyle: {
    ...Platform.select({
      ios: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.08, shadowRadius: 6 },
      android: { elevation: 3 },
    }),
  },
});

export default HomeScreen;
