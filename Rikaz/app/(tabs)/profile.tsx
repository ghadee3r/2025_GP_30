import { useColorScheme } from '@/hooks/use-color-scheme';
import { MaterialIcons } from '@expo/vector-icons';
import { router, useRouter } from 'expo-router';
import React, { useState } from 'react';
import { Alert, Image, SafeAreaView, ScrollView, StyleSheet, Switch, Text, TouchableOpacity, View } from 'react-native';
const addPreset = () => {
  router.push('/AddPreset'); // navigates to app/AddPreset.tsx (outside tabs)
};

const ProfileScreen = () => {
  const router = useRouter();
  const colorScheme = useColorScheme();
  const [isDarkMode, setIsDarkMode] = useState(colorScheme === 'dark');

  const [presets, setPresets] = useState([
    { id: '1', name: 'Deep Work', sensitivity: 'High', triggers: 3 },
    { id: '2', name: 'Morning Focus', sensitivity: 'Low', triggers: 1 },
    { id: '3', name: 'Study Session', sensitivity: 'Mid', triggers: 4 },
  ]);

  const handleDeletePreset = (idToDelete: string) => {
    Alert.alert(
      "Delete Preset",
      "Are you sure you want to delete this preset?",
      [
        {
          text: "Cancel",
          style: "cancel"
        },
        { 
          text: "Delete", 
          onPress: () => {
            const newPresets = presets.filter(preset => preset.id !== idToDelete);
            setPresets(newPresets);
            console.log(`Preset with ID ${idToDelete} was deleted.`);
          },
          style: "destructive"
        }
      ]
    );
  };

  const handleSignOut = () => {
    console.log('User signed out.');
  };

  const themeContainerStyle = isDarkMode ? styles.darkContainer : styles.lightContainer;
  const themeTextStyle = isDarkMode ? styles.darkText : styles.lightText;
  const themeCardStyle = isDarkMode ? styles.darkCard : styles.lightCard;

  return (
    <SafeAreaView style={[styles.safeArea, themeContainerStyle]}>
      <ScrollView contentContainerStyle={styles.scrollViewContent}>
        {/* User Profile Header */}
        <View style={styles.profileHeader}>
          <View style={styles.avatarContainer}>
            <Image
              source={{ uri: 'https://via.placeholder.com/100' }}
              style={styles.avatar}
            />
            <TouchableOpacity style={styles.editIcon}>
              <MaterialIcons name="edit" size={16} color="#000" />
            </TouchableOpacity>
          </View>
          <Text style={[styles.userName, themeTextStyle]}>User Name</Text>
          <Text style={[styles.userEmail, themeTextStyle]}>user.name@email.com</Text>
          <TouchableOpacity style={styles.editProfileButton}>
            <Text style={styles.editProfileText}>Edit Profile</Text>
          </TouchableOpacity>
        </View>

        {/* Rikaz Tools Presets */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, themeTextStyle]}>Rikaz Tools Presets</Text>
            <Text style={[styles.presetCount, themeTextStyle]}>{presets.length}/5</Text>
          </View>
          <TouchableOpacity
            style={[styles.addPresetButton, themeCardStyle]}
            onPress={addPreset}
          >
            <Text style={[styles.addPresetText, themeTextStyle]}>+</Text>
            <Text style={[styles.addPresetText, themeTextStyle]}>Add New Preset</Text>
          </TouchableOpacity>

          {presets.map((preset) => (
            <View key={preset.id} style={[styles.presetCard, themeCardStyle]}>
              <View style={styles.presetDetails}>
                <Text style={[styles.presetName, themeTextStyle]}>{preset.name}</Text>
                <View style={styles.tagsContainer}>
                  <Text style={styles.tag}>{preset.sensitivity} Sensitivity</Text>
                  <Text style={styles.tag}>{preset.triggers} Triggers</Text>
                </View>
              </View>
              <View style={styles.presetActions}>
                <TouchableOpacity style={styles.actionIcon}>
                  <MaterialIcons name="edit" size={20} color={isDarkMode ? '#fff' : '#000'} />
                </TouchableOpacity>
                <TouchableOpacity style={styles.actionIcon} onPress={() => handleDeletePreset(preset.id)}>
                  <MaterialIcons name="delete" size={20} color={isDarkMode ? '#fff' : '#000'} />
                </TouchableOpacity>
              </View>
            </View>
          ))}
        </View>

        {/* Settings Section */}
        <View style={styles.section}>
          <Text style={[styles.sectionTitle, themeTextStyle]}>Settings</Text>
          <TouchableOpacity style={[styles.settingsItem, themeCardStyle]}>
            <View style={styles.settingsItemLeft}>
              <MaterialIcons name="security" size={20} color={isDarkMode ? '#fff' : '#000'} />
              <Text style={[styles.settingsText, themeTextStyle]}>Privacy</Text>
            </View>
            <MaterialIcons name="chevron-right" size={20} color={isDarkMode ? '#fff' : '#000'} />
          </TouchableOpacity>

          <TouchableOpacity style={[styles.settingsItem, themeCardStyle]}>
            <View style={styles.settingsItemLeft}>
              <MaterialIcons name="help-outline" size={20} color={isDarkMode ? '#fff' : '#000'} />
              <Text style={[styles.settingsText, themeTextStyle]}>Help & Support</Text>
            </View>
            <MaterialIcons name="chevron-right" size={20} color={isDarkMode ? '#fff' : '#000'} />
          </TouchableOpacity>
          
          {/* Dark Mode Switch */}
          <View style={[styles.settingsItem, themeCardStyle]}>
            <View style={styles.settingsItemLeft}>
              <MaterialIcons name="dark-mode" size={20} color={isDarkMode ? '#fff' : '#000'} />
              <Text style={[styles.settingsText, themeTextStyle]}>Dark Mode</Text>
            </View>
            <Switch
              value={isDarkMode}
              onValueChange={() => setIsDarkMode(!isDarkMode)}
              trackColor={{ false: "#ccc", true: "#81b0ff" }}
              thumbColor={isDarkMode ? "#f4f3f4" : "#f4f3f4"}
            />
          </View>
        </View>

        {/* Sign Out Button */}
        <View style={styles.section}>
          <TouchableOpacity style={[styles.signOutButton, themeCardStyle]} onPress={handleSignOut}>
            <View style={styles.settingsItemLeft}>
              <MaterialIcons name="logout" size={20} color={isDarkMode ? '#fff' : '#000'} />
              <Text style={[styles.settingsText, themeTextStyle]}>Sign Out</Text>
            </View>
            <MaterialIcons name="chevron-right" size={20} color={isDarkMode ? '#fff' : '#000'} />
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
  scrollViewContent: {
    paddingBottom: 20,
  },
  lightContainer: {
    backgroundColor: '#f5f5f5',
  },
  darkContainer: {
    backgroundColor: '#121212',
  },
  lightText: {
    color: '#000',
  },
  darkText: {
    color: '#fff',
  },
  lightCard: {
    backgroundColor: '#fff',
  },
  darkCard: {
    backgroundColor: '#1f1f1f',
  },
  profileHeader: {
    alignItems: 'center',
    paddingVertical: 30,
    borderBottomWidth: 1,
    borderBottomColor: '#ccc',
  },
  avatarContainer: {
    position: 'relative',
  },
  avatar: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  editIcon: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    backgroundColor: '#fff',
    borderRadius: 15,
    padding: 5,
  },
  userName: {
    fontSize: 24,
    fontWeight: 'bold',
    marginTop: 10,
  },
  userEmail: {
    fontSize: 14,
    color: '#888',
  },
  editProfileButton: {
    backgroundColor: '#000',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 25,
    marginTop: 20,
  },
  editProfileText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  section: {
    marginVertical: 20,
    paddingHorizontal: 20,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  presetCount: {
    fontSize: 14,
    color: '#888',
  },
  addPresetButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 15,
    padding: 15,
    marginBottom: 15,
    borderWidth: 1,
    borderColor: '#eee',
  },
  addPresetText: {
    fontSize: 16,
    fontWeight: 'bold',
    marginHorizontal: 5,
  },
  presetCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderRadius: 15,
    padding: 20,
    marginBottom: 10,
  },
  presetDetails: {
    flex: 1,
  },
  presetName: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  tagsContainer: {
    flexDirection: 'row',
  },
  tag: {
    backgroundColor: '#f0f0f0',
    borderRadius: 5,
    paddingHorizontal: 8,
    paddingVertical: 4,
    fontSize: 12,
    marginRight: 5,
  },
  presetActions: {
    flexDirection: 'row',
  },
  actionIcon: {
    marginLeft: 10,
  },
  settingsItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderRadius: 15,
    padding: 20,
    marginBottom: 10,
  },
  settingsItemLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  settingsText: {
    fontSize: 16,
    marginLeft: 10,
  },
  signOutButton: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderRadius: 15,
    padding: 20,
    marginTop: 20,
  },
});

export default ProfileScreen;