import type { ComponentProps, ComponentType } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { body, font, line, muted, paper, spruce, spruceInk } from '@/theme';

import type { ChallengeView as ChallengeViewType } from './ChallengeView';

type Props = ComponentProps<typeof ChallengeViewType>;

/**
 * Skia is a native module. If it is missing from the binary (an Expo Go
 * build without it, or a development build made before it was added), the
 * climb screen must not crash the expedition: it explains and lets the
 * player back off, which resolves the attempt through the normal path.
 */
let Loaded: ComponentType<Props> | null = null;
let failure: string | null = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  Loaded = (require('./ChallengeView') as { ChallengeView: ComponentType<Props> }).ChallengeView;
} catch (error) {
  failure = error instanceof Error ? error.message : String(error);
  console.warn(`CLIMB UP: the climbing renderer did not load (${failure}).`);
}

export function ChallengeHost(props: Props) {
  if (Loaded) return <Loaded {...props} />;
  return (
    <View style={styles.wrap}>
      <Text style={styles.kicker}>Graphics unavailable</Text>
      <Text style={styles.title}>The wall cannot be drawn on this build</Text>
      <Text style={styles.body}>
        The climbing scene needs React Native Skia, which this app binary does not include. A development build
        fixes it. Backing off keeps the expedition going: the party stays at Barranco.
      </Text>
      <Text style={styles.detail}>{failure}</Text>
      <Pressable accessibilityRole="button" onPress={props.onBackOff} style={({ pressed }) => [styles.button, pressed && styles.pressed]}>
        <Text style={styles.buttonText}>Back off and stay at Barranco</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: paper },
  kicker: { fontFamily: font.bodyMedium, fontSize: 11, letterSpacing: 1.1, textTransform: 'uppercase', color: muted },
  title: { fontFamily: font.display, fontSize: 24, lineHeight: 28, color: body },
  body: { fontFamily: font.body, fontSize: 15, lineHeight: 21, color: body },
  detail: { fontFamily: font.body, fontSize: 12, color: muted, borderTopWidth: 1, borderTopColor: line, paddingTop: 8 },
  button: { marginTop: 8, backgroundColor: spruce, minHeight: 52, justifyContent: 'center', paddingHorizontal: 14 },
  pressed: { opacity: 0.82 },
  buttonText: { fontFamily: font.display, fontSize: 18, color: spruceInk },
});
