import { useLocalSearchParams } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as Haptics from 'expo-haptics';
import { useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Results } from '@/components/game/Results';
import { Screen } from '@/components/ui/Screen';
import { EventSheet } from '@/components/world/EventSheet';
import { ExpeditionScene } from '@/components/world/ExpeditionScene';
import { Hud } from '@/components/world/Hud';
import {
  checkpointName,
  chooseEverest,
  currentEverestEvent,
  startEverest,
} from '@/expeditions/everest';
import type { ExpeditionState, StatKey } from '@/game/types';
import { paper } from '@/theme';
import { formatElapsed, formatMeters, parseSeed } from '@/utils/number';

const DELTAS: readonly (readonly [StatKey, string])[] = [
  ['health', 'Health'],
  ['energy', 'Energy'],
  ['acclimatization', 'Acclimatization'],
  ['oxygen', 'Oxygen'],
  ['supplies', 'Supplies'],
  ['weatherRisk', 'Weather'],
  ['objectiveRisk', 'Objective'],
  ['teamCondition', 'Team'],
];

function readCode(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function consequence(before: ExpeditionState, after: ExpeditionState): string {
  const parts: string[] = [];
  if (before.checkpoint !== after.checkpoint || before.altitude !== after.altitude) {
    parts.push(`${checkpointName(after.checkpoint)} · ${formatMeters(after.altitude)} m`);
  }
  for (const [key, label] of DELTAS) {
    if (before[key] !== after[key]) parts.push(`${label} ${before[key]} → ${after[key]}`);
  }
  return parts.join('   ');
}

export default function ClimbScreen() {
  const params = useLocalSearchParams<{ code?: string | string[] }>();
  const code = readCode(params.code);
  const insets = useSafeAreaInsets();
  const [state, setState] = useState(() => startEverest(parseSeed(code)));
  const [prior, setPrior] = useState<ExpeditionState | null>(null);
  const [journalOpen, setJournalOpen] = useState(false);
  const choosing = useRef(false);

  useEffect(() => {
    choosing.current = false;
  }, [state]);

  function choose(index: number) {
    if (choosing.current || state.status !== 'active') return;
    choosing.current = true;
    setPrior(state);
    setJournalOpen(false);
    const next = chooseEverest(state, index);
    setState(next);
    void Haptics.selectionAsync().catch(() => undefined);
    if (next.status !== 'active') {
      void Haptics.notificationAsync(
        next.returnedSafely
          ? Haptics.NotificationFeedbackType.Success
          : Haptics.NotificationFeedbackType.Warning,
      ).catch(() => undefined);
    }
  }

  if (state.status !== 'active') {
    return (
      <Screen>
        <StatusBar style="light" />
        <Results
          state={state}
          onAgain={() => {
            setPrior(null);
            setJournalOpen(false);
            setState(startEverest());
          }}
        />
      </Screen>
    );
  }

  const event = currentEverestEvent(state);
  const delta = prior ? consequence(prior, state) : '';

  return (
    <Screen>
      <StatusBar style="light" />
      <View style={styles.play}>
        <View
          style={styles.world}
          accessibilityLabel={`${checkpointName(state.checkpoint)}, ${formatMeters(state.altitude)} meters, ${formatElapsed(state.elapsedHours)}`}
        >
          <ExpeditionScene
            world={{
              checkpoint: state.checkpoint,
              altitude: state.altitude,
              retreating: state.retreating,
              elapsedHours: state.elapsedHours,
              weatherRisk: state.weatherRisk,
              teamCondition: state.teamCondition,
              energy: state.energy,
            }}
          />
          <Hud state={state} top={insets.top + 10} />
        </View>
        <EventSheet
          state={state}
          event={event}
          delta={delta}
          history={state.history}
          journalOpen={journalOpen}
          onToggleJournal={() => setJournalOpen((open) => !open)}
          onChoose={choose}
          bottom={insets.bottom + 10}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  play: { flex: 1, backgroundColor: paper },
  world: { flex: 1 },
});
