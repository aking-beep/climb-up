import { Link, Stack } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { Frame } from '@/components/Frame';
import { body, font, paper, rust, rustInk } from '@/theme';

export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: 'Off the map' }} />
      <Frame>
        <View style={styles.sheet}>
          <Text style={styles.kicker}>Off the map</Text>
          <Text style={styles.title}>This route is not on the mountain.</Text>
          <Link href="/" style={styles.link}>
            <Text style={styles.linkText}>Return to the road</Text>
          </Link>
        </View>
      </Frame>
    </>
  );
}

const styles = StyleSheet.create({
  sheet: {
    flex: 1,
    backgroundColor: paper,
    padding: 24,
    justifyContent: 'center',
  },
  kicker: {
    fontFamily: font.bodyMedium,
    color: body,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
    fontSize: 12,
  },
  title: {
    marginTop: 12,
    fontFamily: font.display,
    fontSize: 36,
    lineHeight: 40,
    color: body,
  },
  link: {
    marginTop: 28,
    backgroundColor: rust,
    borderRadius: 16,
    paddingVertical: 16,
    alignItems: 'center',
  },
  linkText: {
    fontFamily: font.display,
    fontSize: 20,
    color: rustInk,
  },
});
