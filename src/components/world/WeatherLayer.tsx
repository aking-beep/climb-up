import { StyleSheet, View } from 'react-native';

import type { DayPhase } from './scene';

/** A wash over the landscape. The rope team stays in front of it. */
export function WeatherLayer({ risk, phase }: { risk: number; phase: DayPhase }) {
  const storm = Math.max(0, risk - 28) / 140;
  const night = phase === 'night' ? 0.34 : phase === 'dusk' ? 0.1 : 0;
  const opacity = Math.min(0.5, storm + night);
  if (opacity < 0.04) return null;
  return <View style={[styles.veil, { opacity }]} />;
}

const styles = StyleSheet.create({
  veil: {
    ...StyleSheet.absoluteFill,
    backgroundColor: '#1a232c',
  },
});
