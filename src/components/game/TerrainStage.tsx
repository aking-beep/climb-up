import { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Svg, { Path, Polygon } from 'react-native-svg';

import { Climber } from '@/components/game/Climber';
import {
  TERRAIN_HEIGHT,
  TERRAIN_WIDTH,
  groundPath,
  terrainFor,
} from '@/expeditions/everest/terrain';
import type { TerrainId } from '@/expeditions/everest/terrain';
import type { CheckpointId } from '@/game/types';
import { font, spruceInk } from '@/theme';

const CREAM = 'rgba(244, 241, 234, 0.82)';
const FAINT = 'rgba(244, 241, 234, 0.28)';
const ICE = 'rgba(244, 241, 234, 0.42)';
const ROCK = 'rgba(8, 12, 10, 0.38)';
const TREE = 'rgba(8, 14, 12, 0.62)';

type Props = {
  checkpoint: CheckpointId;
  altitude: number;
  retreating: boolean;
  nudge?: number;
  weatherRisk?: number;
};

export function TerrainStage({ checkpoint, altitude, retreating, nudge = 0, weatherRisk = 0 }: Props) {
  const scene = terrainFor(checkpoint, altitude);
  const descending = retreating || checkpoint === 'descent';
  const placeKey = `${scene.id}:${descending ? 'down' : 'up'}:${Math.round(altitude / 80)}`;
  const [t, setT] = useState(descending ? 0.9 : 0.1);
  const [step, setStep] = useState(0);
  const placeRef = useRef(placeKey);

  useEffect(() => {
    const from = descending ? 0.9 : 0.1;
    const to = descending ? 0.1 : 0.9;
    const start = Date.now();
    const duration = 1200;
    let frame = 0;
    const tick = () => {
      const u = Math.min(1, (Date.now() - start) / duration);
      const eased = 1 - (1 - u) ** 3;
      setT(from + (to - from) * eased);
      setStep(u < 1 ? Math.floor(u * 10) % 2 : 0);
      if (u < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [placeKey, descending]);

  useEffect(() => {
    const moved = placeRef.current !== placeKey;
    placeRef.current = placeKey;
    if (moved || nudge === 0) return;
    let count = 0;
    const id = setInterval(() => {
      count += 1;
      setStep(count % 2);
      if (count >= 4) {
        clearInterval(id);
        setStep(0);
      }
    }, 150);
    return () => clearInterval(id);
  }, [nudge, placeKey]);

  const foot = scene.foot(t);
  const windy = weatherRisk >= 55 || scene.id === 'col' || scene.id === 'ridge';

  return (
    <View accessibilityLabel={`Climber on ${scene.label}`}>
      <View style={styles.stage}>
        <Svg width="100%" height="100%" viewBox={`0 0 ${TERRAIN_WIDTH} ${TERRAIN_HEIGHT}`}>
          <TerrainArt id={scene.id} />
          {windy ? <Wind /> : null}
          <Path d={groundPath(scene)} fill="rgba(244, 241, 234, 0.14)" stroke={CREAM} strokeWidth={1.6} />
        </Svg>
        <View
          pointerEvents="none"
          style={[
            styles.figure,
            {
              left: `${(foot.x / TERRAIN_WIDTH) * 100}%`,
              top: `${(foot.y / TERRAIN_HEIGHT) * 100}%`,
            },
          ]}
        >
          <Climber step={step} facing={descending ? 'left' : 'right'} />
        </View>
      </View>
      <Text style={styles.label}>{scene.label}</Text>
      <Text style={styles.sketch}>Sketch, not a route</Text>
    </View>
  );
}

function Wind() {
  return (
    <>
      <Path d="M18 28 H92" stroke={FAINT} strokeWidth={1} />
      <Path d="M40 40 H130" stroke={FAINT} strokeWidth={1} />
      <Path d="M210 24 H330" stroke={FAINT} strokeWidth={1} />
      <Path d="M240 38 H348" stroke={FAINT} strokeWidth={1} />
    </>
  );
}

function Tree({ x, y, h }: { x: number; y: number; h: number }) {
  return <Polygon points={`${x},${y} ${x - h * 0.42},${y + h} ${x + h * 0.42},${y + h}`} fill={TREE} />;
}

function TerrainArt({ id }: { id: TerrainId }) {
  if (id === 'valley') {
    return (
      <>
        <Path d="M0 96 C 70 78, 140 100, 210 84 S 320 96, 360 72 V168 H0 Z" fill="rgba(244,241,234,0.08)" />
        <Tree x={54} y={78} h={36} />
        <Tree x={92} y={86} h={28} />
        <Tree x={250} y={90} h={24} />
      </>
    );
  }
  if (id === 'forest') {
    return (
      <>
        <Tree x={36} y={70} h={48} />
        <Tree x={70} y={78} h={40} />
        <Tree x={108} y={62} h={52} />
        <Tree x={148} y={74} h={36} />
        <Tree x={292} y={48} h={30} />
        <Tree x={328} y={40} h={26} />
      </>
    );
  }
  if (id === 'moraine') {
    return (
      <>
        <Path d="M0 70 L80 48 L160 78 L250 36 L360 64 V120 H0 Z" fill={ICE} />
        <Polygon points="40,120 62,96 86,120" fill={ROCK} />
        <Polygon points="120,124 148,92 176,124" fill={ROCK} />
        <Polygon points="250,118 268,100 286,118" fill={ROCK} />
        <Polygon points="200,108 214,90 228,108" fill="rgba(244,241,234,0.7)" />
        <Polygon points="232,112 244,96 256,112" fill="rgba(244,241,234,0.7)" />
      </>
    );
  }
  if (id === 'icefall') {
    return (
      <>
        <Polygon points="18,118 48,72 78,118" fill={ICE} />
        <Polygon points="88,124 128,64 168,124" fill={ICE} />
        <Polygon points="176,110 214,58 252,110" fill="rgba(244,241,234,0.55)" />
        <Polygon points="260,100 300,46 340,100" fill={ICE} />
        <Path d="M96 96 L112 108 L104 118" stroke={ROCK} strokeWidth={2} fill="none" />
      </>
    );
  }
  if (id === 'glacier') {
    return (
      <>
        <Path d="M0 36 L70 88 L0 168 Z" fill="rgba(244,241,234,0.16)" />
        <Path d="M360 28 L280 92 L360 168 Z" fill="rgba(244,241,234,0.16)" />
        <Path d="M120 128 L150 146" stroke={ROCK} strokeWidth={1.5} />
        <Path d="M200 132 L236 150" stroke={ROCK} strokeWidth={1.5} />
      </>
    );
  }
  if (id === 'face') {
    return (
      <>
        <Path d="M0 40 L360 8 V168 H0 Z" fill="rgba(244,241,234,0.08)" />
        <Path d="M70 120 L96 104" stroke={ROCK} strokeWidth={2} />
        <Path d="M180 88 L210 70" stroke={ROCK} strokeWidth={2} />
        <Path d="M280 58 L304 44" stroke={ROCK} strokeWidth={2} />
      </>
    );
  }
  if (id === 'col') {
    return (
      <>
        <Path d="M0 20 L90 78 L150 40 L220 96 L300 28 L360 16 V168 H0 Z" fill="rgba(244,241,234,0.1)" />
      </>
    );
  }
  return (
    <>
      <Path d="M0 150 L168 36 L214 18 L250 48 L360 150 Z" fill="rgba(244,241,234,0.12)" />
      <Path d="M214 18 L250 8 L286 40" stroke={CREAM} strokeWidth={1.2} fill="none" />
    </>
  );
}

const styles = StyleSheet.create({
  stage: {
    height: 176,
    width: '100%',
    marginTop: 6,
  },
  figure: {
    position: 'absolute',
    marginLeft: -24,
    marginTop: -54,
  },
  label: {
    marginTop: 2,
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    color: spruceInk,
  },
  sketch: {
    marginBottom: 8,
    fontFamily: font.body,
    fontSize: 11,
    color: spruceInk,
    opacity: 0.62,
  },
});
