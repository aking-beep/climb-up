import { LinearGradient } from 'expo-linear-gradient';
import { StyleSheet, Text, View } from 'react-native';

import { checkpointName, kiliCamping } from '@/expeditions/kilimanjaro';
import type { ExpeditionState } from '@/game/types';
import { font, spruceInk } from '@/theme';
import { formatElapsed, formatMeters } from '@/utils/number';

import { partyCaption, partyPoses } from './scene';

const READOUTS = [
  ['health', 'Health'],
  ['oxygen', 'Oxygen'],
  ['supplies', 'Supplies'],
  ['teamCondition', 'Team'],
] as const;

export function Hud({ state, top }: { state: ExpeditionState; top: number }) {
  const caption =
    partyCaption(partyPoses(state.teamCondition, state.energy)) ??
    (kiliCamping(state.checkpoint, state.altitude) ? 'The tents are up.' : null);
  return (
    <View style={styles.wrap}>
      <LinearGradient
        colors={['rgba(18,17,15,0.55)', 'rgba(18,17,15,0)']}
        style={styles.scrim}
      />
      <View style={[styles.row, { paddingTop: top }]}>
        <View style={styles.placeBlock}>
          <Text style={styles.kicker}>{state.retreating ? 'Descending' : 'Kilimanjaro · Lemosho'}</Text>
          <Text style={styles.place} accessibilityRole="header">
            {checkpointName(state.checkpoint)}
          </Text>
        </View>
        <View style={styles.when}>
          <Text style={styles.altitude}>{formatMeters(state.altitude)} m</Text>
          <Text style={styles.kicker}>{formatElapsed(state.elapsedHours)}</Text>
        </View>
      </View>
      <View style={styles.meters}>
        {READOUTS.map(([key, label]) => (
          <Text key={key} style={styles.meter}>
            {label} {state[key]}
          </Text>
        ))}
      </View>
      {caption ? <Text style={styles.caption}>{caption}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', top: 0, left: 0, right: 0, pointerEvents: 'none' },
  scrim: { position: 'absolute', top: 0, left: 0, right: 0, height: 128 },
  row: {
    paddingHorizontal: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  placeBlock: { flex: 1 },
  when: { alignItems: 'flex-end' },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 11,
    letterSpacing: 1,
    textTransform: 'uppercase',
    color: spruceInk,
  },
  place: {
    marginTop: 2,
    fontFamily: font.display,
    fontSize: 26,
    lineHeight: 30,
    color: spruceInk,
  },
  altitude: {
    fontFamily: font.display,
    fontSize: 18,
    color: spruceInk,
  },
  meters: {
    marginTop: 8,
    paddingHorizontal: 16,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  meter: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    color: spruceInk,
  },
  caption: {
    marginTop: 6,
    paddingHorizontal: 16,
    fontFamily: font.italic,
    fontSize: 14,
    color: spruceInk,
  },
});
