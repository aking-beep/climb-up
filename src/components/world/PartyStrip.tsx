import { Image, Pressable, StyleSheet, Text, View } from 'react-native';

import type { MemberView } from '@/expeditions/kilimanjaro/party';
import { font, muted, paper, spruce } from '@/theme';

import type { PartyId } from './scene';

const SPRITES: Record<PartyId, number> = {
  jun: require('../../../assets/world/pixel-jun.png'),
  marco: require('../../../assets/world/pixel-marco.png'),
  you: require('../../../assets/world/pixel-you.png'),
  lena: require('../../../assets/world/pixel-lena.png'),
};

function pip(member: MemberView): string {
  if (member.pose === 'kneel') return '#7a3b2e';
  if (member.pose === 'lag') return '#a56a32';
  return spruce;
}

/** The party menu. Tap a person the way an HD-2D game opens a traveler. */
export function PartyStrip({
  members,
  selected,
  onSelect,
}: {
  members: readonly MemberView[];
  selected: PartyId | null;
  onSelect: (id: PartyId) => void;
}) {
  return (
    <View style={styles.bar}>
      {members.map((member) => {
        const open = selected === member.id;
        return (
          <Pressable
            key={member.id}
            accessibilityRole="button"
            accessibilityLabel={`${member.name}, ${member.role}`}
            accessibilityState={{ selected: open }}
            onPress={() => onSelect(member.id)}
            style={({ pressed }) => [styles.person, open && styles.open, pressed && styles.pressed]}
          >
            <Image source={SPRITES[member.id]} style={styles.sprite} resizeMode="contain" accessibilityIgnoresInvertColors />
            <View style={[styles.pip, { backgroundColor: pip(member) }]} />
            <Text style={styles.name} numberOfLines={1}>
              {member.name}
            </Text>
            <Text style={styles.role} numberOfLines={1}>
              {member.role}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    backgroundColor: paper,
    borderTopWidth: 1,
    borderTopColor: '#d9d1c3',
    paddingHorizontal: 6,
    paddingTop: 6,
    paddingBottom: 4,
  },
  person: { flex: 1, alignItems: 'center', minHeight: 64, paddingVertical: 2 },
  open: { backgroundColor: '#e7e1d4' },
  pressed: { opacity: 0.72 },
  sprite: { width: 22, height: 36 },
  pip: { position: 'absolute', top: 4, right: 10, width: 7, height: 7, borderRadius: 4 },
  name: { fontFamily: font.bodySemi, fontSize: 12, color: '#1c1915' },
  role: { fontFamily: font.body, fontSize: 10, color: muted },
});
