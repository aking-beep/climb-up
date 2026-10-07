import { useLocalSearchParams } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as Haptics from 'expo-haptics';
import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Instruments } from '@/components/game/Instruments';
import { Results } from '@/components/game/Results';
import { RouteProgress } from '@/components/game/RouteProgress';
import { TerrainStage } from '@/components/game/TerrainStage';
import { Screen } from '@/components/ui/Screen';
import {
  EVEREST_DISCLAIMER,
  EVEREST_PROGRESS,
  checkpointName,
  chooseEverest,
  currentEverestEvent,
  startEverest,
} from '@/expeditions/everest';
import type { ExpeditionState, StatKey } from '@/game/types';
import { body, font, line, muted, paper, paperRaised, spruce, spruceInk } from '@/theme';
import { formatElapsed, formatMeters, formatSeed, parseSeed } from '@/utils/number';

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
  const scrollRef = useRef<ScrollView>(null);
  const choosing = useRef(false);

  useEffect(() => {
    choosing.current = false;
    scrollRef.current?.scrollTo({ y: 0, animated: true });
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
  const stage = Math.max(0, EVEREST_PROGRESS.findIndex((stop) => stop.id === state.checkpoint));
  const delta = prior ? consequence(prior, state) : '';

  return (
    <Screen>
      <StatusBar style="light" />
      <ScrollView
        ref={scrollRef}
        style={styles.scroll}
        contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 28 }]}
        contentInsetAdjustmentBehavior="never"
        keyboardShouldPersistTaps="handled"
      >
        <View style={[styles.mast, { paddingTop: insets.top + 12 }]}>
          <View style={styles.mastRow}>
            <Text style={styles.kicker}>{state.retreating ? 'Descending' : 'Everest · South Col'}</Text>
            <Text style={styles.kicker}>{formatElapsed(state.elapsedHours)}</Text>
          </View>
          <Text
            style={styles.place}
            accessibilityRole="header"
            accessibilityLabel={`${checkpointName(state.checkpoint)}, ${formatMeters(state.altitude)} meters, ${formatElapsed(state.elapsedHours)}`}
          >
            {checkpointName(state.checkpoint)}
          </Text>
          <Text style={styles.altitude}>{formatMeters(state.altitude)} m</Text>
          <TerrainStage
            checkpoint={state.checkpoint}
            altitude={state.altitude}
            retreating={state.retreating}
            nudge={state.history.length}
            weatherRisk={state.weatherRisk}
          />
          <RouteProgress checkpoint={state.checkpoint} />
          <Text style={styles.code}>
            {stage + 1} / {EVEREST_PROGRESS.length} · Expedition {formatSeed(state.seed)}
          </Text>
        </View>

        <View style={styles.sheet}>
          <Instruments state={state} />

          {state.lastNote ? (
            <View style={styles.note} accessibilityLiveRegion="polite">
              <Text style={styles.noteKicker}>Field note</Text>
              <Text style={styles.noteText}>{state.lastNote}</Text>
              {delta ? <Text style={styles.delta}>{delta}</Text> : null}
            </View>
          ) : null}

          <View key={event.id} style={styles.event}>
            <Text style={styles.category}>{event.category.replace(/-/g, ' ')}</Text>
            <Text style={styles.eventTitle} accessibilityRole="header">
              {event.title}
            </Text>
            <Text style={styles.eventText}>{event.text}</Text>
            {event.review === 'sme' ? (
              <Text style={styles.review}>Guide review pending · not instruction</Text>
            ) : null}
          </View>

          <View style={styles.choices}>
            {event.choices.map((choice, index) => (
              <Pressable
                key={`${event.id}-${choice.label}`}
                accessibilityRole="button"
                accessibilityLabel={choice.label}
                accessibilityHint={choice.detail}
                onPress={() => choose(index)}
                style={({ pressed }) => [styles.choice, pressed && styles.pressed]}
              >
                <Text style={styles.choiceLabel}>{choice.label}</Text>
                <Text style={styles.choiceDetail}>{choice.detail}</Text>
              </Pressable>
            ))}
          </View>

          <Pressable
            accessibilityRole="button"
            accessibilityLabel={journalOpen ? 'Hide the journal' : 'Show the journal'}
            onPress={() => setJournalOpen((open) => !open)}
            style={styles.journalButton}
          >
            <Text style={styles.journalButtonText}>
              {journalOpen ? 'Hide the journal' : `Journal (${state.history.length})`}
            </Text>
          </Pressable>
          {journalOpen ? (
            <View style={styles.journal}>
              {state.history.length === 0 ? (
                <Text style={styles.journalLine}>Nothing written yet.</Text>
              ) : (
                state.history.map((entry, index) => (
                  <Text key={`${entry.hours}-${index}`} style={styles.journalLine}>
                    {checkpointName(entry.checkpoint)}. {entry.choice}
                  </Text>
                ))
              )}
            </View>
          ) : null}

          <Text style={styles.disclaimer}>{EVEREST_DISCLAIMER}</Text>
        </View>
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1, backgroundColor: paper },
  content: { flexGrow: 1 },
  mast: {
    backgroundColor: spruce,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  mastRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    color: spruceInk,
    opacity: 0.82,
  },
  place: {
    marginTop: 8,
    fontFamily: font.display,
    fontSize: 32,
    lineHeight: 36,
    color: spruceInk,
  },
  altitude: {
    marginTop: 2,
    fontFamily: font.body,
    fontSize: 16,
    color: spruceInk,
  },
  code: {
    marginTop: 8,
    fontFamily: font.body,
    fontSize: 12,
    letterSpacing: 0.3,
    color: spruceInk,
    opacity: 0.75,
  },
  sheet: {
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  note: {
    marginTop: 8,
    paddingVertical: 12,
    paddingHorizontal: 2,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  noteKicker: {
    fontFamily: font.bodyMedium,
    fontSize: 11,
    letterSpacing: 1,
    textTransform: 'uppercase',
    color: muted,
  },
  noteText: {
    marginTop: 6,
    fontFamily: font.italic,
    fontSize: 16,
    lineHeight: 22,
    color: body,
  },
  delta: {
    marginTop: 8,
    fontFamily: font.bodyMedium,
    fontSize: 13,
    lineHeight: 18,
    color: muted,
  },
  event: { marginTop: 16 },
  category: {
    fontFamily: font.bodyMedium,
    fontSize: 11,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    color: muted,
  },
  eventTitle: {
    marginTop: 4,
    fontFamily: font.display,
    fontSize: 28,
    lineHeight: 32,
    color: body,
  },
  eventText: {
    marginTop: 8,
    fontFamily: font.body,
    fontSize: 16,
    lineHeight: 23,
    color: body,
  },
  review: {
    marginTop: 8,
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.3,
    color: muted,
  },
  choices: { marginTop: 16, gap: 10 },
  choice: {
    backgroundColor: paperRaised,
    borderWidth: 1,
    borderColor: line,
    paddingHorizontal: 16,
    paddingVertical: 14,
    minHeight: 56,
    justifyContent: 'center',
  },
  pressed: { opacity: 0.82 },
  choiceLabel: {
    fontFamily: font.display,
    fontSize: 18,
    lineHeight: 23,
    color: body,
  },
  choiceDetail: {
    marginTop: 4,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 19,
    color: muted,
  },
  journalButton: {
    marginTop: 8,
    minHeight: 44,
    justifyContent: 'center',
  },
  journalButtonText: {
    fontFamily: font.bodyMedium,
    fontSize: 14,
    color: muted,
  },
  journal: { gap: 10, paddingBottom: 8 },
  journalLine: {
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 20,
    color: body,
  },
  disclaimer: {
    marginTop: 12,
    fontFamily: font.body,
    fontSize: 12,
    lineHeight: 17,
    color: muted,
  },
});
