import * as Google from "expo-auth-session/providers/google";
import * as WebBrowser from "expo-web-browser";
import React, { useEffect, useState } from "react";
import {
    Alert,
    Image,
    Text,
    TextInput,
    TouchableOpacity,
    View,
} from "react-native";

// must stay at the top, outside the component
WebBrowser.maybeCompleteAuthSession();

export default function Signup() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginStarted, setLoginStarted] = useState(false);

  // ✅ 1️⃣  Add this line – your fixed redirect URI
  const redirectUri = "https://auth.expo.dev/@rikazqp/Rikaz";
  console.log("Redirect URI:", redirectUri);

  // ✅ 2️⃣  Use it inside your useAuthRequest
  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId: "464258371961-cdgkhagr0scfcgg85vpospljqeuu12hb.apps.googleusercontent.com", // from Google Cloud Console
    redirectUri, // <— use your hardcoded hosted URI here
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
    <View className="flex-1 justify-center bg-white px-6">
      <Text className="text-3xl font-bold text-center text-gray-800 mb-8">
        Create Account
      </Text>

      <TextInput
        placeholder="Full Name"
        value={name}
        onChangeText={setName}
        className="border border-gray-300 rounded-lg px-4 py-3 mb-4 text-base"
      />

      <TextInput
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        className="border border-gray-300 rounded-lg px-4 py-3 mb-4 text-base"
      />

      <TextInput
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        className="border border-gray-300 rounded-lg px-4 py-3 mb-6 text-base"
      />

      <TouchableOpacity
        onPress={handleSignup}
        className="bg-indigo-600 py-3 rounded-lg mb-5"
      >
        <Text className="text-center text-white text-lg font-semibold">
          Sign Up
        </Text>
      </TouchableOpacity>

      <Text className="text-center text-gray-500 mb-4">or</Text>

      <TouchableOpacity
        disabled={!request}
        onPress={handleGoogleConnect}
        className="flex-row justify-center items-center border border-gray-300 py-3 rounded-lg"
      >
        <Image
          source={{
            uri: "https://developers.google.com/identity/images/g-logo.png",
          }}
          style={{ width: 22, height: 22, marginRight: 8 }}
        />
        <Text className="font-medium text-gray-700 text-base">
          Connect Google Calendar
        </Text>
      </TouchableOpacity>
    </View>
  );
}
