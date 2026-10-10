/// <reference types="jest" />

import type { ReactElement } from 'react';

describe('challenge host', () => {
  test('a renderer that fails to load becomes a back-off screen, not a crash', () => {
    jest.isolateModules(() => {
      jest.doMock('@/features/climbing/ui/ChallengeView', () => {
        throw new Error('Native module RNSkia not found');
      });
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const { ChallengeHost } = require('@/features/climbing/ui/ChallengeHost');
      const onBackOff = jest.fn();
      const tree = ChallengeHost({ onBackOff } as never) as ReactElement<{ children: ReactElement<Record<string, unknown>>[] }>;
      const button = tree.props.children.find((child) => typeof child?.props?.onPress === 'function');
      expect(button?.props.onPress).toBe(onBackOff);
      expect(warn).toHaveBeenCalledWith(expect.stringContaining('RNSkia'));
      warn.mockRestore();
    });
  });
});
