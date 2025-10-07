import React, { useState } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, Image, TouchableOpacity, Modal, FlatList, ActivityIndicator, Platform } from 'react-native';
import { useRouter } from 'expo-router';

const FocusScreen = () => {
  const router = useRouter();
  const [isPresetsVisible, setIsPresetsVisible] = useState(false);
  const [selectedPreset, setSelectedPreset] = useState('Choose Preset');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedMode, setSelectedMode] = useState('Pomodoro Mode'); 
  const presets = ['Pomodoro', 'Deep Work', 'Light Focus', 'Break'];

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

  // دالة جديدة لإضافة إعداد مسبق
  const handleAddPreset = () => {
    console.log('Navigating to Add New Preset screen');
    // هنا يمكنك إضافة منطق التوجيه إلى صفحة إضافة إعداد مسبق جديد
    // router.push('/add-preset');
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
              <Text style={{fontSize: 18, color: '#888'}}>▼</Text>
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
                <Text>{"<"}</Text>
                <Text>{">"}</Text>
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
                  <Text style={styles.plusIcon}>+</Text>
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
            {/* الزر الجديد */}
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
    backgroundColor: '#f5f5f5',
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
    color: '#888',
  },
  profileImageContainer: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#e0e0e0',
    justifyContent: 'center',
    alignItems: 'center',
  },
  profileImage: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 15,
    marginHorizontal: 20,
    padding: 20,
    marginBottom: 20,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  cardContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardDescription: {
    flex: 1,
    fontSize: 14,
    color: '#666',
  },
  connectButton: {
    backgroundColor: '#000',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 10,
  },
  connectButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  section: {
    marginHorizontal: 20,
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  dropdown: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 15,
    marginBottom: 15,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderColor: '#ccc',
    borderWidth: 1,
  },
  dropdownText: {
    color: '#000',
  },
  modeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 15,
  },
  modeCard: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 15,
    padding: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modeCardSelected: {
    backgroundColor: '#e0e0e0', 
  },
  modeTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
    textAlign: 'center',
  },
  modeDescription: {
    fontSize: 12,
    textAlign: 'center',
    color: '#666',
  },
  setSessionButton: {
    backgroundColor: '#000',
    paddingVertical: 15,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  setSessionButtonText: {
    color: '#fff',
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
    color: '#888',
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
    backgroundColor: '#000',
  },
  selectedDateText: {
    color: '#fff',
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
    color: '#000',
  },
  upcomingSessionCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 15,
    padding: 15,
    marginBottom: 10,
  },
  upcomingSessionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  upcomingSessionDetails: {
    fontSize: 12,
    color: '#888',
  },
  editButtonText: {
    color: '#000',
    fontWeight: 'bold',
  },
  modalOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalView: {
    backgroundColor: 'white',
    borderRadius: 10,
    width: '80%',
    maxHeight: '50%',
    padding: 20,
  },
  presetItem: {
    paddingVertical: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  presetText: {
    fontSize: 16,
  },
  shadowStyle: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 5,
    elevation: 3,
  },
  addPresetLink: {
    color: 'blue',
    fontSize: 16,
    textAlign: 'center',
    marginTop: 15,
  },
});

export default FocusScreen;