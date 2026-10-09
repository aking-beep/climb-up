import { useEffect } from 'react';
import { Image, StyleSheet, View, type ImageStyle } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';

import { PARTY, type PartyId, type Pose } from './scene';

const SPRITES: Record<PartyId, number> = {
  jun: require('../../../assets/world/pixel-jun.png'),
  marco: require('../../../assets/world/pixel-marco.png'),
  you: require('../../../assets/world/pixel-you.png'),
  lena: require('../../../assets/world/pixel-lena.png'),
};

/** Near camera first. The guide is farthest up the path. */
const DEPTH: Record<PartyId, number> = {
  jun: 0,
  marco: 0.22,
  you: 0.44,
  lena: 0.66,
};

function place(depth: number, towardCamera: boolean, progress: number) {
  const along = towardCamera ? 0.66 - depth : depth;
  const d = Math.min(0.9, Math.max(0, along + progress * 0.08));
  return {
    x: 49.5 + Math.sin(d * 6) * 1.5,
    y: 78 - d * 44,
    scale: 0.8 - d * 0.38,
  };
}

function Sprite({
  id,
  pose,
  depth,
  towardCamera,
  progress,
}: {
  id: PartyId;
  pose: Pose;
  depth: number;
  towardCamera: boolean;
  progress: number;
}) {
  const bob = useSharedValue(0);
  const spot = place(depth, towardCamera, progress);

  useEffect(() => {
    if (pose === 'kneel') {
      bob.value = withTiming(0, { duration: 200 });
      return;
    }
    bob.value = withRepeat(
      withTiming(1, { duration: pose === 'lag' ? 900 : 520, easing: Easing.inOut(Easing.sin) }),
      -1,
      true,
    );
  }, [bob, pose]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateY: bob.value * (pose === 'lag' ? -1 : -2) }],
  }));

  const height = 40 * spot.scale * (pose === 'kneel' ? 0.82 : 1);
  const width = height * (43 / 96);

  return (
    <Animated.View
      style={[
        styles.person,
        {
          left: `${spot.x}%`,
          top: `${spot.y}%`,
          width,
          height,
          marginLeft: -width / 2,
          marginTop: -height,
          zIndex: Math.round((1 - spot.scale) * -10 + 20),
        },
        style,
      ]}
    >
      <View style={[styles.shadow, pose === 'kneel' && styles.shadowDown]} />
      <Image
        source={SPRITES[id]}
        style={[styles.sprite, pose === 'lag' && styles.lag]}
        resizeMode="contain"
        accessibilityIgnoresInvertColors
      />
    </Animated.View>
  );
}

export function DioramaParty({
  poses,
  retreating,
  progress,
}: {
  poses: readonly Pose[];
  retreating: boolean;
  progress: number;
}) {
  const order = [...PARTY].sort((a, b) => DEPTH[b.id] - DEPTH[a.id]);
  return (
    <View style={styles.layer}>
      {order.map((person) => (
        <Sprite
          key={person.id}
          id={person.id}
          pose={poses[PARTY.findIndex((member) => member.id === person.id)] ?? 'walk'}
          depth={DEPTH[person.id]}
          towardCamera={retreating}
          progress={progress}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  layer: StyleSheet.absoluteFill,
  person: { position: 'absolute' },
  sprite: { width: '100%', height: '100%', imageRendering: 'pixelated' } as ImageStyle,
  lag: { opacity: 0.9 },
  shadow: {
    position: 'absolute',
    bottom: 1,
    left: '8%',
    width: '110%',
    height: 7,
    borderRadius: 6,
    backgroundColor: 'rgba(48, 32, 12, 0.38)',
    transform: [{ rotate: '-18deg' }, { scaleX: 1.3 }],
  },
  shadowDown: { opacity: 0.7, height: 5 },
});
