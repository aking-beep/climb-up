/// <reference types="jest" />

import type { ReactElement } from 'react';

describe('world host', () => {
  test('a renderer that fails to load shows the flat scene instead of crashing', () => {
    jest.isolateModules(() => {
      jest.doMock('@/features/world/WorldScene', () => {
        throw new Error('Native module RNSkia not found');
      });
      const warn = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const { WorldHost } = require('@/features/world/WorldHost');
      const fallback = <></>;
      const tree = WorldHost({ fallback } as never) as ReactElement<{ children: unknown }>;
      expect(tree.props.children).toBe(fallback);
      expect(warn).toHaveBeenCalledWith(expect.stringContaining('RNSkia'));
      warn.mockRestore();
    });
  });
});
