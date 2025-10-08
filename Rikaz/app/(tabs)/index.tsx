import React, { useState } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, Image, TouchableOpacity, Modal, FlatList, ActivityIndicator, Platform } from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';

const HomeScreen = () => {
  const router = useRouter();
  const [isPresetsVisible, setIsPresetsVisible] = useState(false);
  const [selectedPreset, setSelectedPreset] = useState('Choose Preset');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedMode, setSelectedMode] = useState('Pomodoro Mode'); 
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
    if (selectedMode === 'Pomodoro Mode') {
      router.push('/pomodoro');
    } else {
      router.push('/custom'); 
    }
  };

  const handleEditPress = (sessionType: string) => {
    console.log(`Edit pressed for ${sessionType} session.`);
  };

  const handlePresetSelect = (preset: string) => {
    setSelectedPreset(preset);
    setIsPresetsVisible(false);
    console.log(`Selected preset: ${preset}`);
  };

  const handleAddSessionPress = () => {
    console.log('Add a new session pressed!');
  };

  const handleAddPreset = () => {
    console.log('Navigating to Add New Preset screen');
    setIsPresetsVisible(false);
  };
  
  const getDaysInMonth = (year: number, month: number) => {
    return new Date(year, month, 0).getDate();
  };
  
  const today = new Date();
  const currentMonth = today.getMonth();
  const currentYear = today.getFullYear();
  const currentDay = today.getDate();
  const daysInMonth = getDaysInMonth(currentYear, currentMonth + 1);
  const calendarDates = Array.from({ length: daysInMonth }, (_, i) => i + 1);

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.mainContainer}>
        <ScrollView contentContainerStyle={styles.scrollViewContent}>
          
          {/* Header Section */}
          <View style={styles.header}>
            <Image
              source={{ uri: 'https://via.placeholder.com/50' }}
              style={styles.logo}
            />
            <View style={styles.headerTextContainer}>
              <Text style={styles.greetingText}>Good morning, User!</Text>
              <Text style={styles.statusText}>Ready for a productive day?</Text>
            </View>
            <View style={styles.profileImageContainer}>
              <Image
                source={{ uri: 'https://via.placeholder.com/50' }}
                style={styles.profileImage}
              />
            </View>
          </View>

          {/* Rikaz Tools Card */}
          <View style={[styles.card, styles.shadowStyle]}>
            <Text style={styles.cardTitle}>Rikaz Tools</Text>
            <View style={styles.cardContent}>
              <Text style={styles.cardDescription}>
                Connect to unlock custom presets and advanced features
              </Text>
              <TouchableOpacity 
                style={styles.connectButton} 
                onPress={handleConnectPress}
                disabled={isLoading}
              >
                {isLoading ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={styles.connectButtonText}>Connect</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>

          {/* Start Focus Session Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Start Focus Session</Text>
            <TouchableOpacity 
              style={styles.dropdown}
              onPress={() => setIsPresetsVisible(true)}
            >
              <Text style={styles.dropdownText}>{selectedPreset}</Text>
              <Text style={{fontSize: 18, color: '#9A9A9A'}}>▼</Text>
            </TouchableOpacity>
            
            {/* Mode Cards */}
            <View style={styles.modeContainer}>
              <TouchableOpacity 
                style={[styles.modeCard, styles.shadowStyle, selectedMode === 'Pomodoro Mode' && styles.modeCardSelected]}
                onPress={() => setSelectedMode('Pomodoro Mode')}
              >
                <Text style={styles.modeTitle}>Pomodoro Mode</Text>
                <Text style={styles.modeDescription}>Structured focus and break sessions</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.modeCard, styles.shadowStyle, {marginLeft: 10}, selectedMode === 'Custom Mode' && styles.modeCardSelected]}
                onPress={() => setSelectedMode('Custom Mode')}
              >
                <Text style={styles.modeTitle}>Custom Mode</Text>
                <Text style={styles.modeDescription}>Set your own duration</Text>
              </TouchableOpacity>
            </View>
            
            <TouchableOpacity 
              style={styles.setSessionButton} 
              onPress={handleSetSessionPress}
              disabled={isLoading}
            >
              <Text style={styles.setSessionButtonText}>Set Session</Text>
            </TouchableOpacity>
          </View>
          
          {/* Schedule Sessions Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Schedule Sessions</Text>
            <View style={styles.calendarHeader}>
              <Text style={styles.calendarMonth}>January 2025</Text>
              <View style={styles.calendarNav}>
                <MaterialIcons name="chevron-left" size={24} color="#9A9A9A" />
                <MaterialIcons name="chevron-right" size={24} color="#9A9A9A" />
              </View>
            </View>
            <View style={styles.daysContainer}>
              {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day, index) => (
                <Text key={index} style={styles.dayText}>{day}</Text>
              ))}
            </View>
            <View style={styles.datesContainer}>
              {calendarDates.map((date, index) => (
                <View 
                  key={index} 
                  style={[styles.dateCircle, date === currentDay && styles.selectedDate]}
                >
                  <Text style={[styles.dateText, date === currentDay && styles.selectedDateText]}>{date}</Text>
                </View>
              ))}
            </View>
          </View>

          {/* Upcoming Sessions Section */}
          <View style={styles.section}>
            <View style={styles.sectionTitleContainer}>
              <Text style={styles.sectionTitle}>Upcoming Sessions</Text>
              <TouchableOpacity onPress={handleAddSessionPress}>
                <MaterialIcons name="add" size={24} color="#1E1E1E" />
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
      </View>

      {/* Modal for Presets Dropdown */}
      <Modal
        animationType="slide"
        transparent={true}
        visible={isPresetsVisible}
        onRequestClose={() => {
          setIsPresetsVisible(!isPresetsVisible);
        }}
      >
        <TouchableOpacity 
          style={styles.modalOverlay} 
          activeOpacity={1} 
          onPress={() => setIsPresetsVisible(false)}
        >
          <View style={styles.modalView}>
            <FlatList
              data={presets}
              keyExtractor={(item) => item}
              renderItem={({ item }) => (
                <TouchableOpacity 
                  style={styles.presetItem}
                  onPress={() => handlePresetSelect(item)}
                >
                  <Text style={styles.presetText}>{item}</Text>
                </TouchableOpacity>
              )}
            />
            {/* The new "Add New Preset" button */}
            <TouchableOpacity onPress={handleAddPreset}>
              <Text style={styles.addPresetLink}>+ Add New Preset</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F6F4F1',
  },
  mainContainer: {
    flex: 1,
  },
  scrollViewContent: {
    paddingBottom: 70, 
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    marginTop: Platform.OS === 'ios' ? 0 : 20,
  },
  logo: {
    width: 30,
    height: 30,
    resizeMode: 'contain',
    marginRight: 10,
  },
  headerTextContainer: {
    flex: 1,
  },
  greetingText: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  statusText: {
    fontSize: 14,
    color: '#9A9A9A',
  },
  profileImageContainer: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#D7D2CA',
    justifyContent: 'center',
    alignItems: 'center',
  },
  profileImage: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    marginHorizontal: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E6E2DC',
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  cardContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardDescription: {
    flex: 1,
    fontSize: 14,
    color: '#7A7A7A',
  },
  connectButton: {
    backgroundColor: '#000000',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 10,
  },
  connectButtonText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  section: {
    marginHorizontal: 16,
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  dropdown: {
    backgroundColor: '#FFFFFF',
    borderRadius: 10,
    padding: 15,
    marginBottom: 15,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderColor: '#E6E2DC',
    borderWidth: 1,
  },
  dropdownText: {
    color: '#1E1E1E',
  },
  modeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 15,
  },
  modeCard: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    padding: 14,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E6E2DC',
  },
  modeCardSelected: {
    borderColor: '#000000',
    borderWidth: 2,
  },
  modeTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 5,
    textAlign: 'center',
  },
  modeDescription: {
    fontSize: 11,
    textAlign: 'center',
    color: '#7A7A7A',
  },
  setSessionButton: {
    backgroundColor: '#000000',
    paddingVertical: 15,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  setSessionButtonText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 16,
  },
  calendarHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  calendarMonth: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  calendarNav: {
    flexDirection: 'row',
    width: 50,
    justifyContent: 'space-around',
  },
  daysContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  dayText: {
    flex: 1,
    textAlign: 'center',
    color: '#9A9A9A',
  },
  datesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-around',
  },
  dateCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    margin: 4,
  },
  dateText: {
    fontSize: 16,
  },
  selectedDate: {
    backgroundColor: '#000000',
  },
  selectedDateText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  sectionTitleContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  plusIcon: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1E1E1E',
  },
  upcomingSessionCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#E6E2DC',
  },
  upcomingSessionTitle: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  upcomingSessionDetails: {
    fontSize: 12,
    color: '#7A7A7A',
  },
  editButtonText: {
    color: '#1E1E1E',
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalView: {
    backgroundColor: '#F6F4F1',
    borderRadius: 14,
    width: '80%',
    maxHeight: '50%',
    padding: 20,
  },
  presetItem: {
    paddingVertical: 15,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#EEE9E2',
  },
  presetText: {
    fontSize: 16,
    color: '#1E1E1E',
  },
  shadowStyle: {
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 5,
      },
      android: {
        elevation: 3,
      },
    }),
  },
  addPresetLink: {
    color: '#007AFF', // Standard iOS blue
    fontSize: 16,
    textAlign: 'center',
    marginTop: 15,
    fontWeight: '600',
  },
});

export default HomeScreen;