import { useRef } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { body, font, line, muted, paperRaised, spruce, spruceInk } from '@/theme';
import { EMPTY_INPUT, type ClimbInput } from '@/features/climbing/simulation/types';

type Props = {
  prompt: boolean;
  onHold: (input: ClimbInput) => void;
};

function pad(partial: Partial<ClimbInput>): ClimbInput {
  return { ...EMPTY_INPUT, ...partial };
}

export function TouchControls({ prompt, onHold }: Props) {
  if (prompt) {
    return (
      <View style={styles.column}>
        <Choice label="Stay with Marco" detail="The party waits." input={pad({ help: true })} onHold={onHold} />
        <Choice label="Rest with Marco" detail="Time, and a little stamina." input={pad({ rest: true })} onHold={onHold} />
        <Choice label="Go on" detail="The scramble continues without waiting." input={pad({ continue: true })} onHold={onHold} />
      </View>
    );
  }

  return (
    <View style={styles.wrap}>
      <View style={styles.row}>
        <Hold label="Left" a11y="Move left" input={pad({ left: true })} onHold={onHold} />
        <Hold label="Right" a11y="Move right" input={pad({ right: true })} onHold={onHold} />
        <Hold label="Scramble" a11y="Scramble" input={pad({ scramble: true })} onHold={onHold} />
        <Hold label="Rest" a11y="Rest" input={pad({ rest: true })} onHold={onHold} />
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Come back down"
        onPress={() => onHold(pad({ retreat: true }))}
        style={styles.quit}
      >
        <Text style={styles.quitText}>Come back down</Text>
      </Pressable>
    </View>
  );
}

function Hold({
  label,
  a11y,
  input,
  onHold,
}: {
  label: string;
  a11y: string;
  input: ClimbInput;
  onHold: (input: ClimbInput) => void;
}) {
  const down = useRef(false);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={a11y}
      onPressIn={() => {
        down.current = true;
        onHold(input);
      }}
      onPress={() => {
        onHold(input);
        if (!down.current) onHold(EMPTY_INPUT);
      }}
      onPressOut={() => {
        down.current = false;
        onHold(EMPTY_INPUT);
      }}
      style={({ pressed }) => [styles.pad, pressed && styles.pressed]}
    >
      <Text style={styles.padText}>{label}</Text>
    </Pressable>
  );
}

function Choice({
  label,
  detail,
  input,
  onHold,
}: {
  label: string;
  detail: string;
  input: ClimbInput;
  onHold: (input: ClimbInput) => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={() => onHold(input)}
      style={({ pressed }) => [styles.choice, pressed && styles.pressed]}
    >
      <Text style={styles.choiceLabel}>{label}</Text>
      <Text style={styles.choiceDetail}>{detail}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  wrap: { paddingHorizontal: 16, paddingTop: 8, gap: 8 },
  row: { flexDirection: 'row', gap: 8 },
  pad: {
    flex: 1,
    minHeight: 64,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: spruce,
  },
  padText: { fontFamily: font.display, fontSize: 16, color: spruceInk },
  quit: { minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  quitText: { fontFamily: font.bodyMedium, fontSize: 15, color: muted },
  column: { paddingHorizontal: 16, paddingTop: 8, gap: 8 },
  choice: {
    minHeight: 58,
    justifyContent: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: paperRaised,
    borderWidth: 1,
    borderColor: line,
  },
  choiceLabel: { fontFamily: font.display, fontSize: 17, color: body },
  choiceDetail: { marginTop: 2, fontFamily: font.body, fontSize: 13, color: muted },
  pressed: { opacity: 0.82 },
});
