import { WithSkiaWeb } from '@shopify/react-native-skia/lib/module/web';
import type { ComponentProps } from 'react';
import { Text } from 'react-native';

import type { ChallengeView } from './ChallengeView';

type Props = ComponentProps<typeof ChallengeView>;

/**
 * On web, Skia runs on CanvasKit (WebAssembly), which has to load before
 * any Skia component renders. `npm run web` copies canvaskit.wasm into
 * public/. Native builds never load this file.
 */
export function ChallengeHost(props: Props) {
  return (
    <WithSkiaWeb<Props>
      opts={{ locateFile: (file: string) => `/${file}` }}
      getComponent={() => import('./ChallengeView').then((module) => ({ default: module.ChallengeView }))}
      fallback={<Text style={{ padding: 24 }}>Loading the wall…</Text>}
      componentProps={props}
    />
  );
}
