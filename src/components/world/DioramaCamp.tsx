import { useEffect } from 'react';
import { Image, StyleSheet, View, type ImageStyle } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

const TENT = require('../../../assets/world/pixel-tent.png');

const TENTS = [
  { x: 30, y: 76, width: 62 },
  { x: 69, y: 66, width: 44 },
] as const;

/** Two tents beside the path. They appear when the team is in camp. */
export function DioramaCamp({ visible }: { visible: boolean }) {
  const opacity = useSharedValue(visible ? 1 : 0);

  useEffect(() => {
    opacity.value = withTiming(visible ? 1 : 0, { duration: 700 });
  }, [opacity, visible]);

  const style = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return (
    <Animated.View style={[styles.layer, style]}>
      {TENTS.map((tent) => {
        const height = tent.width * (60 / 96);
        return (
          <View
            key={tent.x}
            style={[
              styles.tent,
              {
                left: `${tent.x}%`,
                top: `${tent.y}%`,
                width: tent.width,
                height,
                marginLeft: -tent.width / 2,
                marginTop: -height,
              },
            ]}
          >
            <Image source={TENT} style={styles.image} resizeMode="contain" accessibilityIgnoresInvertColors />
          </View>
        );
      })}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  layer: { ...StyleSheet.absoluteFill, pointerEvents: 'none' },
  tent: { position: 'absolute' },
  image: { width: '100%', height: '100%', imageRendering: 'pixelated' } as ImageStyle,
});
