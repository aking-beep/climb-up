import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet } from 'react-native';

import { skyColors, type DayPhase } from './scene';

export function DayNightLayer({ phase }: { phase: DayPhase }) {
  const colors = skyColors(phase);
  return <LinearGradient colors={[colors[0], colors[1], colors[2]]} style={StyleSheet.absoluteFill} />;
}
