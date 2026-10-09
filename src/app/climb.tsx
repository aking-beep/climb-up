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
import { MemberSheet } from '@/components/world/MemberSheet';
import { PartyStrip } from '@/components/world/PartyStrip';
import type { PartyId } from '@/components/world/scene';
import {
  checkpointName,
  chooseKilimanjaro,
  currentKilimanjaroEvent,
  playKilimanjaro,
  startKilimanjaro,
} from '@/expeditions/kilimanjaro';
import { membersOf, routineActions, routineEffect, tendEffect, type RoutineId } from '@/expeditions/kilimanjaro/party';
import type { Effect, ExpeditionState, StatKey } from '@/game/types';
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
  const [state, setState] = useState(() => startKilimanjaro(parseSeed(code)));
  const [prior, setPrior] = useState<ExpeditionState | null>(null);
  const [journalOpen, setJournalOpen] = useState(false);
  const [selected, setSelected] = useState<PartyId | null>(null);
  const choosing = useRef(false);

  useEffect(() => {
    choosing.current = false;
  }, [state]);

  function apply(effect: Effect | null) {
    if (choosing.current || state.status !== 'active' || !effect) return;
    choosing.current = true;
    setPrior(state);
    setJournalOpen(false);
    setState(playKilimanjaro(state, effect));
    void Haptics.selectionAsync().catch(() => undefined);
  }

  function choose(index: number) {
    if (choosing.current || state.status !== 'active') return;
    choosing.current = true;
    setPrior(state);
    setJournalOpen(false);
    setSelected(null);
    const next = chooseKilimanjaro(state, index);
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
            setSelected(null);
            setState(startKilimanjaro());
          }}
        />
      </Screen>
    );
  }

  const event = currentKilimanjaroEvent(state);
  const delta = prior ? consequence(prior, state) : '';
  const party = membersOf(state);
  const member = party.find((person) => person.id === selected) ?? null;
  const routine = routineActions(state);

  function select(id: PartyId) {
    setSelected((current) => (current === id ? null : id));
  }

  function memberAction(id: PartyId): { label: string; effect: Effect } | null {
    const care = tendEffect(state, id);
    if (care) {
      const name = party.find((person) => person.id === id)?.name ?? 'them';
      return { label: `Sit with ${name}`, effect: care };
    }
    if (id === 'lena') {
      const effect = routineEffect(state, 'pole-pole');
      return effect ? { label: routine.find((action) => action.id === 'pole-pole')?.label ?? 'Pole pole', effect } : null;
    }
    if (id === 'jun') {
      const effect = routineEffect(state, 'head-count');
      return effect ? { label: routine.find((action) => action.id === 'head-count')?.label ?? 'Head count', effect } : null;
    }
    return null;
  }

  const personal = member ? memberAction(member.id) : null;

  return (
    <Screen>
      <StatusBar style="light" />
      <View style={styles.play}>
        <View
          style={styles.world}
          accessibilityLabel={`${checkpointName(state.checkpoint)}, ${formatMeters(state.altitude)} meters, ${formatElapsed(state.elapsedHours)}`}
        >
          <ExpeditionScene
            selected={selected}
            onSelectMember={select}
            world={{
              checkpoint: state.checkpoint,
              altitude: state.altitude,
              retreating: state.retreating,
              elapsedHours: state.elapsedHours,
              weatherRisk: state.weatherRisk,
              teamCondition: state.teamCondition,
              energy: state.energy,
              poses: party.map((person) => person.pose),
            }}
          />
          <Hud state={state} top={insets.top + 10} />
        </View>
        <PartyStrip members={party} selected={selected} onSelect={select} />
        {member ? (
          <MemberSheet
            member={member}
            actionLabel={personal?.label ?? null}
            onAction={() => apply(personal?.effect ?? null)}
            onClose={() => setSelected(null)}
            bottom={insets.bottom + 10}
          />
        ) : (
          <EventSheet
            state={state}
            event={event}
            delta={delta}
            history={state.history}
            journalOpen={journalOpen}
            onToggleJournal={() => setJournalOpen((open) => !open)}
            onChoose={choose}
            routine={routine}
            onRoutine={(id: RoutineId) => apply(routineEffect(state, id))}
            bottom={insets.bottom + 10}
          />
        )}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  play: { flex: 1, backgroundColor: paper },
  world: { flex: 1 },
});
