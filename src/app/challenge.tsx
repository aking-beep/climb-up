import { router, Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { ChallengeHost } from '@/features/climbing/ui/ChallengeHost';
import { gameStore, settingsStore, useGameSession, useSettings } from '@/game/session';
import { body, font, paper, spruce, spruceInk } from '@/theme';

function backToCamp() {
  if (router.canGoBack()) router.back();
  else router.replace('/climb');
}

export default function ChallengeScreen() {
  const session = useGameSession();
  const settings = useSettings();
  // Pinned on entry: the pending record disappears from the store the moment
  // the outcome lands, and the screen should not flash before it leaves.
  const [pending] = useState(() => gameStore.get()?.pending ?? null);
  const [state] = useState(() => gameStore.get()?.state ?? null);

  if (!pending || !state || !session) {
    return (
      <View style={styles.empty}>
        <Text style={styles.text}>There is no climb waiting.</Text>
        <Pressable accessibilityRole="button" onPress={backToCamp} style={styles.button}>
          <Text style={styles.buttonText}>Back to the expedition</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <>
      <Stack.Screen options={{ gestureEnabled: false, animation: 'fade' }} />
      <StatusBar style="light" />
      <ChallengeHost
        pending={pending}
        state={state}
        settings={settings}
        onSettings={(patch) => settingsStore.update(patch)}
        onFinish={(outcome) => {
          gameStore.resolve(outcome);
          backToCamp();
        }}
        onBackOff={() => {
          gameStore.abandon();
          backToCamp();
        }}
      />
    </>
  );
}

const styles = StyleSheet.create({
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: paper, padding: 24, gap: 16 },
  text: { fontFamily: font.body, fontSize: 16, color: body },
  button: { backgroundColor: spruce, paddingHorizontal: 18, minHeight: 52, justifyContent: 'center' },
  buttonText: { fontFamily: font.display, fontSize: 18, color: spruceInk },
});
