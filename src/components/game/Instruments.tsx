import { StyleSheet, Text, View } from 'react-native';

import type { ExpeditionState, StatKey } from '@/game/types';
import { body, danger, font, line, muted, spruce } from '@/theme';

type Kind = 'benefit' | 'risk' | 'acclim';

const METERS: readonly { key: StatKey; label: string; kind: Kind }[] = [
  { key: 'health', label: 'Health', kind: 'benefit' },
  { key: 'energy', label: 'Energy', kind: 'benefit' },
  { key: 'acclimatization', label: 'Acclimatization', kind: 'acclim' },
  { key: 'oxygen', label: 'Oxygen', kind: 'benefit' },
  { key: 'supplies', label: 'Supplies', kind: 'benefit' },
  { key: 'weatherRisk', label: 'Weather Risk', kind: 'risk' },
  { key: 'objectiveRisk', label: 'Objective Risk', kind: 'risk' },
  { key: 'teamCondition', label: 'Team Condition', kind: 'benefit' },
];

function pipColor(kind: Kind, value: number): string {
  if (kind === 'risk') return value >= 60 ? danger : spruce;
  if (kind === 'acclim') return spruce;
  return value <= 30 ? danger : spruce;
}

export function Instruments({ state }: { state: ExpeditionState }) {
  return (
    <View style={styles.grid}>
      {METERS.map((meter) => {
        const value = state[meter.key];
        const filled = Math.round(value / 10);
        const color = pipColor(meter.kind, value);
        const hint = meter.kind === 'risk' ? 'Higher is worse' : undefined;
        return (
          <View
            key={meter.key}
            style={styles.cell}
            accessibilityLabel={hint ? `${meter.label} ${value}. ${hint}.` : `${meter.label} ${value}.`}
          >
            <Text style={styles.label}>{meter.label}</Text>
            <Text style={[styles.value, color === danger && styles.dangerValue]}>{value}</Text>
            <View style={styles.pips}>
              {Array.from({ length: 10 }, (_, index) => (
                <View
                  key={index}
                  style={[styles.pip, index < filled ? { backgroundColor: color } : styles.pipEmpty]}
                />
              ))}
            </View>
            {hint ? <Text style={styles.hint}>{hint}</Text> : <View style={styles.hintSpace} />}
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -6,
  },
  cell: {
    width: '50%',
    paddingHorizontal: 6,
    paddingVertical: 8,
  },
  label: {
    fontFamily: font.bodyMedium,
    fontSize: 11,
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    color: muted,
  },
  value: {
    marginTop: 2,
    fontFamily: font.display,
    fontSize: 22,
    lineHeight: 26,
    color: body,
  },
  dangerValue: {
    color: danger,
  },
  pips: {
    flexDirection: 'row',
    gap: 3,
    marginTop: 6,
  },
  pip: {
    flex: 1,
    height: 7,
  },
  pipEmpty: {
    backgroundColor: line,
  },
  hint: {
    marginTop: 4,
    fontFamily: font.body,
    fontSize: 11,
    color: muted,
  },
  hintSpace: {
    height: 15,
    marginTop: 4,
  },
});
