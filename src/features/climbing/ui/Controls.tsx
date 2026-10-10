import { Pressable, StyleSheet, Text, View } from 'react-native';

import { font } from '@/theme';

import type { HeldKey } from '../runtime';

type Press = (key: HeldKey, down: boolean) => void;

function Pad({ press, dir, label, glyph }: { press: Press; dir: HeldKey; label: string; glyph: string }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint="Press and hold"
      onPressIn={() => press(dir, true)}
      onPressOut={() => press(dir, false)}
      hitSlop={6}
      style={({ pressed }) => [styles.pad, pressed && styles.padDown]}
    >
      <Text style={styles.glyph}>{glyph}</Text>
    </Pressable>
  );
}

/**
 * A four-way pad for one thumb. Every button is press-and-hold: climbing is
 * holding up, not tapping. No multi-finger gestures are needed.
 */
export function Controls({ press, leftHanded, bottom }: { press: Press; leftHanded: boolean; bottom: number }) {
  return (
    <View pointerEvents="box-none" style={[styles.wrap, { bottom, flexDirection: leftHanded ? 'row-reverse' : 'row' }]}>
      <View style={styles.cross}>
        <View style={styles.row}>
          <Pad press={press} dir="up" label="Climb up" glyph="▲" />
        </View>
        <View style={styles.row}>
          <Pad press={press} dir="left" label="Move left" glyph="◀" />
          <View style={styles.gap} />
          <Pad press={press} dir="right" label="Move right" glyph="▶" />
        </View>
        <View style={styles.row}>
          <Pad press={press} dir="down" label="Climb down" glyph="▼" />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', left: 14, right: 14 },
  cross: { gap: 4 },
  row: { flexDirection: 'row', justifyContent: 'center', gap: 4 },
  gap: { width: 64 },
  pad: {
    width: 64,
    height: 64,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(18,17,15,0.48)',
    borderWidth: 1,
    borderColor: 'rgba(244,241,234,0.35)',
  },
  padDown: { backgroundColor: 'rgba(244,241,234,0.4)' },
  glyph: { fontFamily: font.bodySemi, fontSize: 22, color: '#f4f1ea' },
});
