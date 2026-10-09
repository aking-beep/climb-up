import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { MemberView } from '@/expeditions/kilimanjaro/party';
import { body, font, line, muted, paper, paperRaised, spruce, spruceInk } from '@/theme';

const METERS = [
  ['health', 'Health'],
  ['energy', 'Energy'],
  ['spirits', 'Spirits'],
] as const;

export function MemberSheet({
  member,
  actionLabel,
  onAction,
  onClose,
  bottom,
}: {
  member: MemberView;
  actionLabel: string | null;
  onAction: () => void;
  onClose: () => void;
  bottom: number;
}) {
  return (
    <View style={[styles.sheet, { paddingBottom: bottom }]}>
      <Text style={styles.kicker}>{member.role}</Text>
      <Text style={styles.title} accessibilityRole="header">
        {member.name}
      </Text>
      <Text style={styles.duty}>{member.duty}</Text>
      <Text style={styles.line}>{member.line}</Text>
      <View style={styles.meters}>
        {METERS.map(([key, label]) => (
          <View key={key} style={styles.meter}>
            <Text style={styles.meterLabel}>{label}</Text>
            <Text style={styles.meterValue}>{member[key]}</Text>
          </View>
        ))}
      </View>
      {actionLabel ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={actionLabel}
          onPress={onAction}
          style={({ pressed }) => [styles.go, pressed && styles.pressed]}
        >
          <Text style={styles.goText}>{actionLabel}</Text>
        </Pressable>
      ) : (
        <Text style={styles.note}>Nothing to do for them right now. The decision for the day is still waiting.</Text>
      )}
      <Pressable accessibilityRole="button" accessibilityLabel="Back to the day" onPress={onClose} style={styles.textButton}>
        <Text style={styles.textButtonLabel}>Back to the day</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: {
    maxHeight: '54%',
    backgroundColor: paper,
    borderTopWidth: 1,
    borderTopColor: line,
    paddingHorizontal: 16,
    paddingTop: 14,
  },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: muted,
  },
  title: { marginTop: 4, fontFamily: font.display, fontSize: 32, color: body },
  duty: { marginTop: 8, fontFamily: font.body, fontSize: 16, lineHeight: 22, color: body },
  line: { marginTop: 8, fontFamily: font.italic, fontSize: 16, lineHeight: 22, color: body },
  meters: { flexDirection: 'row', marginTop: 14 },
  meter: { flex: 1, backgroundColor: paperRaised, borderWidth: 1, borderColor: line, paddingVertical: 8, alignItems: 'center' },
  meterLabel: { fontFamily: font.bodyMedium, fontSize: 11, letterSpacing: 0.4, textTransform: 'uppercase', color: muted },
  meterValue: { marginTop: 2, fontFamily: font.display, fontSize: 22, color: body },
  go: { marginTop: 16, backgroundColor: spruce, minHeight: 52, alignItems: 'center', justifyContent: 'center' },
  pressed: { opacity: 0.84 },
  goText: { fontFamily: font.display, fontSize: 18, color: spruceInk },
  note: { marginTop: 16, fontFamily: font.body, fontSize: 15, lineHeight: 21, color: body },
  textButton: { minHeight: 44, justifyContent: 'center' },
  textButtonLabel: { fontFamily: font.bodyMedium, fontSize: 15, color: spruce },
});
