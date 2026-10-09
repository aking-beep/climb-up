import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet, View } from 'react-native';

import type { DayPhase } from './scene';

const GRADE: Record<DayPhase, { color: string; opacity: number }> = {
  day: { color: '#f3e2b0', opacity: 0.08 },
  dawn: { color: '#e7a06a', opacity: 0.22 },
  dusk: { color: '#c46a3a', opacity: 0.28 },
  night: { color: '#0e1624', opacity: 0.5 },
};

/** Foreground and background fall soft. The rope team stays in the sharp band. */
export function TiltShift({ phase, storm }: { phase: DayPhase; storm: number }) {
  const grade = GRADE[phase];
  const weather = Math.max(0, storm - 30) / 180;
  return (
    <View style={styles.layer}>
      <BlurView intensity={22} tint="default" style={styles.far} />
      <BlurView intensity={28} tint="default" style={styles.near} />
      <LinearGradient
        colors={['rgba(255, 214, 140, 0.0)', 'rgba(255, 206, 120, 0.45)', 'rgba(255, 214, 140, 0)']}
        style={styles.bloom}
      />
      <View style={[styles.grade, { backgroundColor: grade.color, opacity: grade.opacity }]} />
      {weather > 0.04 ? <View style={[styles.grade, { backgroundColor: '#c5ced6', opacity: weather }]} /> : null}
      <LinearGradient colors={['rgba(12,10,8,0.45)', 'rgba(12,10,8,0)']} style={styles.vignetteTop} />
      <LinearGradient colors={['rgba(12,10,8,0)', 'rgba(12,10,8,0.5)']} style={styles.vignetteBottom} />
    </View>
  );
}

const styles = StyleSheet.create({
  layer: { ...StyleSheet.absoluteFill, pointerEvents: 'none' },
  far: { position: 'absolute', top: 0, left: 0, right: 0, height: '30%' },
  near: { position: 'absolute', bottom: 0, left: 0, right: 0, height: '10%' },
  bloom: {
    position: 'absolute',
    top: '-8%',
    left: '18%',
    right: '18%',
    height: '36%',
  },
  grade: StyleSheet.absoluteFill,
  vignetteTop: { position: 'absolute', top: 0, left: 0, right: 0, height: '22%' },
  vignetteBottom: { position: 'absolute', bottom: 0, left: 0, right: 0, height: '18%' },
});
