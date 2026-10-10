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

import { ExpeditionScene } from '@/components/world/ExpeditionScene';
import { Screen } from '@/components/ui/Screen';
import { KILI_DISCLAIMER, KILI_PROGRESS, checkpointName } from '@/expeditions/kilimanjaro';
import { gameStore, useGameSession } from '@/game/session';
import { body, font, line, muted, paper, spruce, spruceInk } from '@/theme';
import { formatElapsed, formatSeed, parseSeed } from '@/utils/number';

const ROUTE = KILI_PROGRESS.map((stop) => stop.name).join(' → ');

export default function TitleScreen() {
  const insets = useSafeAreaInsets();
  const [code, setCode] = useState('');
  const parsed = parseSeed(code);
  const invalid = code.trim().length > 0 && parsed === undefined;
  const session = useGameSession();
  const saved = session && session.state.status === 'active' ? session : null;

  function begin() {
    const seed = parsed ?? (Math.floor(Math.random() * 1_000_000_000) || 1);
    gameStore.start(seed);
    router.push({ pathname: '/climb', params: { code: formatSeed(seed) } });
  }

  function resume() {
    if (!saved) return;
    router.push({ pathname: '/climb', params: { code: formatSeed(saved.state.seed) } });
  }

  return (
    <Screen>
      <StatusBar style="light" />
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <View style={[styles.mast, { paddingTop: insets.top + 16 }]}>
            <Text style={styles.kicker}>Kilimanjaro · Ten days</Text>
            <View style={styles.world}>
              <ExpeditionScene
                still
                world={{
                  checkpoint: 'briefing',
                  altitude: 2100,
                  retreating: false,
                  elapsedHours: 0,
                  weatherRisk: 12,
                  teamCondition: 90,
                  energy: 88,
                }}
              />
            </View>
          </View>
          <View style={styles.sheet}>
            <Text style={styles.title} accessibilityRole="header">
              Climb Up
            </Text>
            <Text style={styles.tagline}>{"How high you climb isn't how you win."}</Text>
            <Text style={styles.lede}>
              Ten days on a simplified Lemosho. Each camp arrives after dark, and the night is its own decision before the morning walk. The team keeps going only while the way down is still real. A careful retreat can outscore a reckless summit.
            </Text>
            <Text style={styles.routeLabel}>Simplified 10-day Lemosho</Text>
            <Text style={styles.route}>{ROUTE}</Text>
            <View style={styles.notice}>
              <Text style={styles.noticeLabel}>Not a manual</Text>
              <Text style={styles.noticeText}>{KILI_DISCLAIMER}</Text>
            </View>
          </View>
        </ScrollView>
        <View style={[styles.dock, { paddingBottom: insets.bottom + 14 }]}>
          {saved ? (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Continue the saved expedition"
              onPress={resume}
              style={({ pressed }) => [styles.go, styles.resume, pressed && styles.pressed]}
            >
              <Text style={styles.goText}>
                {saved.pending ? 'Return to the Barranco Wall' : 'Continue the expedition'}
              </Text>
              <Text style={styles.resumeDetail}>
                {checkpointName(saved.state.checkpoint)} · {formatElapsed(saved.state.elapsedHours)} · {formatSeed(saved.state.seed)}
              </Text>
            </Pressable>
          ) : null}
          <Text style={styles.label}>Expedition code</Text>
          <TextInput
            value={code}
            onChangeText={setCode}
            autoCapitalize="characters"
            autoCorrect={false}
            autoComplete="off"
            placeholder="Leave blank for a new expedition"
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
            <Text style={styles.goText}>{saved ? 'Start a new expedition' : 'Start the expedition'}</Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  scroll: { flexGrow: 1, backgroundColor: paper },
  mast: {
    backgroundColor: spruce,
    paddingHorizontal: 22,
    paddingBottom: 8,
  },
  world: { height: 268, marginTop: 10 },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 1.3,
    textTransform: 'uppercase',
    color: spruceInk,
    opacity: 0.82,
  },
  sheet: {
    flexGrow: 1,
    paddingHorizontal: 22,
    paddingTop: 22,
    paddingBottom: 18,
  },
  dock: {
    paddingHorizontal: 22,
    paddingTop: 12,
    backgroundColor: paper,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  title: {
    fontFamily: font.displayBold,
    fontSize: 48,
    lineHeight: 50,
    color: body,
  },
  tagline: {
    marginTop: 10,
    fontFamily: font.italic,
    fontSize: 22,
    lineHeight: 28,
    color: body,
  },
  lede: {
    marginTop: 14,
    fontFamily: font.body,
    fontSize: 16,
    lineHeight: 23,
    color: body,
  },
  routeLabel: {
    marginTop: 22,
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: muted,
  },
  route: {
    marginTop: 6,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 21,
    color: body,
  },
  notice: {
    marginTop: 20,
    paddingTop: 14,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  noticeLabel: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: muted,
  },
  noticeText: {
    marginTop: 6,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 20,
    color: body,
  },
  label: {
    fontFamily: font.bodyMedium,
    fontSize: 13,
    color: muted,
    letterSpacing: 0.4,
  },
  input: {
    marginTop: 8,
    borderWidth: 1,
    borderColor: line,
    backgroundColor: '#faf7f1',
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
    color: '#7a3b2e',
  },
  go: {
    marginTop: 18,
    backgroundColor: spruce,
    minHeight: 56,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  pressed: { opacity: 0.84 },
  resume: { marginTop: 0, marginBottom: 14, paddingVertical: 10 },
  resumeDetail: { marginTop: 2, fontFamily: font.body, fontSize: 13, color: spruceInk, opacity: 0.8 },
  goText: {
    fontFamily: font.display,
    fontSize: 20,
    color: spruceInk,
  },
});
