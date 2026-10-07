import { useEffect } from 'react';
import { Image, StyleSheet, View } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';

import { PARTY, type PartyId, type Pose } from './scene';

const SPRITES: Record<PartyId, number> = {
  jun: require('../../../assets/world/climber-jun.png'),
  marco: require('../../../assets/world/climber-marco.png'),
  you: require('../../../assets/world/climber-lead.png'),
  lena: require('../../../assets/world/climber-guide.png'),
};

const KNEEL = require('../../../assets/world/climber-kneel.png');

function Walker({ id, pose }: { id: PartyId; pose: Pose }) {
  const bob = useSharedValue(0);

  useEffect(() => {
    if (pose === 'kneel') {
      bob.value = withTiming(0, { duration: 240 });
      return;
    }
    bob.value = withRepeat(
      withTiming(1, { duration: pose === 'lag' ? 820 : 480, easing: Easing.inOut(Easing.sin) }),
      -1,
      true,
    );
  }, [bob, pose]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateY: bob.value * (pose === 'lag' ? -2 : -4) + (pose === 'lag' ? 5 : 0) }],
  }));

  return (
    <Animated.View style={[styles.person, pose === 'lag' && styles.lag, style]}>
      <Image
        source={pose === 'kneel' && id === 'marco' ? KNEEL : SPRITES[id]}
        style={styles.sprite}
        resizeMode="contain"
        accessibilityIgnoresInvertColors
      />
    </Animated.View>
  );
}

export function ExpeditionParty({ poses, facing }: { poses: readonly Pose[]; facing: 'left' | 'right' }) {
  return (
    <View style={[styles.row, facing === 'left' ? styles.descend : styles.ascend]}>
      <View style={[styles.ropeTeam, facing === 'left' && styles.faceLeft]}>
        <View style={styles.rope} />
        {PARTY.map((person, index) => (
          <Walker key={person.id} id={person.id} pose={poses[index] ?? 'walk'} />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    position: 'absolute',
    left: 8,
    right: 8,
    bottom: '7%',
    pointerEvents: 'none',
  },
  ascend: { alignItems: 'flex-start' },
  descend: { alignItems: 'flex-end' },
  ropeTeam: {
    width: 300,
    maxWidth: '100%',
    height: 118,
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
  },
  faceLeft: { transform: [{ scaleX: -1 }] },
  rope: {
    position: 'absolute',
    left: 28,
    right: 28,
    bottom: 78,
    height: 2,
    backgroundColor: '#3a342c',
    opacity: 0.8,
    transform: [{ rotate: '-4deg' }],
  },
  person: { width: 68, height: 112 },
  lag: { opacity: 0.92 },
  sprite: { width: '100%', height: '100%' },
});
