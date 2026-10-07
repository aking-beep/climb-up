import { Image } from 'react-native';

const FRAME = require('../../../assets/terrain/climber-a.png');

type Props = {
  step: number;
  facing: 'left' | 'right';
  scale?: number;
};

export function Climber({ step, facing, scale = 1 }: Props) {
  return (
    <Image
      source={FRAME}
      accessibilityIgnoresInvertColors
      style={{
        width: 74 * scale,
        height: 128 * scale,
        transform: [
          { scaleX: facing === 'left' ? -1 : 1 },
          { translateY: step % 2 === 0 ? 0 : -4 },
        ],
      }}
    />
  );
}
