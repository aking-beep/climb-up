import { useEffect, useRef, useState } from 'react';
import { Image, StyleSheet, Text, View } from 'react-native';

import { Climber } from '@/components/game/Climber';
import { TERRAIN_HEIGHT, TERRAIN_WIDTH, terrainFor } from '@/expeditions/everest/terrain';
import type { TerrainId } from '@/expeditions/everest/terrain';
import type { CheckpointId } from '@/game/types';
import { font, spruceInk } from '@/theme';

const PLATES: Record<TerrainId, number> = {
  valley: require('../../../assets/terrain/valley.jpg'),
  forest: require('../../../assets/terrain/forest.jpg'),
  moraine: require('../../../assets/terrain/moraine.jpg'),
  icefall: require('../../../assets/terrain/icefall.jpg'),
  glacier: require('../../../assets/terrain/glacier.jpg'),
  face: require('../../../assets/terrain/face.jpg'),
  col: require('../../../assets/terrain/col.jpg'),
  ridge: require('../../../assets/terrain/ridge.jpg'),
};

type Props = {
  checkpoint: CheckpointId;
  altitude: number;
  retreating: boolean;
  nudge?: number;
  weatherRisk?: number;
  /** Hold the figure in place. Used on the title. */
  still?: boolean;
};

export function TerrainStage({
  checkpoint,
  altitude,
  retreating,
  nudge = 0,
  weatherRisk = 0,
  still = false,
}: Props) {
  const scene = terrainFor(checkpoint, altitude);
  const descending = retreating || checkpoint === 'descent';
  const placeKey = `${scene.id}:${descending ? 'down' : 'up'}:${Math.round(altitude / 80)}`;
  const [t, setT] = useState(still ? 0.62 : descending ? 0.78 : 0.14);
  const [step, setStep] = useState(0);
  const placeRef = useRef(placeKey);

  useEffect(() => {
    if (still) return;
    const from = descending ? 0.78 : 0.14;
    const to = descending ? 0.14 : 0.78;
    const start = Date.now();
    const duration = 1400;
    let frame = 0;
    const tick = () => {
      const u = Math.min(1, (Date.now() - start) / duration);
      const eased = 1 - (1 - u) ** 3;
      setT(from + (to - from) * eased);
      setStep(u < 1 ? Math.floor(u * 8) % 2 : 0);
      if (u < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [placeKey, descending, still]);

  useEffect(() => {
    const moved = placeRef.current !== placeKey;
    placeRef.current = placeKey;
    if (still || moved || nudge === 0) return;
    let count = 0;
    const id = setInterval(() => {
      count += 1;
      setStep(count % 2);
      if (count >= 4) {
        clearInterval(id);
        setStep(0);
      }
    }, 160);
    return () => clearInterval(id);
  }, [nudge, placeKey, still]);

  const foot = scene.foot(t);

  return (
    <View accessibilityLabel={`Climber on ${scene.label}`}>
      <View style={styles.frame}>
        <Image source={PLATES[scene.id]} style={styles.plate} resizeMode="cover" accessibilityIgnoresInvertColors />
        {weatherRisk >= 62 ? <View style={styles.weather} /> : null}
        <View
          style={[
            styles.walker,
            {
              left: `${(foot.x / TERRAIN_WIDTH) * 100}%`,
              top: `${(foot.y / TERRAIN_HEIGHT) * 100}%`,
            },
          ]}
        >
          <View style={styles.shadow} />
          <Climber step={step} facing={descending ? 'left' : 'right'} />
        </View>
      </View>
      <Text style={styles.label}>{scene.label}</Text>
      <Text style={styles.note}>Illustration, not a route</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    width: '100%',
    aspectRatio: 16 / 9,
    marginTop: 8,
    overflow: 'hidden',
    backgroundColor: '#cfc6b8',
  },
  plate: {
    ...StyleSheet.absoluteFill,
    width: '100%',
    height: '100%',
  },
  weather: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(232, 236, 238, 0.28)',
    pointerEvents: 'none',
  },
  walker: {
    position: 'absolute',
    alignItems: 'center',
    marginLeft: -37,
    marginTop: -124,
    pointerEvents: 'none',
  },
  shadow: {
    position: 'absolute',
    bottom: 1,
    width: 62,
    height: 12,
    borderRadius: 12,
    backgroundColor: 'rgba(28, 22, 16, 0.18)',
  },
  label: {
    marginTop: 8,
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    color: spruceInk,
  },
  note: {
    marginBottom: 4,
    fontFamily: font.body,
    fontSize: 11,
    color: spruceInk,
    opacity: 0.7,
  },
});
