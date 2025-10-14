import { useEffect } from "react";
import { router } from "expo-router";
import { View, ActivityIndicator } from "react-native";

 export default function Index() {
  useEffect(() => {
    // Redirect immediately to signup
    router.replace("/signup");
  }, []);

  // Show a tiny loader while redirecting
  return (
    <View
      style={{
        flex: 1,
        justifyContent: "center",
        alignItems: "center",
        backgroundColor: "#fff",
      }}
    >
      <ActivityIndicator size="large" color="#4f46e5" />
    </View>
  );
}
