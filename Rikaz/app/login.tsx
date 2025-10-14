import { router } from "expo-router";
import React, { useState } from "react";
import {
  Alert,
  Image,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";

const API_BASE_URL = "http://192.168.100.15:8000/api";
const RikazLogo = require("../assets/images/RikazLogo.png");

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert("Missing Info", "Please fill in all fields.");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await fetch(`${API_BASE_URL}/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.message || "Invalid credentials.");
      }

      await AsyncStorage.setItem("userSession", JSON.stringify({ email }));
      Alert.alert("Welcome Back!", `Logged in as ${email}`);
      router.replace("/(tabs)");
    } catch (err: any) {
      console.error("Login Error:", err);
      Alert.alert("Login Error", err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <View style={styles.container}>
      <Image source={RikazLogo} style={styles.logo} resizeMode="contain" />
      <Text style={styles.title}>Welcome Back!</Text>
      <Text style={styles.subtitle}>Log in to continue</Text>

      <TextInput
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        style={styles.input}
      />
      <TextInput
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        style={styles.input}
      />

      <TouchableOpacity
        onPress={handleLogin}
        style={styles.loginButton}
        disabled={isSubmitting}
      >
        <Text style={styles.loginText}>
          {isSubmitting ? "Logging in..." : "Log In"}
        </Text>
      </TouchableOpacity>

      <Pressable
        onPress={() => router.replace("/signup")}
        style={({ pressed }) => [
          styles.continueButton,
          pressed && styles.buttonPressed,
        ]}
      >
        <Text style={styles.continueText}>Don’t have an account? Sign Up</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    backgroundColor: "#fff",
    paddingHorizontal: 24,
  },
  logo: {
    width: 150,
    height: 150,
    alignSelf: "center",
    marginBottom: 10,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    textAlign: "center",
    color: "#222",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: "#666",
    textAlign: "center",
    marginBottom: 24,
  },
  input: {
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 12,
  },
  loginButton: {
    backgroundColor: "#4f46e5",
    borderRadius: 8,
    paddingVertical: 14,
    marginBottom: 16,
  },
  loginText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
    textAlign: "center",
  },
  continueButton: {
    marginTop: 20,
    alignSelf: "center",
    paddingVertical: 10,
    paddingHorizontal: 20,
  },
  continueText: {
    color: "#4f46e5",
    fontSize: 15,
  },
  buttonPressed: {
    opacity: 0.5,
  },
});
