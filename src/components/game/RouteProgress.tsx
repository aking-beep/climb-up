import { StyleSheet, View } from 'react-native';

import { EVEREST_PROGRESS, checkpointName } from '@/expeditions/everest';
import type { CheckpointId } from '@/game/types';
import { spruceInk } from '@/theme';

export function RouteProgress({ checkpoint }: { checkpoint: CheckpointId }) {
  const index = Math.max(
    0,
    EVEREST_PROGRESS.findIndex((stop) => stop.id === checkpoint),
  );

  return (
    <View
      accessibilityRole="progressbar"
      accessibilityLabel={`${checkpointName(checkpoint)}, stage ${index + 1} of ${EVEREST_PROGRESS.length}`}
      accessibilityValue={{ min: 0, max: EVEREST_PROGRESS.length - 1, now: index }}
      style={styles.row}
    >
      {EVEREST_PROGRESS.map((stop, i) => (
        <View key={stop.id} style={[styles.tick, i <= index && styles.done, i === index && styles.now]} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 4,
  },
  tick: {
    flex: 1,
    height: 4,
    backgroundColor: 'rgba(244, 241, 234, 0.28)',
  },
  done: {
    backgroundColor: spruceInk,
  },
  now: {
    height: 10,
  },
});
