import { useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

const FLAKES = [
  { left: '6%', duration: 5200, delay: 0, size: 2 },
  { left: '18%', duration: 6400, delay: 400, size: 3 },
  { left: '29%', duration: 4800, delay: 900, size: 2 },
  { left: '41%', duration: 7000, delay: 200, size: 3 },
  { left: '53%', duration: 5600, delay: 1100, size: 2 },
  { left: '64%', duration: 6200, delay: 600, size: 3 },
  { left: '76%', duration: 5000, delay: 1400, size: 2 },
  { left: '88%', duration: 6800, delay: 300, size: 3 },
  { left: '12%', duration: 7400, delay: 1600, size: 2 },
  { left: '47%', duration: 5900, delay: 1800, size: 2 },
  { left: '71%', duration: 6600, delay: 800, size: 3 },
  { left: '94%', duration: 5400, delay: 1200, size: 2 },
] as const;

function Flake({ left, duration, delay, size }: (typeof FLAKES)[number]) {
  const fall = useSharedValue(0);

  useEffect(() => {
    fall.value = withDelay(
      delay,
      withRepeat(withTiming(1, { duration, easing: Easing.linear }), -1, false),
    );
  }, [delay, duration, fall]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateY: -20 + fall.value * 280 }, { translateX: fall.value * 18 }],
    opacity: 0.35 + fall.value * 0.4,
  }));

  return <Animated.View style={[styles.flake, { left, width: size, height: size }, style]} />;
}

export function SnowLayer({ density }: { density: number }) {
  if (density < 0.08) return null;
  const count = Math.max(4, Math.round(density * FLAKES.length));
  return (
    <>
      {FLAKES.slice(0, count).map((flake) => (
        <Flake key={flake.left + flake.delay} {...flake} />
      ))}
    </>
  );
}

const styles = StyleSheet.create({
  flake: {
    position: 'absolute',
    top: 0,
    borderRadius: 2,
    backgroundColor: '#f7f4ee',
  },
});
