import { StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle, type SharedValue } from 'react-native-reanimated';

/** A cloth flag on the path. It is a game marker, not a surveyed point. */
export function RouteMarker({ shift }: { shift: SharedValue<number> }) {
  const style = useAnimatedStyle(() => ({
    transform: [{ translateX: 36 + shift.value * 120 }],
  }));

  return (
    <Animated.View style={[styles.mark, style]}>
      <View style={styles.flag} />
      <View style={styles.pole} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  mark: {
    position: 'absolute',
    bottom: '13%',
    left: '78%',
    alignItems: 'center',
    pointerEvents: 'none',
  },
  pole: {
    width: 2,
    height: 22,
    backgroundColor: '#3a342c',
  },
  flag: {
    width: 14,
    height: 9,
    marginLeft: 12,
    backgroundColor: '#1f3d34',
    borderTopRightRadius: 1,
    borderBottomRightRadius: 1,
  },
});
