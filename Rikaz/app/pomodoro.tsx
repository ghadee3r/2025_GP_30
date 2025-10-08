import { useRouter } from 'expo-router';
import React, { useState } from 'react';
import { ActivityIndicator, SafeAreaView, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
// ملاحظة: هذا السطر مهم لتشغيل Slider
import Slider from '@react-native-community/slider';

const PomodoroScreen = () => {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [duration, setDuration] = useState('25min');
  const [numberOfBlocks, setNumberOfBlocks] = useState(4);

  //updated
const handleStartSessionPress = async () => {
  setIsLoading(true);
  try {
    console.log(`Starting Pomodoro session with: ${duration} and ${numberOfBlocks} blocks.`);

    // Navigate to Session.tsx page and send parameters
    router.push({
      pathname: '/Session',
      params: { duration, numberOfBlocks }
    });

    console.log('Navigating to Session page...');
  } catch (error) {
    console.error('Failed to start session:', error);
  } finally {
    setIsLoading(false);
  }
};


  // تعديل هذه الدالة
  const handleBackPress = () => {
    router.back();
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.mainContainer}>
        <ScrollView contentContainerStyle={styles.scrollViewContent}>

          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity onPress={handleBackPress}>
              <Text style={styles.backButton}>{"< Back"}</Text>
            </TouchableOpacity>
            <Text style={styles.headerTitle}>Pomodoro Session</Text>
            <Text style={styles.headerSubtitle}>Configure your structured focus routine</Text>
          </View>

          {/* Duration Options */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Duration Options</Text>
            <TouchableOpacity 
              style={[styles.durationOption, duration === '25min' && styles.selectedOption]}
              onPress={() => setDuration('25min')}
            >
              <View style={[styles.radioButton, duration === '25min' && styles.radioButtonSelected]} />
              <Text style={styles.optionText}>25 min focus</Text>
              <Text style={styles.optionBreakText}>+ 5 min break</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.durationOption, duration === '50min' && styles.selectedOption]}
              onPress={() => setDuration('50min')}
            >
              <View style={[styles.radioButton, duration === '50min' && styles.radioButtonSelected]} />
              <Text style={styles.optionText}>50 min focus</Text>
              <Text style={styles.optionBreakText}>+ 10 min break</Text>
            </TouchableOpacity>
          </View>

          {/* Number of Blocks */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Number of Blocks</Text>
            <Text style={styles.blocksValue}>{numberOfBlocks}</Text>
            <Slider
              style={styles.slider}
              minimumValue={1}
              maximumValue={8}
              step={1}
              value={numberOfBlocks}
              onValueChange={value => setNumberOfBlocks(value)}
              minimumTrackTintColor="#000"
              maximumTrackTintColor="#ccc"
              thumbTintColor="#000"
            />
            <View style={styles.infoBox}>
              <Text style={styles.infoText}>
                Blocks represent how many Pomodoro cycles you want to repeat.{"\n"}
                One block = one focus session followed by its break.
              </Text>
            </View>
          </View>
          
          {/* Rikaz Tools Configuration */}
          <View style={styles.section}>
             <View style={styles.dropdown}>
               <Text style={styles.dropdownText}>Rikaz Tools Configuration</Text>
             </View>
          </View>

        </ScrollView>
        
        {/* Start Session Button */}
        <View style={styles.bottomButtonContainer}>
          <TouchableOpacity 
            style={styles.startSessionButton} 
            onPress={handleStartSessionPress}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.startSessionButtonText}>Start Session</Text>
            )}
          </TouchableOpacity>
        </View>

      </View>
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
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 100,
  },
  header: {
    marginBottom: 20,
  },
  backButton: {
    fontSize: 16,
    color: '#000',
    marginBottom: 20,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#888',
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  durationOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 15,
    padding: 20,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#eee',
  },
  selectedOption: {
    borderColor: '#000',
    borderWidth: 2,
  },
  radioButton: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#ccc',
    marginRight: 10,
  },
  radioButtonSelected: {
    borderColor: '#000',
    backgroundColor: '#000',
  },
  optionText: {
    flex: 1,
    fontSize: 16,
  },
  optionBreakText: {
    fontSize: 14,
    color: '#666',
  },
  blocksValue: {
    fontSize: 48,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  slider: {
    width: '100%',
    height: 40,
  },
  infoBox: {
    backgroundColor: '#f0f0f0',
    borderRadius: 10,
    padding: 15,
    marginTop: 10,
  },
  infoText: {
    fontSize: 14,
    color: '#444',
    textAlign: 'center',
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
  bottomButtonContainer: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    right: 20,
  },
  startSessionButton: {
    backgroundColor: '#000',
    paddingVertical: 15,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  startSessionButtonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
  },
});

export default PomodoroScreen;