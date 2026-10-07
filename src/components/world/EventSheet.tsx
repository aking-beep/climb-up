import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Animated, { FadeInDown } from 'react-native-reanimated';

import { Instruments } from '@/components/game/Instruments';
import { EVEREST_DISCLAIMER, checkpointName } from '@/expeditions/everest';
import type { EventCard, ExpeditionState, HistoryEntry } from '@/game/types';
import { body, font, line, muted, paper, paperRaised } from '@/theme';

type Props = {
  state: ExpeditionState;
  event: EventCard;
  delta: string;
  history: readonly HistoryEntry[];
  journalOpen: boolean;
  onToggleJournal: () => void;
  onChoose: (index: number) => void;
  bottom: number;
};

export function EventSheet({
  state,
  event,
  delta,
  history,
  journalOpen,
  onToggleJournal,
  onChoose,
  bottom,
}: Props) {
  const [storesOpen, setStoresOpen] = useState(false);

  return (
    <View style={[styles.sheet, { paddingBottom: bottom }]}>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <Animated.View key={event.id} entering={FadeInDown.duration(420)}>
          {state.lastNote ? (
            <View style={styles.note}>
              <Text style={styles.kicker}>Field note</Text>
              <Text style={styles.noteText}>{state.lastNote}</Text>
              {delta ? <Text style={styles.delta}>{delta}</Text> : null}
            </View>
          ) : null}
          <Text style={styles.kicker}>{event.category.replace(/-/g, ' ')}</Text>
          <Text style={styles.title} accessibilityRole="header">
            {event.title}
          </Text>
          <Text style={styles.body}>{event.text}</Text>
          {event.review === 'sme' ? (
            <Text style={styles.review}>Guide review pending · not instruction</Text>
          ) : null}
          <View style={styles.choices}>
            {event.choices.map((choice, index) => (
              <Pressable
                key={`${event.id}-${choice.label}`}
                accessibilityRole="button"
                accessibilityLabel={choice.label}
                accessibilityHint={choice.detail}
                onPress={() => onChoose(index)}
                style={({ pressed }) => [styles.choice, pressed && styles.pressed]}
              >
                <Text style={styles.choiceLabel}>{choice.label}</Text>
                <Text style={styles.choiceDetail}>{choice.detail}</Text>
              </Pressable>
            ))}
          </View>
        </Animated.View>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={storesOpen ? 'Hide team and stores' : 'Show team and stores'}
          onPress={() => setStoresOpen((open) => !open)}
          style={styles.textButton}
        >
          <Text style={styles.textButtonLabel}>{storesOpen ? 'Hide team and stores' : 'Team and stores'}</Text>
        </Pressable>
        {storesOpen ? <Instruments state={state} /> : null}

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={journalOpen ? 'Hide the journal' : 'Show the journal'}
          onPress={onToggleJournal}
          style={styles.textButton}
        >
          <Text style={styles.textButtonLabel}>
            {journalOpen ? 'Hide the journal' : `Journal (${history.length})`}
          </Text>
        </Pressable>
        {journalOpen ? (
          <View style={styles.journal}>
            {history.length === 0 ? (
              <Text style={styles.journalLine}>Nothing written yet.</Text>
            ) : (
              history.map((entry, index) => (
                <Text key={`${entry.hours}-${index}`} style={styles.journalLine}>
                  {checkpointName(entry.checkpoint)}. {entry.choice}
                </Text>
              ))
            )}
          </View>
        ) : null}
        <Text style={styles.disclaimer}>{EVEREST_DISCLAIMER}</Text>
        <Text style={styles.sketch}>Illustration, not a route</Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: {
    maxHeight: '54%',
    backgroundColor: paper,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  content: { paddingHorizontal: 16, paddingTop: 14, paddingBottom: 8 },
  note: { marginBottom: 12 },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 11,
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    color: muted,
  },
  noteText: {
    marginTop: 4,
    fontFamily: font.italic,
    fontSize: 16,
    lineHeight: 22,
    color: body,
  },
  delta: {
    marginTop: 6,
    fontFamily: font.bodyMedium,
    fontSize: 13,
    lineHeight: 18,
    color: muted,
  },
  title: {
    marginTop: 4,
    fontFamily: font.display,
    fontSize: 26,
    lineHeight: 30,
    color: body,
  },
  body: {
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
    color: muted,
  },
  choices: { marginTop: 14, gap: 10 },
  choice: {
    backgroundColor: paperRaised,
    borderWidth: 1,
    borderColor: line,
    paddingHorizontal: 14,
    paddingVertical: 12,
    minHeight: 56,
    justifyContent: 'center',
  },
  pressed: { opacity: 0.82 },
  choiceLabel: {
    fontFamily: font.display,
    fontSize: 17,
    lineHeight: 22,
    color: body,
  },
  choiceDetail: {
    marginTop: 3,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 19,
    color: muted,
  },
  textButton: { minHeight: 44, justifyContent: 'center' },
  textButtonLabel: {
    fontFamily: font.bodyMedium,
    fontSize: 14,
    color: muted,
  },
  journal: { gap: 8, paddingBottom: 8 },
  journalLine: {
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 20,
    color: body,
  },
  disclaimer: {
    marginTop: 4,
    fontFamily: font.body,
    fontSize: 12,
    lineHeight: 17,
    color: muted,
  },
  sketch: {
    marginTop: 4,
    fontFamily: font.body,
    fontSize: 11,
    color: muted,
  },
});
