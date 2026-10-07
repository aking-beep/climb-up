import { useEffect } from 'react';
import { Image, StyleSheet } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';

const CLOUDS = require('../../../assets/world/clouds.png');

export function CloudLayer({ still, storm }: { still?: boolean; storm: number }) {
  const drift = useSharedValue(0);

  useEffect(() => {
    drift.value = withRepeat(
      withTiming(-220, { duration: still ? 36000 : 22000, easing: Easing.linear }),
      -1,
      false,
    );
  }, [drift, still]);

  const style = useAnimatedStyle(() => ({
    opacity: 0.55 + Math.min(storm, 80) / 200,
    transform: [{ translateX: drift.value }],
  }));

  return (
    <Animated.View style={[styles.band, style]}>
      <Image source={CLOUDS} style={styles.cloud} resizeMode="contain" accessibilityIgnoresInvertColors />
      <Image source={CLOUDS} style={styles.cloud} resizeMode="contain" accessibilityIgnoresInvertColors />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  band: {
    position: 'absolute',
    top: '18%',
    left: 0,
    width: '210%',
    height: '24%',
    flexDirection: 'row',
  },
  cloud: { width: '50%', height: '100%' },
});
