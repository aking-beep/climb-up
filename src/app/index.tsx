import { router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Frame } from '@/components/Frame';
import { Mountain } from '@/components/Mountain';
import { createGame, formatSeed } from '@/game/engine';
import { parseSeed } from '@/game/world';
import { body, font, ink, line, muted, paper, rust, rustInk, SKY, skyInk } from '@/theme';
import { LinearGradient } from 'expo-linear-gradient';

const PRINCIPLES = [
  'Four people are on your rope. Their condition is the game.',
  'Warmth, food, daylight, the rope, lungs, and morale are real. Tomorrow’s weather is posted.',
  'How high you climb isn’t how you win. The ledger counts who comes home.',
];

export default function TitleScreen() {
  const insets = useSafeAreaInsets();
  const [code, setCode] = useState('');
  const inkOnSky = skyInk('clear');
  const parsed = parseSeed(code);
  const invalid = code.trim().length > 0 && parsed === undefined;

  function begin() {
    const seed = parsed ?? createGame().seed;
    router.push({ pathname: '/climb', params: { code: formatSeed(seed) } });
  }

  return (
    <Frame>
      <StatusBar style="light" />
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <LinearGradient
            colors={SKY.clear}
            locations={[0, 0.46, 1]}
            style={[styles.sky, { paddingTop: insets.top + 12 }]}
          >
            <Text style={[styles.kicker, { color: inkOnSky }]}>Kharung · 6,420 m</Text>
            <View style={styles.ridge}>
              <Mountain band={0} weather="clear" ink={inkOnSky} />
            </View>
          </LinearGradient>
          <View style={[styles.sheet, { paddingBottom: insets.bottom + 28 }]}>
            <Text style={styles.title}>Climb Up</Text>
            <Text style={styles.tagline}>How high you climb isn’t how you win.</Text>
            {PRINCIPLES.map((lineText) => (
              <Text key={lineText} style={styles.principle}>
                {lineText}
              </Text>
            ))}
            <Text style={styles.label}>Expedition code</Text>
            <TextInput
              value={code}
              onChangeText={setCode}
              autoCapitalize="characters"
              autoCorrect={false}
              placeholder="Leave blank for a new mountain"
              placeholderTextColor="#8a8176"
              style={styles.input}
              accessibilityLabel="Expedition code"
              returnKeyType="go"
              onSubmitEditing={begin}
            />
            {invalid ? (
              <Text style={styles.invalid}>That code is not an expedition. A new one will start.</Text>
            ) : null}
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Start the expedition"
              onPress={begin}
              style={({ pressed }) => [styles.go, pressed && styles.pressed]}
            >
              <Text style={styles.goText}>Start the expedition</Text>
            </Pressable>
            <Text style={styles.foot}>Kharung is fictional. The turnaround is not.</Text>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </Frame>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scroll: { flexGrow: 1 },
  sky: { minHeight: 250 },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 13,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    paddingHorizontal: 22,
  },
  ridge: { height: 180 },
  sheet: {
    flexGrow: 1,
    marginTop: -18,
    backgroundColor: paper,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 22,
    paddingTop: 26,
  },
  title: {
    fontFamily: font.displayBold,
    fontSize: 52,
    lineHeight: 54,
    color: body,
  },
  tagline: {
    marginTop: 8,
    fontFamily: font.italic,
    fontSize: 22,
    lineHeight: 28,
    color: body,
  },
  principle: {
    marginTop: 14,
    fontFamily: font.body,
    fontSize: 16,
    lineHeight: 22,
    color: body,
  },
  label: {
    marginTop: 22,
    fontFamily: font.bodyMedium,
    fontSize: 13,
    color: muted,
    letterSpacing: 0.4,
  },
  input: {
    marginTop: 8,
    borderWidth: 1,
    borderColor: line,
    backgroundColor: '#fffdf8',
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 14,
    fontFamily: font.body,
    fontSize: 16,
    color: body,
  },
  invalid: {
    marginTop: 8,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 20,
    color: '#8d2d1f',
  },
  go: {
    marginTop: 18,
    backgroundColor: rust,
    borderRadius: 16,
    minHeight: 56,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  pressed: { opacity: 0.86 },
  goText: {
    fontFamily: font.display,
    fontSize: 22,
    color: rustInk,
  },
  foot: {
    marginTop: 16,
    fontFamily: font.body,
    fontSize: 13,
    color: muted,
  },
});
