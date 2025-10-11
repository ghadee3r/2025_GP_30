import * as Google from "expo-auth-session/providers/google";
import { router } from "expo-router";
import * as WebBrowser from "expo-web-browser";
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

WebBrowser.maybeCompleteAuthSession();

export default function Signup() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginStarted, setLoginStarted] = useState(false);

  // hard-coded hosted redirect (replace with rikaz://redirect if using dev build)
  const redirectUri = "https://auth.expo.dev/@rikazqp/Rikaz";
  console.log("Redirect URI:", redirectUri);

  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId:
      "464258371961-cdgkhagr0scfcgg85vpospljqeuu12hb.apps.googleusercontent.com",
    redirectUri,
    scopes: ["https://www.googleapis.com/auth/calendar.events"],
  });

  useEffect(() => {
    if (!loginStarted) return;

    if (response?.type === "success" && response.authentication) {
      console.log("✅ Google connected!");
      console.log("Access token:", response.authentication.accessToken);
      Alert.alert("Google Connected", "Calendar access granted!");
      setLoginStarted(false);
    } else if (response?.type === "error") {
      if (
        response.error?.message?.includes("Cross-Site") ||
        response.error?.message?.includes("state do not match")
      ) {
        console.log("⚠️ Ignored cached OAuth resume mismatch");
        setLoginStarted(false);
        return;
      }
      console.error("❌ Google sign-in error:", response.error);
      Alert.alert("Error", "Google sign-in failed.");
      setLoginStarted(false);
    }
  }, [response]);

  const handleSignup = () => {
    console.log("Signup:", { name, email, password });
    Alert.alert("Account Created", "You signed up successfully!");
  };

  const handleGoogleConnect = async () => {
    setLoginStarted(true);
    await promptAsync();
  };

  return (
    <View style={styles.container}>
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

      <TouchableOpacity onPress={handleSignup} style={styles.signupButton}>
        <Text style={styles.signupText}>Sign Up</Text>
      </TouchableOpacity>

      <Text style={styles.orText}>or</Text>

      <TouchableOpacity
        disabled={!request}
        onPress={handleGoogleConnect}
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

      {/* moved the Pressable inside the return */}
      <Pressable
        onPress={() => router.replace("/(tabs)")}
        style={({ pressed }) => [
          styles.continueButton,
          pressed && styles.buttonPressed,
        ]}
      >
        <Text style={styles.continueText}>
          Continue without account (till now)
        </Text>
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
