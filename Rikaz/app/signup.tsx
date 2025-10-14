import * as Google from "expo-auth-session/providers/google";
import * as WebBrowser from "expo-web-browser";
import { router } from "expo-router";
import React, { useEffect, useState } from "react";
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

WebBrowser.maybeCompleteAuthSession();

const API_BASE_URL = "http://192.168.100.15:8000/api";
const RikazLogo = require("../assets/images/RikazLogo.png");

export default function Signup() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Google Authentication
  const redirectUri = "https://auth.expo.dev/@rikazqp/Rikaz";
  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId:
      "464258371961-cdgkhagr0scfcgg85vpospljqeuu12hb.apps.googleusercontent.com",
    redirectUri,
    scopes: ["openid", "profile", "email"],
  });

  useEffect(() => {
    if (response?.type === "success") {
      Alert.alert("Google Connected", "Calendar access granted!");
    } else if (response?.type === "error") {
      Alert.alert("Google Sign-In Error", "Failed to connect Google.");
    }
  }, [response]);

  const handleSignup = async () => {
    if (!name || !email || !password) {
      Alert.alert("Missing Info", "Please fill in all fields.");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await fetch(`${API_BASE_URL}/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password }),
      });

      const data = await res.json();
      if (!res.ok || !data.success) {
        throw new Error(data.message || "Registration failed.");
      }

      await AsyncStorage.setItem("userSession", JSON.stringify({ email }));
      Alert.alert("Account Created", `Welcome, ${name}!`);
      router.replace("/(tabs)");
    } catch (err: any) {
      console.error("Signup Error:", err);
      Alert.alert("Signup Error", err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <View style={styles.container}>
      <Image source={RikazLogo} style={styles.logo} resizeMode="contain" />
      <Text style={styles.title}>Create Account</Text>

      <TextInput
        placeholder="Full Name"
        value={name}
        onChangeText={setName}
        style={styles.input}
      />
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
        onPress={handleSignup}
        style={styles.signupButton}
        disabled={isSubmitting}
      >
        <Text style={styles.signupText}>
          {isSubmitting ? "Creating..." : "Sign Up"}
        </Text>
      </TouchableOpacity>

      <Text style={styles.orText}>or</Text>

      <TouchableOpacity
        disabled={!request || isSubmitting}
        onPress={() => promptAsync()}
        style={styles.googleButton}
      >
        <Image
          source={{
            uri: "https://developers.google.com/identity/images/g-logo.png",
          }}
          style={styles.googleIcon}
        />
        <Text style={styles.googleText}>Connect Google Calendar</Text>
      </TouchableOpacity>

      <Pressable
        onPress={() => router.replace("/login")}
        style={({ pressed }) => [
          styles.continueButton,
          pressed && styles.buttonPressed,
        ]}
      >
        <Text style={styles.continueText}>Already have an account? Log in</Text>
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
  signupButton: {
    backgroundColor: "#4f46e5",
    borderRadius: 8,
    paddingVertical: 14,
    marginBottom: 16,
  },
  signupText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
    textAlign: "center",
  },
  orText: {
    textAlign: "center",
    color: "#666",
    marginVertical: 10,
  },
  googleButton: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 8,
    paddingVertical: 12,
  },
  googleIcon: {
    width: 22,
    height: 22,
    marginRight: 8,
  },
  googleText: {
    fontSize: 15,
    color: "#333",
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
