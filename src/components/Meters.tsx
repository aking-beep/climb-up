import { StyleSheet, Text, View } from 'react-native';

import type { GameState } from '@/game/world';
import { body, font, line, lost, muted, paperRaised } from '@/theme';

type Meter = {
  label: string;
  hint: string;
  value: number;
  display: string;
};

function metersFor(state: GameState): Meter[] {
  return [
    { label: 'Warmth', hint: 'Warmth', value: state.warmth, display: String(state.warmth) },
    { label: 'Food', hint: 'Food', value: state.food, display: String(state.food) },
    { label: 'Light', hint: 'Daylight hours', value: Math.max(0, state.daylight) * (100 / 12), display: `${Math.max(0, state.daylight)}h` },
    { label: 'Rope', hint: 'Rope', value: state.rope, display: String(state.rope) },
    { label: 'Lungs', hint: 'Acclimatization', value: state.acclimatization, display: String(state.acclimatization) },
    { label: 'Morale', hint: 'Morale', value: state.morale, display: String(state.morale) },
  ];
}

export function Meters({ state }: { state: GameState }) {
  return (
    <View style={styles.grid}>
      {metersFor(state).map((meter) => {
        const low = meter.value <= 25;
        return (
          <View
            key={meter.label}
            style={styles.meter}
            accessibilityLabel={`${meter.hint} ${meter.display}`}
          >
            <View style={styles.row}>
              <Text style={styles.label}>{meter.label}</Text>
              <Text style={[styles.value, low && styles.low]}>{meter.display}</Text>
            </View>
            <View style={styles.track}>
              <View style={[styles.fill, low && styles.fillLow, { width: `${Math.max(0, Math.min(100, meter.value))}%` }]} />
            </View>
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
    gap: 10,
  },
  meter: {
    width: '31%',
    flexGrow: 1,
    backgroundColor: paperRaised,
    borderRadius: 12,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: line,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    gap: 6,
  },
  label: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    color: muted,
  },
  value: {
    fontFamily: font.bodySemi,
    fontSize: 14,
    color: body,
  },
  low: {
    color: lost,
  },
  track: {
    marginTop: 6,
    height: 4,
    borderRadius: 2,
    backgroundColor: 'rgba(26, 22, 18, 0.1)',
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    backgroundColor: body,
  },
  fillLow: {
    backgroundColor: lost,
  },
});
