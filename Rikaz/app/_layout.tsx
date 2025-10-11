import { DefaultTheme, ThemeProvider } from "@react-navigation/native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import React, { useState } from "react";

export default function RootLayout() {
  const [user, setUser] = useState<boolean>(false);

  return (
    <ThemeProvider value={DefaultTheme}>
      <Stack screenOptions={{ headerShown: false }}>
        {!user ? (
          // Show the signup screen first
          <Stack.Screen name="signup" />
        ) : (
          // Once logged in, show the tab navigator
          <Stack.Screen name="(tabs)" />
        )}

        {/* Add Session screen here */}
        <Stack.Screen
          name="Session"
          options={{
            gestureEnabled: false,
            headerShown: false, // keep your fullscreen session look
          }}
        />
      </Stack>

      <StatusBar style="dark" />
    </ThemeProvider>
  );
}
