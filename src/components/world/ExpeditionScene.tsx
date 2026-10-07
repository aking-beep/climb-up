import { useEffect } from 'react';
import { Image, StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { terrainFor } from '@/expeditions/everest/terrain';
import type { CheckpointId } from '@/game/types';

import { Camp } from './Camp';
import { CloudLayer } from './CloudLayer';
import { DayNightLayer } from './DayNightLayer';
import { EnvironmentTransition } from './EnvironmentTransition';
import { ExpeditionParty } from './ExpeditionParty';
import { ParallaxMountain } from './ParallaxMountain';
import { RouteMarker } from './RouteMarker';
import { SnowLayer } from './SnowLayer';
import { WeatherLayer } from './WeatherLayer';
import {
  campVisible,
  dayPhase,
  expeditionHour,
  groundFor,
  partyLabel,
  partyPoses,
  routeProgress,
  snowDensity,
} from './scene';

const FORE = require('../../../assets/world/foreground-snow.png');

export type WorldInput = {
  checkpoint: CheckpointId;
  altitude: number;
  retreating: boolean;
  elapsedHours: number;
  weatherRisk: number;
  teamCondition: number;
  energy: number;
};

export function ExpeditionScene({ world, still = false }: { world: WorldInput; still?: boolean }) {
  const progress = routeProgress(world.altitude);
  const shift = useSharedValue(progress);
  const focus = useSharedValue(0);
  const terrain = terrainFor(world.checkpoint, world.altitude);
  const poses = partyPoses(world.teamCondition, world.energy);
  const phase = dayPhase(expeditionHour(world.elapsedHours));
  const facing = world.retreating || world.checkpoint === 'descent' ? 'left' : 'right';
  const kneeling = poses[1] === 'kneel';

  useEffect(() => {
    shift.value = withTiming(progress, { duration: still ? 600 : 1500 });
  }, [progress, shift, still]);

  useEffect(() => {
    focus.value = withTiming(kneeling ? 1 : 0, { duration: 800 });
  }, [focus, kneeling]);

  const camera = useAnimatedStyle(() => ({
    transform: [{ scale: 1 + focus.value * 0.05 }, { translateX: focus.value * -18 }],
  }));

  return (
    <View style={styles.scene} accessibilityLabel={partyLabel(poses)}>
      <Animated.View style={[styles.world, camera]}>
        <DayNightLayer phase={phase} />
        <ParallaxMountain shift={shift} />
        <CloudLayer still={still} storm={world.weatherRisk} />
        <EnvironmentTransition ground={groundFor(terrain.id)} shift={shift} />
        <Camp visible={campVisible(world.checkpoint)} shift={shift} />
        <RouteMarker shift={shift} />
        <WeatherLayer risk={world.weatherRisk} phase={phase} />
        <ExpeditionParty poses={poses} facing={facing} />
        {groundFor(terrain.id) === 'snow' ? (
          <Image source={FORE} style={styles.foreground} resizeMode="cover" accessibilityIgnoresInvertColors />
        ) : null}
        <SnowLayer density={still ? 0 : snowDensity(world.altitude, world.weatherRisk)} />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  scene: { flex: 1, overflow: 'hidden', backgroundColor: '#d5ddd6' },
  world: { flex: 1 },
  foreground: {
    position: 'absolute',
    left: '-10%',
    width: '124%',
    height: '18%',
    bottom: -4,
  },
});
