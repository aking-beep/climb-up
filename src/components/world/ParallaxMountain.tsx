import { Image, StyleSheet } from 'react-native';
import Animated, { useAnimatedStyle, type SharedValue } from 'react-native-reanimated';

const FAR = require('../../../assets/world/far-mountains.png');
const PEAK = require('../../../assets/world/everest-massif.png');

export function ParallaxMountain({ shift }: { shift: SharedValue<number> }) {
  const far = useAnimatedStyle(() => ({
    transform: [{ translateX: -56 * shift.value }],
  }));
  const peak = useAnimatedStyle(() => ({
    opacity: 0.88 + shift.value * 0.12,
    transform: [
      { translateX: -90 * shift.value },
      { translateY: 8 - shift.value * 28 },
      { scale: 0.58 + shift.value * 0.55 },
    ],
  }));

  return (
    <>
      <Animated.View style={[styles.far, far]}>
        <Image source={FAR} style={styles.farImage} resizeMode="cover" accessibilityIgnoresInvertColors />
      </Animated.View>
      <Animated.View style={[styles.peak, peak]}>
        <Image source={PEAK} style={styles.fill} resizeMode="contain" accessibilityIgnoresInvertColors />
      </Animated.View>
    </>
  );
}

const styles = StyleSheet.create({
  far: {
    position: 'absolute',
    left: -36,
    right: -80,
    height: '30%',
    bottom: '46%',
    overflow: 'hidden',
  },
  peak: {
    position: 'absolute',
    width: '70%',
    height: '42%',
    left: '15%',
    bottom: '36%',
  },
  farImage: { position: 'absolute', left: 0, right: 0, bottom: 0, width: '100%', height: '170%' },
  fill: { width: '100%', height: '100%' },
});
