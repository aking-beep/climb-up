import Svg, { Circle, Polyline, Polygon } from 'react-native-svg';

import type { Weather } from '@/game/world';

const ROUTE = [
  { x: 46, y: 168 },
  { x: 86, y: 156 },
  { x: 124, y: 142 },
  { x: 162, y: 126 },
  { x: 198, y: 112 },
  { x: 230, y: 96 },
  { x: 262, y: 80 },
  { x: 292, y: 62 },
];

type Props = {
  band: number;
  weather: Weather;
  ink: string;
};

export function Mountain({ band, weather, ink }: Props) {
  const point = ROUTE[Math.min(Math.max(band, 0), ROUTE.length - 1)];
  const route = ROUTE.map((spot) => `${spot.x},${spot.y}`).join(' ');
  const pale = weather === 'whiteout';
  const far = pale ? '#c5ced4' : weather === 'storm' ? '#1a1e26' : '#6a3a32';
  const near = pale ? '#9aa6ae' : weather === 'storm' ? '#101318' : '#241c18';
  const routeColor = pale ? '#1c1915' : '#f6f1e8';

  return (
    <Svg viewBox="0 0 360 200" width="100%" height="100%" accessibilityElementsHidden>
      <Polygon
        points="0,148 28,132 74,144 118,104 168,128 214,86 258,112 304,78 360,98 360,200 0,200"
        fill={far}
      />
      <Polygon
        points="0,176 42,152 96,164 142,126 188,150 228,114 270,138 318,112 360,132 360,200 0,200"
        fill={near}
      />
      <Polyline
        points={route}
        fill="none"
        stroke={routeColor}
        strokeWidth={2}
        strokeDasharray="3 5"
        strokeLinecap="round"
      />
      <Circle cx={point.x} cy={point.y} r={7} fill="#c45c32" stroke={ink} strokeWidth={2} />
    </Svg>
  );
}
