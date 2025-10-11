// This file assumes the following dependencies are installed in your Expo project:
// expo-auth-session, expo-router, expo-web-browser, react-native-safe-area-context
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
}
from "react-native";

WebBrowser.maybeCompleteAuthSession();

// --- CONFIGURATION ---
// IMPORTANT: This IP must match the local IP of the computer running your Node.js server.
const API_BASE_URL = 'http://192.168.2.149:8000/api'; 

// --- Client-side Hashing Utility ---
const simpleHash = (str: string) => {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        hash = (hash << 5) - hash + str.charCodeAt(i);
        hash |= 0; 
    }
    return hash.toString();
};


export default function Signup() {
    const [name, setName] = useState("");
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [loginStarted, setLoginStarted] = useState(false);
    const [isSubmitting, setIsSubmitting] = useState(false); // State for button loading/disabling
    
    // --- GOOGLE AUTHENTICATION SETUP ---
    const redirectUri = "https://auth.expo.dev/@rikazqp/Rikaz";
    
    const [request, response, promptAsync] = Google.useAuthRequest({
        clientId:
            "464258371961-cdgkhagr0scfcgg85vpospljqeuu12hb.apps.googleusercontent.com",
        redirectUri,
        scopes: ["https://www.googleapis.com/auth/calendar.events", "openid", "profile", "email"], 
    });

    useEffect(() => {
        if (!loginStarted || !response) return;

        if (response?.type === "success" && response.authentication) {
             console.log("✅ Google connected!");
             Alert.alert("Google Connected", "Calendar access granted!");
             setLoginStarted(false);
        } else if (response?.type === "error") {
             console.error("❌ Google sign-in error:", response.error);
             Alert.alert("Error", "Google sign-in failed.");
             setLoginStarted(false);
        }
    }, [response]);
    
    // --- DATABASE REGISTRATION LOGIC ---
    const handleSignup = async () => {
        if (!name || !email || !password) {
            Alert.alert("Required Fields Missing", "Please enter name, email, and password.");
            return;
        }

        setIsSubmitting(true);
        const url = `${API_BASE_URL}/register`; 
        const passwordHash = simpleHash(password); 

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, email, password_hash: passwordHash }), 
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.message || `HTTP Error ${response.status}`);
            }

            const data = await response.json();

            if (data.success) {
                Alert.alert("Account Created", `Welcome, ${name}!`);
                router.replace("/(tabs)"); // Navigate to home screen
            } else {
                Alert.alert("Registration Failed", data.message || "An unknown error occurred."); 
            }
        } catch (error) {
            console.error('API Error during signup:', error);
            const errorMessage = (error instanceof Error) ? error.message : 'Could not connect to the server for registration.';
            Alert.alert('Registration Error', errorMessage);

        } finally {
            setIsSubmitting(false); 
        }
    };
    // -----------------------------------

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
                editable={!isSubmitting}
            />
            <TextInput
                placeholder="Email"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                style={styles.input}
                editable={!isSubmitting}
            />
            <TextInput
                placeholder="Password"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                style={styles.input}
                editable={!isSubmitting}
            />

            <TouchableOpacity 
                onPress={handleSignup} 
                style={styles.signupButton}
                disabled={isSubmitting} 
            >
                <Text style={styles.signupText}>{isSubmitting ? 'Creating...' : 'Sign Up'}</Text>
            </TouchableOpacity>

            <Text style={styles.orText}>or</Text>

            <TouchableOpacity
                disabled={!request || isSubmitting}
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

// NOTE: The styles object MUST be placed AFTER the Signup function definition.
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