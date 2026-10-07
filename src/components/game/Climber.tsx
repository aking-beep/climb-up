import Svg, { Circle, Path } from 'react-native-svg';

const CREAM = '#f4f1ea';
const OUTLINE = '#101410';

type Props = {
  step: number;
  facing: 'left' | 'right';
};

function Stroke({ d }: { d: string }) {
  return (
    <>
      <Path d={d} stroke={OUTLINE} strokeWidth={5} fill="none" strokeLinecap="round" strokeLinejoin="round" />
      <Path d={d} stroke={CREAM} strokeWidth={2.4} fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </>
  );
}

export function Climber({ step, facing }: Props) {
  const leading = step % 2 === 0;
  const legs = leading ? 'M24 34 L14 54 M24 34 L32 52' : 'M24 34 L18 54 M24 34 L36 50';
  const arm = leading ? 'M24 22 L34 32' : 'M24 22 L33 28';

  return (
    <Svg
      width={48}
      height={60}
      viewBox="0 0 48 60"
      style={{ transform: [{ scaleX: facing === 'left' ? -1 : 1 }] }}
    >
      <Stroke d="M12 20 H20 V32 H12 Z" />
      <Stroke d={arm} />
      <Stroke d="M24 16 L24 34" />
      <Stroke d={legs} />
      <Stroke d="M32 28 L38 44 M34 30 L40 28" />
      <Circle cx={24} cy={11} r={5.5} fill={OUTLINE} />
      <Circle cx={24} cy={11} r={4.2} fill={CREAM} />
    </Svg>
  );
}
