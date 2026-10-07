import { useEffect } from 'react';
import { Image, StyleSheet } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming, type SharedValue } from 'react-native-reanimated';

const TENTS = require('../../../assets/world/camp-tents.png');

export function Camp({ visible, shift }: { visible: boolean; shift: SharedValue<number> }) {
  const opacity = useSharedValue(visible ? 1 : 0);

  useEffect(() => {
    opacity.value = withTiming(visible ? 1 : 0, { duration: 600 });
  }, [opacity, visible]);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateX: -90 * shift.value }],
  }));

  return (
    <Animated.View style={[styles.camp, style]}>
      <Image source={TENTS} style={styles.fill} resizeMode="contain" accessibilityIgnoresInvertColors />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  camp: {
    position: 'absolute',
    width: '46%',
    height: '28%',
    left: '4%',
    bottom: '16%',
    pointerEvents: 'none',
  },
  fill: { width: '100%', height: '100%' },
});
