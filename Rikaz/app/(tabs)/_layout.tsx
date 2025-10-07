// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';
import React from 'react';
import { MaterialIcons } from '@expo/vector-icons';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';

export default function TabLayout() {
  const colorScheme = useColorScheme();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors[colorScheme ?? 'light'].tint,
        headerShown: false,
      }}>
      <Tabs.Screen
        name="index" // اسم الملف: index.tsx
        options={{
          title: 'Home',
          tabBarIcon: ({ color }) => <MaterialIcons name="home" size={24} color={color} />,
        }}
      />
      <Tabs.Screen
        name="progress" // اسم الملف: progress.tsx
        options={{
          title: 'Progress',
          tabBarIcon: ({ color }) => <MaterialIcons name="trending-up" size={24} color={color} />,
        }}
      />
      <Tabs.Screen
        name="games" // اسم الملف: games.tsx
        options={{
          title: 'Games',
          tabBarIcon: ({ color }) => <MaterialIcons name="gamepad" size={24} color={color} />,
        }}
      />
      <Tabs.Screen
        name="profile" // اسم الملف: profile.tsx
        options={{
          title: 'Profile',
          tabBarIcon: ({ color }) => <MaterialIcons name="person" size={24} color={color} />,
        }}
      />
    </Tabs>
  );
}