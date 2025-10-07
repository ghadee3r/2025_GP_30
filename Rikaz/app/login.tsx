// app/login.tsx

import { router } from 'expo-router';
import React, { useState } from 'react';
import { Image, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
const RikazLogo = require('../assets/images/RikazLogo.png');

/**
 * Rikaz Login Screen
 * - Navigates to home: router.replace('/(tabs)') which resolves to (tabs)/index.tsx
 * - Button: black background, white text (per your request)
 * - Minimal local validation; you can swap in real auth later
 */
export default function LoginScreen(): React.JSX.Element {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const onSubmit = async () => {
    setError(null);

    // Very light client-side checks to reduce common runtime errors
    const trimmedEmail = email.trim();
    const trimmedPassword = password.trim();
    if (!trimmedEmail || !trimmedPassword) {
      setError('Please enter email and password.');
      return;
    }

    try {
      setSubmitting(true);

      // TODO: replace with your real authentication call.
      // Simulate success to demonstrate navigation:
      await new Promise((r) => setTimeout(r, 400));

      // Important:
      // Use replace so user cannot "back" to login after success.
      router.replace('/(tabs)');
    } catch (e) {
      setError('Login failed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.select({ ios: 'padding', android: undefined })}
      >
        <View style={styles.container}>
              {/* Rikaz Logo */}
              <Image source={RikazLogo} style={styles.logo} resizeMode="contain" />

          {/* Page title (use your own wording) */}
          <Text style={styles.title}>Welcome back!</Text>
          <Text style={styles.subtitle}>Log in to continue</Text>

          {/* Email */}
          <View style={styles.card}>
            <Text style={styles.label}>Email address</Text>
            <TextInput
              style={styles.input}
              value={email}
              onChangeText={setEmail}
              placeholder="name@example.com"
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              textContentType="emailAddress"
              // Keep returnKeyType to help usability:
              returnKeyType="next"
            />
          </View>

          {/* Password */}
          <View style={styles.card}>
            <Text style={styles.label}>Password</Text>
            <TextInput
              style={styles.input}
              value={password}
              onChangeText={setPassword}
              placeholder="••••••••"
              secureTextEntry
              autoCapitalize="none"
              autoCorrect={false}
              textContentType="password"
              returnKeyType="done"
              onSubmitEditing={onSubmit}
            />
          </View>

          {/* Error message (if any) */}
          {!!error && <Text style={styles.error}>{error}</Text>}

        {/* Main Login button */}
        <Pressable
        onPress={onSubmit}
        disabled={submitting}
        style={({ pressed }) => [
            styles.button,
            pressed && styles.buttonPressed,
            submitting && styles.buttonDisabled,
        ]}
        >
        <Text style={styles.buttonText}>
            {submitting ? 'Logging in…' : 'Log in'}
        </Text>
        </Pressable>

        {/* Temporary dev bypass button */}
        <Pressable
        onPress={() => router.replace('/(tabs)')}
        style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
        >
        <Text style={styles.buttonText}>Continue without account (till now)</Text>
        </Pressable>


          {/* Optional: helper text / links area */}
          <Text style={styles.helper}>
            By continuing you agree to our terms.
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: '#F6F4F1', // soft, neutral background to match your theme direction
  },
  flex: { flex: 1 },
  container: {
    flex: 1,
    paddingHorizontal: 20,
    justifyContent: 'center',
  },
  logo: {
    width: 150,
    height: 150,
    alignSelf: 'center',
    marginBottom: 10,
    marginTop: -40,

  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 4,
    color: '#1E1E1E',
  },
  subtitle: {
    fontSize: 14,
    color: '#6A6A6A',
    marginBottom: 24,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E6E2DC',
  },
  label: {
    fontSize: 12,
    color: '#7A7A7A',
    marginBottom: 6,
  },
  input: {
    fontSize: 16,
    paddingVertical: 8,
    color: '#1E1E1E',
  },
  error: {
    color: '#B00020',
    marginTop: 4,
    marginBottom: 10,
  },
  button: {
    backgroundColor: '#000000', // black button per requirement
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 4,
  },
  buttonPressed: {
    opacity: 0.9,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#FFFFFF', // white text
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
  helper: {
    textAlign: 'center',
    color: '#868686',
    marginTop: 14,
    fontSize: 12,
  },
});
