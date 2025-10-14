import { DefaultTheme, ThemeProvider } from "@react-navigation/native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import React, { useEffect, useState } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";

export default function RootLayout() {
  const [initialRoute, setInitialRoute] = useState<string | null>(null);

  useEffect(() => {
    const checkSession = async () => {
      const session = await AsyncStorage.getItem("userSession");
      setInitialRoute(session ? "(tabs)" : "index");
    };
    checkSession();
  }, []);

  if (!initialRoute) return null;

  return (
    <ThemeProvider value={DefaultTheme}>
      <Stack screenOptions={{ headerShown: false }} initialRouteName={initialRoute}>
        <Stack.Screen name="index" />
        <Stack.Screen name="login" />
        <Stack.Screen name="(tabs)" />
      </Stack>
      <StatusBar style="dark" />
    </ThemeProvider>
  );
}
