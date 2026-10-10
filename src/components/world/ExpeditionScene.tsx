import { useEffect } from 'react';
import { Image, StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { terrainFor } from '@/expeditions/everest/terrain';
import { KILI_GATE, KILI_SUMMIT, kiliCamping } from '@/expeditions/kilimanjaro/route';
import { kiliGround } from '@/expeditions/kilimanjaro/zones';
import { WorldHost } from '@/features/world/WorldHost';
import type { CheckpointId } from '@/game/types';

import { DioramaCamp } from './DioramaCamp';
import { DioramaParty } from './DioramaParty';
import { SnowLayer } from './SnowLayer';
import { TiltShift } from './TiltShift';
import { dayPhase, expeditionHour, groundFor, partyLabel, partyPoses, routeProgress, snowDensity, type GroundId, type PartyId, type Pose } from './scene';

const PLATES: Record<GroundId, number> = {
  valley: require('../../../assets/world/diorama-valley.jpg'),
  forest: require('../../../assets/world/diorama-forest.jpg'),
  rock: require('../../../assets/world/diorama-rock.jpg'),
  snow: require('../../../assets/world/diorama-snow.jpg'),
  rainforest: require('../../../assets/world/diorama-rainforest.jpg'),
  moorland: require('../../../assets/world/diorama-moorland.jpg'),
  desert: require('../../../assets/world/diorama-desert.jpg'),
};

export type WorldInput = {
  checkpoint: CheckpointId;
  altitude: number;
  retreating: boolean;
  elapsedHours: number;
  weatherRisk: number;
  teamCondition: number;
  energy: number;
  /** The first mountain is Kilimanjaro. Everest keeps the older plates. */
  mountain?: 'kilimanjaro' | 'everest';
  poses?: readonly Pose[];
};

type SceneProps = {
  world: WorldInput;
  still?: boolean;
  selected?: PartyId | null;
  onSelectMember?: (id: PartyId) => void;
};

/**
 * Kilimanjaro is drawn as an HD-2D diorama (src/features/world): a lit
 * three-quarter plate per zone, the party walking the trail, fog, weather,
 * camp light, and the route map. The flat painted plate below is the
 * fallback while the renderer loads or where Skia is missing, and Everest's
 * scene.
 */
export function ExpeditionScene(props: SceneProps) {
  const { world, still = false, selected = null, onSelectMember } = props;
  if (world.mountain === 'everest') return <FlatScene {...props} />;
  return (
    <View style={styles.scene}>
      <WorldHost
        world={{
          checkpoint: world.checkpoint,
          altitude: world.altitude,
          retreating: world.retreating,
          elapsedHours: world.elapsedHours,
          weatherRisk: world.weatherRisk,
          poses: world.poses ?? partyPoses(world.teamCondition, world.energy),
        }}
        still={still}
        selected={selected}
        onSelectMember={still ? undefined : onSelectMember}
        fallback={<FlatScene {...props} />}
      />
    </View>
  );
}

function FlatScene({ world, still = false, selected = null, onSelectMember }: SceneProps) {
  const kilimanjaro = world.mountain !== 'everest';
  const progress = kilimanjaro ? routeProgress(world.altitude, KILI_GATE, KILI_SUMMIT) : routeProgress(world.altitude);
  const shift = useSharedValue(progress);
  const focus = useSharedValue(0);
  const terrain = terrainFor(world.checkpoint, world.altitude);
  const poses = world.poses ?? partyPoses(world.teamCondition, world.energy);
  const phase = dayPhase(expeditionHour(world.elapsedHours));
  const retreating = world.retreating || world.checkpoint === 'descent';
  const kneeling = poses[1] === 'kneel';
  const ground = kilimanjaro ? kiliGround(world.checkpoint, world.altitude) : groundFor(terrain.id);
  const camping = kilimanjaro && kiliCamping(world.checkpoint, world.altitude);

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
        <Image source={PLATES[ground]} style={styles.plate} resizeMode="cover" accessibilityIgnoresInvertColors />
        <DioramaCamp visible={camping && !still} />
        <DioramaParty
          poses={poses}
          retreating={retreating}
          progress={progress}
          camping={camping}
          selected={selected}
          onSelect={still ? undefined : onSelectMember}
        />
        <SnowLayer density={still ? 0 : snowDensity(world.altitude, world.weatherRisk)} />
        <TiltShift phase={phase} storm={world.weatherRisk} />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  scene: { flex: 1, overflow: 'hidden', backgroundColor: '#1a1612' },
  world: { flex: 1 },
  plate: { width: '100%', height: '100%' },
});
