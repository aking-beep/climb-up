import type { ComponentType, ReactNode } from 'react';

import type { WorldSceneProps } from './WorldScene';

type Props = WorldSceneProps & { fallback: ReactNode };

/**
 * The diorama needs React Native Skia. If this binary lacks it, the
 * expedition screen keeps working with the flat fallback scene instead of
 * crashing.
 */
let Loaded: ComponentType<WorldSceneProps> | null = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  Loaded = (require('./WorldScene') as { WorldScene: ComponentType<WorldSceneProps> }).WorldScene;
} catch (error) {
  console.warn(`CLIMB UP: the world renderer did not load (${error instanceof Error ? error.message : String(error)}).`);
}

export function WorldHost({ fallback, ...props }: Props) {
  if (Loaded) return <Loaded {...props} />;
  return <>{fallback}</>;
}
