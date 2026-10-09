import { useEffect, useRef } from 'react';
import { Image, StyleSheet } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming, type SharedValue } from 'react-native-reanimated';

import type { GroundId } from './scene';

const GROUNDS: Record<GroundId, number> = {
  valley: require('../../../assets/world/ground-valley.png'),
  forest: require('../../../assets/world/ground-forest.png'),
  rock: require('../../../assets/world/ground-rock.png'),
  snow: require('../../../assets/world/ground-snow.png'),
  rainforest: require('../../../assets/world/ground-forest.png'),
  moorland: require('../../../assets/world/ground-valley.png'),
  desert: require('../../../assets/world/ground-rock.png'),
};

export function EnvironmentTransition({
  ground,
  shift,
}: {
  ground: GroundId;
  shift: SharedValue<number>;
}) {
  const fade = useSharedValue(1);
  const seen = useRef(ground);

  useEffect(() => {
    if (seen.current === ground) return;
    seen.current = ground;
    fade.value = 0.15;
    fade.value = withTiming(1, { duration: 700 });
  }, [fade, ground]);

  const style = useAnimatedStyle(() => ({
    opacity: fade.value,
    transform: [{ translateX: -150 * shift.value }],
  }));

  return (
    <Animated.View style={[styles.ground, style]}>
      <Image source={GROUNDS[ground]} style={styles.fill} resizeMode="cover" accessibilityIgnoresInvertColors />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  ground: {
    position: 'absolute',
    left: '-28%',
    width: '168%',
    height: '42%',
    bottom: 0,
    overflow: 'hidden',
  },
  fill: { position: 'absolute', left: 0, right: 0, bottom: 0, width: '100%', height: '150%' },
});
