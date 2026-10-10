import { useEffect, useState } from 'react';
import { Platform, View } from 'react-native';

import type { ClimbWorld } from '@/features/climbing/simulation/types';

import { ViewScene } from './ViewScene';

export function ClimbingCanvas({
  world,
  width,
  height,
  reduced = false,
}: {
  world: ClimbWorld;
  width: number;
  height: number;
  reduced?: boolean;
}) {
  const [NativeScene, setNativeScene] = useState<typeof ViewScene | null>(null);

  useEffect(() => {
    if (Platform.OS === 'web' || width < 2 || height < 2) return;
    let live = true;
    import('./SkiaScene')
      .then((mod) => {
        if (live) setNativeScene(() => mod.SkiaScene);
      })
      .catch((error: unknown) => {
        const message = error instanceof Error ? error.message : 'unknown error';
        console.warn(`CLIMB UP: Skia did not start (${message}). The view scene is on screen instead.`);
      });
    return () => {
      live = false;
    };
  }, [width, height]);

  if (width < 2 || height < 2) return <View style={{ flex: 1, backgroundColor: '#243038' }} />;
  const Scene = NativeScene ?? ViewScene;
  return <Scene world={world} width={width} height={height} reduced={reduced} />;
}
