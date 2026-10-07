import { StyleSheet, View } from 'react-native';
import type { ReactNode } from 'react';

import { ink, inkDeep } from '@/theme';

export function Frame({ children }: { children: ReactNode }) {
  return (
    <View style={styles.page}>
      <View style={styles.column}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: {
    flex: 1,
    backgroundColor: inkDeep,
    alignItems: 'center',
  },
  column: {
    flex: 1,
    width: '100%',
    maxWidth: 480,
    backgroundColor: ink,
  },
});
