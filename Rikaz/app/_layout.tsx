import { DefaultTheme, ThemeProvider } from "@react-navigation/native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import React, { useState } from "react";

export default function RootLayout() {
  // This will later be replaced with your real authentication logic (e.g. Firebase)
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
      </Stack>

      <StatusBar style="dark" />
    </ThemeProvider>
  );
}
