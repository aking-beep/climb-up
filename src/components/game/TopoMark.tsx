import { StyleSheet, View } from 'react-native';
import Svg, { Circle, Path, Polyline } from 'react-native-svg';

const CONTOURS = [
  'M0 112 C 46 104, 88 116, 136 106 S 214 90, 274 102 S 332 114, 360 100',
  'M0 92 C 42 84, 98 98, 152 86 S 232 70, 292 82 S 340 94, 360 78',
  'M0 72 C 58 64, 104 78, 162 62 S 242 48, 302 60 S 342 68, 360 52',
  'M0 52 C 72 46, 122 58, 182 42 S 252 30, 312 42 S 348 50, 360 36',
];

const ROUTE: readonly (readonly [number, number])[] = [
  [22, 104],
  [68, 96],
  [110, 88],
  [152, 78],
  [194, 68],
  [232, 56],
  [268, 44],
  [304, 32],
  [334, 22],
];

export function TopoMark({ progress, ink = '#f4f1ea' }: { progress: number; ink?: string }) {
  const t = Math.min(1, Math.max(0, progress));
  const index = Math.round(t * (ROUTE.length - 1));
  const [x, y] = ROUTE[index];
  const points = ROUTE.map(([px, py]) => `${px},${py}`).join(' ');

  return (
    <View style={styles.frame} accessibilityLabel="Topographic route sketch">
      <Svg viewBox="0 0 360 128" width="100%" height="100%">
        {CONTOURS.map((d) => (
          <Path key={d} d={d} stroke={ink} strokeOpacity={0.35} strokeWidth={1} fill="none" />
        ))}
        <Polyline points={points} stroke={ink} strokeWidth={1.6} fill="none" strokeLinejoin="round" />
        <Circle cx={x} cy={y} r={4} fill={ink} />
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  frame: { height: 112, width: '100%' },
});
