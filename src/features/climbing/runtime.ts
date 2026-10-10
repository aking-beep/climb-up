import { createCamera, followCamera, kick, type Camera, type View } from './camera';
import type { Level } from './level';
import { STEP, command, createSim, step, type ClimbInput, type ClimbSim, type Command, type SimEvent } from './sim';

export type HeldKey = 'left' | 'right' | 'up' | 'down' | 'act';

export type Frame = {
  sim: ClimbSim;
  camera: Camera;
  timeMs: number;
  fps: number;
  /** Smoothed simulation cost per rendered frame, in ms. */
  simMs: number;
  acting: boolean;
};

export type RuntimeOptions = {
  level: Level;
  seed: number;
  energy: number;
  weatherRisk: number;
  view: View;
  onEvents?: (events: readonly SimEvent[]) => void;
  now?: () => number;
};

/**
 * Owns everything that changes sixty times a second, outside React. The
 * screen reads immutable frames from it; nothing here is touched during a
 * render. Fixed-step: `advance` runs as many 60 Hz ticks as the elapsed
 * time allows, independent of the display rate.
 */
export function createRuntime(options: RuntimeOptions) {
  const { level, onEvents } = options;
  const now = options.now ?? (() => Date.now());
  const sim = createSim(options);
  const held: Record<HeldKey, boolean> = { left: false, right: false, up: false, down: false, act: false };
  let view = options.view;
  let camera = createCamera(sim, view, level);
  let timeMs = 0;
  let acc = 0;
  let fps = 0;
  let simMs = 0;
  let frames = 0;
  let since = 0;
  let frame: Frame = snapshot();
  const listeners = new Set<() => void>();

  function input(): ClimbInput {
    return {
      x: (held.right ? 1 : 0) - (held.left ? 1 : 0),
      y: (held.up ? 1 : 0) - (held.down ? 1 : 0),
      act: held.act,
    };
  }

  function snapshot(): Frame {
    return {
      sim: { ...sim, mate: { ...sim.mate }, events: [...sim.events], trail: sim.trail },
      camera,
      timeMs,
      fps,
      simMs,
      acting: held.act,
    };
  }

  function publish() {
    frame = snapshot();
    for (const listener of listeners) listener();
  }

  function react(events: readonly SimEvent[], reducedMotion: boolean) {
    if (events.length === 0) return;
    if (events.includes('slip')) camera = kick(camera, 0.8, reducedMotion);
    if (events.includes('gust')) camera = kick(camera, 0.25, reducedMotion);
    onEvents?.(events);
  }

  return {
    level,
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    frame: () => frame,
    setView(next: View) {
      view = next;
    },
    press(key: HeldKey, down: boolean) {
      held[key] = down;
    },
    toggle(key: HeldKey) {
      held[key] = !held[key];
      publish();
    },
    release() {
      for (const key of Object.keys(held) as HeldKey[]) held[key] = false;
    },
    order(next: Command, reducedMotion = false) {
      command(sim, next);
      react(sim.events, reducedMotion);
      publish();
    },
    /** Runs the simulation forward by `dt` seconds of wall time. */
    advance(dt: number, reducedMotion: boolean, render: boolean) {
      const started = now();
      acc += Math.min(0.1, Math.max(0, dt));
      let steps = 0;
      while (acc >= STEP && steps < 6) {
        step(sim, input());
        react(sim.events, reducedMotion);
        acc -= STEP;
        steps += 1;
      }
      // Never spiral: a long stall drops time instead of fast-forwarding.
      if (steps === 6) acc = 0;
      simMs = simMs * 0.9 + (now() - started) * 0.1;
      camera = followCamera(camera, sim, view, level, dt, reducedMotion);
      timeMs += dt * 1000;
      frames += 1;
      since += dt;
      if (since >= 1) {
        fps = Math.round(frames / since);
        frames = 0;
        since = 0;
      }
      if (render) publish();
    },
    /** Time passes for clouds and the camera, but the climb is frozen (briefing, pause). */
    idle(dt: number, reducedMotion: boolean) {
      camera = followCamera(camera, sim, view, level, dt, reducedMotion);
      timeMs += Math.min(0.1, Math.max(0, dt)) * 1000;
      publish();
    },
    /** The live sim, for reading an outcome once the attempt has ended. */
    live: () => sim,
  };
}

export type ClimbRuntime = ReturnType<typeof createRuntime>;
