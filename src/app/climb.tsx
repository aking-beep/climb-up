import { router, useLocalSearchParams } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as Haptics from 'expo-haptics';
import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Results } from '@/components/game/Results';
import { Screen } from '@/components/ui/Screen';
import { EventSheet } from '@/components/world/EventSheet';
import { ExpeditionScene } from '@/components/world/ExpeditionScene';
import { Hud } from '@/components/world/Hud';
import { MemberSheet } from '@/components/world/MemberSheet';
import { PartyStrip } from '@/components/world/PartyStrip';
import type { PartyId } from '@/components/world/scene';
import { checkpointName, currentKilimanjaroEvent } from '@/expeditions/kilimanjaro';
import { kilimanjaroHybrid } from '@/expeditions/kilimanjaro/challenges';
import { membersOf, routineActions, routineEffect, tendEffect, type RoutineId } from '@/expeditions/kilimanjaro/party';
import { challengeFor } from '@/game/hybrid/coordinator';
import { gameStore, useGameSession } from '@/game/session';
import type { Effect, ExpeditionState, StatKey } from '@/game/types';
import { body, font, line, muted, paper, spruce, spruceInk } from '@/theme';
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
  const session = useGameSession();
  const [journalOpen, setJournalOpen] = useState(false);
  const [selected, setSelected] = useState<PartyId | null>(null);
  const choosing = useRef(false);
  const state = session?.state ?? null;

  // Arriving by link with no saved expedition: start the one in the link.
  useEffect(() => {
    if (!gameStore.get()) gameStore.start(parseSeed(code));
  }, [code]);

  useEffect(() => {
    choosing.current = false;
  }, [state]);

  if (!session || !state) return <Screen>{null}</Screen>;
  const expedition: ExpeditionState = state;
  const prior = session.prior;
  const pending = session.pending;

  function apply(effect: Effect | null) {
    if (choosing.current || !state || state.status !== 'active' || !effect) return;
    choosing.current = true;
    setJournalOpen(false);
    gameStore.play(effect);
    void Haptics.selectionAsync().catch(() => undefined);
  }

  function choose(index: number) {
    if (choosing.current || !state || state.status !== 'active') return;
    choosing.current = true;
    setJournalOpen(false);
    setSelected(null);
    const launched = gameStore.choose(index);
    void Haptics.selectionAsync().catch(() => undefined);
    if (launched) {
      choosing.current = false;
      router.push('/challenge');
      return;
    }
    const next = gameStore.get()?.state;
    if (next && next.status !== 'active') {
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
            setJournalOpen(false);
            setSelected(null);
            gameStore.start();
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
    const care = tendEffect(expedition, id);
    if (care) {
      const name = party.find((person) => person.id === id)?.name ?? 'them';
      return { label: `Sit with ${name}`, effect: care };
    }
    if (id === 'lena') {
      const effect = routineEffect(expedition, 'pole-pole');
      return effect ? { label: routine.find((action) => action.id === 'pole-pole')?.label ?? 'Pole pole', effect } : null;
    }
    if (id === 'jun') {
      const effect = routineEffect(expedition, 'head-count');
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
        {pending ? (
          <View style={[styles.pending, { paddingBottom: insets.bottom + 14 }]}>
            <Text style={styles.pendingKicker}>Playable climb · in progress</Text>
            <Text style={styles.pendingTitle}>The Barranco Wall is waiting</Text>
            <Text style={styles.pendingBody}>
              You chose to climb it. Nothing has been spent yet: the expedition moves on when the climb ends, once.
            </Text>
            <Pressable
              accessibilityRole="button"
              onPress={() => router.push('/challenge')}
              style={({ pressed }) => [styles.pendingGo, pressed && styles.pendingPressed]}
            >
              <Text style={styles.pendingGoText}>Return to the wall</Text>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              onPress={() => gameStore.abandon()}
              style={({ pressed }) => [styles.pendingBack, pressed && styles.pendingPressed]}
            >
              <Text style={styles.pendingBackText}>Back off and stay at Barranco</Text>
            </Pressable>
          </View>
        ) : member ? (
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
            playable={(index) => challengeFor(kilimanjaroHybrid, event, index) !== null}
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
  pending: { backgroundColor: paper, borderTopWidth: 1, borderTopColor: line, paddingHorizontal: 16, paddingTop: 14, gap: 8 },
  pendingKicker: { fontFamily: font.bodyMedium, fontSize: 11, letterSpacing: 1.1, textTransform: 'uppercase', color: muted },
  pendingTitle: { fontFamily: font.display, fontSize: 24, lineHeight: 28, color: body },
  pendingBody: { fontFamily: font.body, fontSize: 15, lineHeight: 21, color: body },
  pendingGo: { backgroundColor: spruce, minHeight: 52, justifyContent: 'center', paddingHorizontal: 14 },
  pendingGoText: { fontFamily: font.display, fontSize: 18, color: spruceInk },
  pendingBack: { minHeight: 48, justifyContent: 'center', paddingHorizontal: 14, borderWidth: 1, borderColor: line },
  pendingBackText: { fontFamily: font.display, fontSize: 16, color: body },
  pendingPressed: { opacity: 0.82 },
});
