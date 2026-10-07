import { StyleSheet, Text, View } from 'react-native';

import { type Climber, isAlive, statusOf, subject } from '@/game/world';
import { body, font, line, lost, muted, paperRaised } from '@/theme';

const STATUS_WORD: Record<string, string> = {
  fit: 'Fit',
  strained: 'Strained',
  hurt: 'Hurt',
  critical: 'Critical',
  dead: 'Lost',
};

export function Party({ party }: { party: Climber[] }) {
  return (
    <View style={styles.grid}>
      {party.map((person) => {
        const status = statusOf(person.strain);
        const alive = isAlive(person);
        const word = STATUS_WORD[status];
        return (
          <View
            key={person.id}
            style={[styles.chip, !alive && styles.chipLost]}
            accessibilityLabel={`${subject(person)}, ${person.role}, ${word}`}
          >
            <Text style={[styles.name, !alive && styles.nameLost]}>{person.name}</Text>
            <Text style={styles.role}>{person.role}</Text>
            <Text style={[styles.status, !alive && styles.statusLost]}>{word}</Text>
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
    gap: 8,
    marginTop: 12,
  },
  chip: {
    width: '48%',
    flexGrow: 1,
    backgroundColor: paperRaised,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: line,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  chipLost: {
    borderColor: 'rgba(141, 45, 31, 0.45)',
  },
  name: {
    fontFamily: font.bodySemi,
    fontSize: 15,
    color: body,
  },
  nameLost: {
    color: lost,
    textDecorationLine: 'line-through',
  },
  role: {
    marginTop: 2,
    fontFamily: font.body,
    fontSize: 12,
    color: muted,
  },
  status: {
    marginTop: 6,
    fontFamily: font.bodyMedium,
    fontSize: 13,
    color: body,
  },
  statusLost: {
    color: lost,
  },
});
