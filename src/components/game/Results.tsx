import { router } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ExpeditionScene } from '@/components/world/ExpeditionScene';
import { KILI_DISCLAIMER, scoreKilimanjaro } from '@/expeditions/kilimanjaro';
import type { ExpeditionState } from '@/game/types';
import { body, danger, font, line, muted, paper, spruce, spruceInk } from '@/theme';
import { formatMeters, formatSeed } from '@/utils/number';

export function Results({ state, onAgain }: { state: ExpeditionState; onAgain: () => void }) {
  const insets = useSafeAreaInsets();
  const score = scoreKilimanjaro(state);
  const title = score.returnedSafely ? 'Expedition complete' : 'Expedition ended';
  const verdict = verdictLine(score.summitReached, score.returnedSafely);

  const facts: readonly (readonly [string, string])[] = [
    ['Highest altitude', `${formatMeters(score.highestAltitude)} m`],
    ['Summit reached', score.summitReached ? 'Yes' : 'No'],
    ['Returned safely', score.returnedSafely ? 'Yes' : 'No'],
  ];
  const parts: readonly (readonly [string, number])[] = [
    ['Judgment', score.judgment],
    ['Risk management', score.riskManagement],
    ['Teamwork', score.teamwork],
    ['Preparation', score.preparation],
  ];

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 28 }]}
      contentInsetAdjustmentBehavior="never"
    >
      <View style={[styles.mast, { paddingTop: insets.top + 18 }]}>
        <Text style={styles.kicker}>Kilimanjaro · {formatSeed(state.seed)}</Text>
        <Text style={styles.title} accessibilityRole="header">
          {title}
        </Text>
        <Text style={styles.verdict}>{verdict}</Text>
        <View style={styles.world}>
          <ExpeditionScene
            world={{
              checkpoint: state.returnedSafely ? 'complete' : state.checkpoint,
              altitude: state.altitude,
              retreating: state.returnedSafely || state.retreating,
              elapsedHours: state.elapsedHours,
              weatherRisk: state.weatherRisk,
              teamCondition: state.teamCondition,
              energy: state.energy,
            }}
          />
        </View>
      </View>

      <View style={styles.sheet}>
        {facts.map(([label, value]) => (
          <View key={label} style={styles.fact}>
            <Text style={styles.factLabel}>{label}</Text>
            <Text style={styles.factValue}>{value}</Text>
          </View>
        ))}

        <View style={styles.scores}>
          {parts.map(([label, value]) => (
            <View key={label} style={styles.scoreRow}>
              <Text style={styles.scoreLabel}>{label}</Text>
              <Text style={styles.scoreValue}>{value}</Text>
            </View>
          ))}
          <View style={styles.overallRow}>
            <Text style={styles.overallLabel}>Overall expedition score</Text>
            <Text style={styles.overallValue}>{score.overall}</Text>
          </View>
        </View>

        {!score.returnedSafely ? (
          <Text style={styles.unsuccessful}>A summit without a safe return is not a successful expedition.</Text>
        ) : null}

        <Text style={styles.explanation}>{score.explanation}</Text>

        <View style={styles.notice}>
          <Text style={styles.noticeText}>{KILI_DISCLAIMER}</Text>
        </View>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Another expedition"
          onPress={onAgain}
          style={({ pressed }) => [styles.go, pressed && styles.pressed]}
        >
          <Text style={styles.goText}>Another expedition</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Back to the briefing"
          onPress={() => router.replace('/')}
          style={styles.textButton}
        >
          <Text style={styles.textButtonLabel}>Back to the briefing</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

function verdictLine(summit: boolean, returned: boolean): string {
  if (summit && returned) return 'You went to the top and brought the expedition down.';
  if (returned) return 'You came back. The summit was not the score.';
  if (summit) return 'The summit is recorded. The expedition did not come back.';
  return 'The expedition ended on the mountain.';
}

const styles = StyleSheet.create({
  scroll: { flex: 1, backgroundColor: paper },
  content: { flexGrow: 1 },
  mast: {
    backgroundColor: spruce,
    paddingHorizontal: 22,
    paddingBottom: 22,
  },
  world: { height: 200, marginTop: 12 },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
    color: spruceInk,
    opacity: 0.8,
  },
  title: {
    marginTop: 8,
    fontFamily: font.displayBold,
    fontSize: 36,
    lineHeight: 40,
    color: spruceInk,
  },
  verdict: {
    marginTop: 10,
    fontFamily: font.italic,
    fontSize: 18,
    lineHeight: 24,
    color: spruceInk,
  },
  sheet: {
    paddingHorizontal: 22,
    paddingTop: 8,
  },
  fact: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: line,
  },
  factLabel: {
    fontFamily: font.body,
    fontSize: 16,
    color: muted,
  },
  factValue: {
    fontFamily: font.bodySemi,
    fontSize: 16,
    color: body,
  },
  scores: {
    marginTop: 18,
  },
  scoreRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    paddingVertical: 7,
  },
  scoreLabel: {
    fontFamily: font.body,
    fontSize: 16,
    color: body,
  },
  scoreValue: {
    fontFamily: font.display,
    fontSize: 22,
    color: body,
  },
  overallRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    marginTop: 8,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  overallLabel: {
    flex: 1,
    fontFamily: font.display,
    fontSize: 18,
    lineHeight: 24,
    color: body,
    paddingRight: 12,
  },
  overallValue: {
    fontFamily: font.displayBold,
    fontSize: 40,
    lineHeight: 44,
    color: body,
  },
  unsuccessful: {
    marginTop: 16,
    fontFamily: font.bodyMedium,
    fontSize: 15,
    lineHeight: 21,
    color: danger,
  },
  explanation: {
    marginTop: 16,
    fontFamily: font.body,
    fontSize: 16,
    lineHeight: 23,
    color: body,
  },
  notice: {
    marginTop: 18,
    paddingTop: 14,
    borderTopWidth: 1,
    borderTopColor: line,
  },
  noticeText: {
    fontFamily: font.body,
    fontSize: 13,
    lineHeight: 19,
    color: muted,
  },
  go: {
    marginTop: 22,
    backgroundColor: spruce,
    minHeight: 56,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  pressed: { opacity: 0.84 },
  goText: {
    fontFamily: font.display,
    fontSize: 20,
    color: spruceInk,
  },
  textButton: {
    minHeight: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  textButtonLabel: {
    fontFamily: font.bodyMedium,
    fontSize: 15,
    color: muted,
  },
});
