import { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, View, type LayoutChangeEvent } from 'react-native';

import { PARTY, dayPhase, expeditionHour, snowDensity, type PartyId, type Pose } from '@/components/world/scene';
import { kiliCamping } from '@/expeditions/kilimanjaro/route';
import { kiliGround } from '@/expeditions/kilimanjaro/zones';
import { useSettings } from '@/game/session';
import type { CheckpointId } from '@/game/types';

import { coverFit, partyLayout } from './layout';
import { PLATES, zoneFor } from './plates';
import { WorldCanvas } from './WorldCanvas';

export type WorldSceneProps = {
  world: {
    checkpoint: CheckpointId;
    altitude: number;
    retreating: boolean;
    elapsedHours: number;
    weatherRisk: number;
    poses: readonly Pose[];
  };
  still: boolean;
  selected: PartyId | null;
  onSelectMember?: (id: PartyId) => void;
};

/**
 * A wall clock for the diorama's ambient motion (fog, fire, walking feet,
 * weather), at a modest frame rate: the strategy screen is mostly read, not
 * played. Frozen when the scene is still or motion is reduced.
 */
function useWorldClock(running: boolean, fps: number): number {
  const [time, setTime] = useState(0);
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    let start: number | null = null;
    let last = 0;
    const tick = (now: number) => {
      if (start === null) start = now;
      if (now - last >= 1000 / fps) {
        last = now;
        setTime(now - start);
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [running, fps]);
  return time;
}

export function WorldScene({ world, still, selected, onSelectMember }: WorldSceneProps) {
  const settings = useSettings();
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);
  const time = useWorldClock(!still && !settings.reducedMotion, settings.lowPower ? 15 : 30);

  const plate = PLATES[zoneFor(kiliGround(world.checkpoint, world.altitude))];
  const phase = dayPhase(expeditionHour(world.elapsedHours));
  const camping = kiliCamping(world.checkpoint, world.altitude) && !still;
  const retreating = world.retreating || world.checkpoint === 'descent';

  const party = useMemo(() => {
    if (!size) return [];
    const fit = coverFit(plate.meta, size.width, size.height);
    const order = PARTY.map((person, index) => ({ id: person.id, pose: world.poses[index] ?? 'walk' }));
    return partyLayout(plate.meta, fit, order, { camping, retreating });
  }, [size, plate.meta, world.poses, camping, retreating]);

  function measure(event: LayoutChangeEvent) {
    const { width, height } = event.nativeEvent.layout;
    if (!size || Math.abs(size.width - width) > 0.5 || Math.abs(size.height - height) > 0.5) setSize({ width, height });
  }

  return (
    <View style={styles.fill} onLayout={measure}>
      {size ? (
        <WorldCanvas
          plate={plate}
          width={size.width}
          height={size.height}
          phase={phase}
          weather={Math.min(1, world.weatherRisk / 80)}
          snow={snowDensity(world.altitude, world.weatherRisk)}
          camping={camping}
          party={party}
          selected={selected}
          checkpoint={world.checkpoint}
          timeMs={time}
          lowPower={settings.lowPower}
          showMap={!still}
        />
      ) : null}
      {onSelectMember
        ? party.map((member) => {
            const name = PARTY.find((person) => person.id === member.id)?.name ?? member.id;
            const w = Math.max(36, 32 * member.px);
            const h = Math.max(44, 40 * member.px);
            return (
              <Pressable
                key={member.id}
                accessibilityRole="button"
                accessibilityLabel={name}
                accessibilityState={{ selected: selected === member.id }}
                onPress={() => onSelectMember(member.id)}
                style={[styles.hit, { left: member.x - w / 2, top: member.y - h, width: w, height: h }]}
              />
            );
          })
        : null}
    </View>
  );
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
  hit: { position: 'absolute' },
});
