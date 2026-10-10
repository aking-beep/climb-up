import { WithSkiaWeb } from '@shopify/react-native-skia/lib/module/web';
import type { ReactNode } from 'react';

import type { WorldSceneProps } from './WorldScene';

type Props = WorldSceneProps & { fallback: ReactNode };

/**
 * On web, Skia runs on CanvasKit (WebAssembly), which loads before the
 * diorama can draw. The flat scene stands in until it has.
 */
export function WorldHost({ fallback, ...props }: Props) {
  return (
    <WithSkiaWeb<WorldSceneProps>
      opts={{ locateFile: (file: string) => `/${file}` }}
      getComponent={() => import('./WorldScene').then((module) => ({ default: module.WorldScene }))}
      fallback={<>{fallback}</>}
      componentProps={props}
    />
  );
}
