import { Link, Stack } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { Screen } from '@/components/ui/Screen';
import { body, font, spruce, spruceInk } from '@/theme';

export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: 'Off the map' }} />
      <Screen>
        <View style={styles.sheet}>
          <Text style={styles.kicker}>Off the map</Text>
          <Text style={styles.title}>This page is not on the route.</Text>
          <Link href="/" style={styles.link}>
            <Text style={styles.linkText}>Return to the briefing</Text>
          </Link>
        </View>
      </Screen>
    </>
  );
}

const styles = StyleSheet.create({
  sheet: {
    flex: 1,
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
    backgroundColor: spruce,
    paddingVertical: 16,
    alignItems: 'center',
  },
  linkText: {
    fontFamily: font.display,
    fontSize: 20,
    color: spruceInk,
  },
});
