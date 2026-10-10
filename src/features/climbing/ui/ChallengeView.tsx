import * as Haptics from 'expo-haptics';
import { useEffect, useState, useSyncExternalStore, type ReactNode } from 'react';
import { AppState, BackHandler, Platform, Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { dayPhase, expeditionHour } from '@/components/world/scene';
import type { ChallengeOutcome, PendingChallenge } from '@/game/hybrid/types';
import type { Settings } from '@/game/save/settings';
import type { ExpeditionState } from '@/game/types';
import { body, font, line, muted, paper, paperRaised, spruce, spruceInk } from '@/theme';

import { hintFor } from '../hints';
import { BARRANCO_LEVEL } from '../levels/barranco';
import { ClimbCanvas } from '../render/ClimbCanvas';
import { createRuntime, type HeldKey } from '../runtime';
import { TUNING, outcomeOf, type Command, type SimEvent } from '../sim';
import { Controls } from './Controls';

type Phase = 'brief' | 'play' | 'paused';

type Props = {
  pending: PendingChallenge;
  state: ExpeditionState;
  settings: Settings;
  onSettings: (patch: Partial<Settings>) => void;
  /** Called once with the finished attempt. */
  onFinish: (outcome: ChallengeOutcome) => void;
  /** Called when the player backs off from the briefing. */
  onBackOff: () => void;
};

const TILES_ACROSS = 11;
const CONTROLS_HEIGHT = 236;

const KEYS: Record<string, HeldKey> = {
  ArrowLeft: 'left',
  ArrowRight: 'right',
  ArrowUp: 'up',
  ArrowDown: 'down',
  a: 'left',
  d: 'right',
  w: 'up',
  s: 'down',
  ' ': 'act',
};

function buzz(events: readonly SimEvent[]) {
  for (const event of events) {
    if (event === 'slip' || event === 'fail') {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning).catch(() => undefined);
    } else if (event === 'complete') {
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => undefined);
    } else if (event === 'checkpoint' || event === 'helped') {
      void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => undefined);
    } else if (event === 'gust-warn' || event === 'mate') {
      void Haptics.selectionAsync().catch(() => undefined);
    }
  }
}

export function ChallengeView({ pending, state, settings, onSettings, onFinish, onBackOff }: Props) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  // Whole multiples of the 16 px art, so every art pixel is a whole number of points.
  const tile = Math.max(16, Math.floor(width / TILES_ACROSS / 16) * 16);
  // Room for the pad under the playfield, so the climber is never under a thumb.
  const playHeight = Math.max(height * 0.55, height - (CONTROLS_HEIGHT + insets.bottom));
  const [runtime] = useState(() =>
    createRuntime({
      level: BARRANCO_LEVEL,
      seed: pending.seed,
      energy: state.energy,
      weatherRisk: state.weatherRisk,
      view: { width: width / tile, height: playHeight / tile },
      onEvents: buzz,
    }),
  );
  const frame = useSyncExternalStore(runtime.subscribe, runtime.frame, runtime.frame);
  const [phase, setPhase] = useState<Phase>('brief');
  const [showPerf, setShowPerf] = useState(false);
  const [finished, setFinished] = useState(false);
  const { reducedMotion, lowPower } = settings;

  useEffect(() => {
    runtime.setView({ width: width / tile, height: playHeight / tile });
  }, [runtime, width, playHeight, tile]);

  // The game loop: fixed 60 Hz simulation, rendering at the display rate
  // (every other display frame in low-power mode).
  // Behind the briefing and the pause menu the scene keeps breathing, frozen.
  useEffect(() => {
    let raf = 0;
    let last: number | null = null;
    let odd = false;
    const tick = (now: number) => {
      const dt = last === null ? 1 / 60 : (now - last) / 1000;
      last = now;
      odd = !odd;
      if (phase === 'play') runtime.advance(dt, reducedMotion, !lowPower || odd);
      else if (!lowPower || odd) runtime.idle(dt, reducedMotion);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [phase, runtime, reducedMotion, lowPower]);

  // Leaving the app pauses the climb.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (next) => {
      if (next !== 'active') {
        runtime.release();
        setPhase((current) => (current === 'play' ? 'paused' : current));
      }
    });
    return () => sub.remove();
  }, [runtime]);

  // Android back opens the pause menu instead of leaving mid-climb.
  useEffect(() => {
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      runtime.release();
      setPhase((current) => (current === 'play' ? 'paused' : current === 'paused' ? 'play' : current));
      return true;
    });
    return () => sub.remove();
  }, [runtime]);

  // Keyboard on web, for testing in a browser.
  useEffect(() => {
    if (Platform.OS !== 'web' || typeof window === 'undefined') return;
    const down = (event: KeyboardEvent) => {
      const key = KEYS[event.key];
      if (key) runtime.press(key, true);
      if (event.key === 'Escape') setPhase((current) => (current === 'play' ? 'paused' : current));
    };
    const up = (event: KeyboardEvent) => {
      const key = KEYS[event.key];
      if (key) runtime.press(key, false);
    };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => {
      window.removeEventListener('keydown', down);
      window.removeEventListener('keyup', up);
    };
  }, [runtime]);

  function order(next: Command) {
    runtime.order(next, reducedMotion);
  }

  function finish() {
    if (finished) return;
    const outcome = outcomeOf(runtime.live(), pending.attemptId, pending.challengeId);
    if (!outcome) return;
    setFinished(true);
    onFinish(outcome);
  }

  const sim = frame.sim;
  const mode = sim.mode;
  const gameHour = expeditionHour(state.elapsedHours + 3);
  const hint = hintFor(sim);
  const staminaPct = Math.round((sim.stamina / sim.maxStamina) * 100);
  const helpPct = Math.round((sim.helpTicks / TUNING.helpTicks) * 100);

  return (
    <View style={styles.root}>
      <ClimbCanvas
        sim={sim}
        camera={frame.camera}
        width={width}
        height={height}
        playHeight={playHeight}
        tile={tile}
        timeMs={frame.timeMs}
        phase={dayPhase(gameHour)}
        weatherRisk={state.weatherRisk}
        reducedMotion={settings.reducedMotion}
        lowPower={settings.lowPower}
      />

      {/* HUD */}
      <View pointerEvents="box-none" style={[styles.hud, { paddingTop: insets.top + 8 }]}>
        <View style={styles.hudRow}>
          <View style={styles.hudBlock}>
            <Text style={styles.hudKicker}>Barranco Wall · Playable</Text>
            <View
              style={styles.bar}
              accessible
              accessibilityRole="progressbar"
              accessibilityLabel="Stamina"
              accessibilityValue={{ min: 0, max: 100, now: staminaPct }}
            >
              <View style={[styles.barFill, { width: `${staminaPct}%`, backgroundColor: staminaPct < 25 ? '#c0573e' : staminaPct < 50 ? '#d9a441' : '#7fa36b' }]} />
            </View>
            <Text style={styles.hudText}>
              Stamina {staminaPct}% · Slips {sim.slips}/{TUNING.maxSlips} · Cairn {sim.checkpoint}/{sim.level.checkpoints.length - 1}
            </Text>
            {showPerf ? (
              <Text style={styles.hudText}>
                {frame.fps} fps · sim {frame.simMs.toFixed(2)} ms/frame{settings.lowPower ? ' · low power' : ''}
              </Text>
            ) : null}
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Pause"
            onPress={() => setPhase('paused')}
            style={({ pressed }) => [styles.pause, pressed && styles.pressed]}
          >
            <Text style={styles.pauseText}>II</Text>
          </Pressable>
        </View>
        {hint && phase === 'play' ? (
          <Text style={styles.hint} accessibilityLiveRegion="polite">
            {hint}
          </Text>
        ) : null}
      </View>

      {phase === 'play' && mode === 'play' ? (
        <Controls press={runtime.press} leftHanded={settings.leftHanded} bottom={insets.bottom + 16} />
      ) : null}

      {phase === 'brief' ? (
        <Sheet bottom={insets.bottom}>
          <Text style={styles.kicker}>Barranco Camp · morning</Text>
          <Text style={styles.title}>The Barranco Wall</Text>
          <Text style={styles.body}>
            A steep morning scramble, played. Hold up on the rock to climb. Ledges and cairns are where you breathe. On the exposed step, stop when the wind comes. Marco is somewhere above you.
          </Text>
          <Text style={styles.facts}>
            Energy {state.energy} → stamina {sim.maxStamina}% · Team {state.teamCondition} · Weather risk {state.weatherRisk}
          </Text>
          <Text style={styles.small}>Game fiction inspired by the place. Not a description of the real route.</Text>
          <Button primary label="Start up the wall" onPress={() => setPhase('play')} />
          <Button label="Back off and stay at Barranco" onPress={onBackOff} />
        </Sheet>
      ) : null}

      {phase === 'play' && mode === 'mate' ? (
        <Sheet bottom={insets.bottom}>
          <Text style={styles.kicker}>Teammate</Text>
          <Text style={styles.title}>Marco is stuck on the step</Text>
          <Text style={styles.body}>
            He has the pack wedged and no footing. Pulling him up costs you {TUNING.helpCost} stamina. Lena is behind and could bring him later.
          </Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={settings.holdAsToggle ? 'Help Marco. Tap to start or stop' : 'Help Marco. Press and hold'}
            accessibilityState={{ disabled: sim.stamina < TUNING.helpCost }}
            onPressIn={() => {
              if (!settings.holdAsToggle) runtime.press('act', true);
            }}
            onPressOut={() => {
              if (!settings.holdAsToggle) runtime.press('act', false);
            }}
            onPress={() => {
              if (settings.holdAsToggle) runtime.toggle('act');
            }}
            style={({ pressed }) => [styles.button, styles.primary, pressed && styles.pressed, sim.stamina < TUNING.helpCost && styles.disabled]}
          >
            <View style={[styles.holdFill, { width: `${helpPct}%` }]} />
            <Text style={[styles.buttonText, styles.primaryText]}>
              {sim.stamina < TUNING.helpCost
                ? 'Not enough stamina. Step back and rest first'
                : settings.holdAsToggle
                  ? frame.acting
                    ? 'Helping… tap to stop'
                    : 'Tap to help Marco up'
                  : 'Hold to help Marco up'}
            </Text>
          </Pressable>
          <Button label="Leave him for Lena" onPress={() => order({ type: 'leave-mate' })} />
          <Button label="Step back" onPress={() => order({ type: 'step-back' })} />
        </Sheet>
      ) : null}

      {phase === 'play' && mode === 'decide' ? (
        <Sheet bottom={insets.bottom}>
          <Text style={styles.kicker}>Halfway up</Text>
          <Text style={styles.title}>{sim.mate.state === 'helped' ? 'Marco is up. Now what?' : 'Lena has Marco. Now what?'}</Text>
          <Text style={styles.body}>Stamina {staminaPct}%. The loose gully above is the last of the wall.</Text>
          <Button primary label="Keep climbing" onPress={() => order({ type: 'continue' })} />
          <Button label="Regroup here (half an hour, full stamina)" onPress={() => order({ type: 'regroup' })} />
          <Button label="Turn back to Barranco" onPress={() => order({ type: 'retreat' })} />
        </Sheet>
      ) : null}

      {mode === 'done' ? (
        <Sheet bottom={insets.bottom}>
          <Text style={styles.kicker}>{sim.result === 'complete' ? 'Top of the wall' : sim.result === 'retreat' ? 'Backed off' : 'Called off'}</Text>
          <Text style={styles.title}>
            {sim.result === 'complete' ? 'Karanga is over the rise' : sim.result === 'retreat' ? 'Back down to Barranco' : 'The wall said no today'}
          </Text>
          <Text style={styles.body}>
            {sim.slips === 0 ? 'No slips.' : `${sim.slips} slip${sim.slips === 1 ? '' : 's'}.`} Stamina {staminaPct}%.{' '}
            {sim.mate.state === 'helped' ? 'You helped Marco up.' : sim.mate.state === 'left' && sim.level.mate ? 'Lena brought Marco.' : ''}
            {sim.regrouped ? ' The party regrouped on the wall.' : ''}
          </Text>
          <Text style={styles.small}>This lands on the expedition once, when you return.</Text>
          <Button primary label="Return to the expedition" onPress={finish} />
        </Sheet>
      ) : null}

      {phase === 'paused' && mode !== 'done' ? (
        <Sheet bottom={insets.bottom}>
          <Text style={styles.kicker}>Paused</Text>
          <Text style={styles.title}>On the wall</Text>
          <Button primary label="Resume" onPress={() => setPhase('play')} />
          <Button
            label="Back off the wall"
            onPress={() => {
              order({ type: 'retreat' });
              setPhase('play');
            }}
          />
          <Toggle label="Reduced motion" value={settings.reducedMotion} onChange={(v) => onSettings({ reducedMotion: v })} />
          <Toggle label="Low power (30 fps, less weather)" value={settings.lowPower} onChange={(v) => onSettings({ lowPower: v })} />
          <Toggle label="Pad on the right" value={settings.leftHanded} onChange={(v) => onSettings({ leftHanded: v })} />
          <Toggle label="Tap instead of hold for help" value={settings.holdAsToggle} onChange={(v) => onSettings({ holdAsToggle: v })} />
          <Toggle label="Show frame rate" value={showPerf} onChange={setShowPerf} />
        </Sheet>
      ) : null}
    </View>
  );
}

function Sheet({ children, bottom }: { children: ReactNode; bottom: number }) {
  return <View style={[styles.sheet, { paddingBottom: bottom + 14 }]}>{children}</View>;
}

function Button({ label, onPress, primary = false }: { label: string; onPress: () => void; primary?: boolean }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [styles.button, primary && styles.primary, pressed && styles.pressed]}
    >
      <Text style={[styles.buttonText, primary && styles.primaryText]}>{label}</Text>
    </Pressable>
  );
}

function Toggle({ label, value, onChange }: { label: string; value: boolean; onChange: (value: boolean) => void }) {
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityLabel={label}
      accessibilityState={{ checked: value }}
      onPress={() => onChange(!value)}
      style={styles.toggle}
    >
      <Text style={styles.toggleLabel}>{label}</Text>
      <Text style={styles.toggleValue}>{value ? 'On' : 'Off'}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#1a1612' },
  hud: { position: 'absolute', left: 0, right: 0, top: 0, paddingHorizontal: 14 },
  hudRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
  hudBlock: {
    flex: 1,
    backgroundColor: 'rgba(18,17,15,0.55)',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 10,
  },
  hudKicker: { fontFamily: font.bodyMedium, fontSize: 11, letterSpacing: 1.1, textTransform: 'uppercase', color: spruceInk, opacity: 0.85 },
  hudText: { marginTop: 4, fontFamily: font.bodyMedium, fontSize: 13, color: spruceInk },
  bar: { marginTop: 6, height: 10, borderRadius: 5, backgroundColor: 'rgba(244,241,234,0.2)', overflow: 'hidden' },
  barFill: { height: '100%', borderRadius: 5 },
  pause: {
    width: 48,
    height: 48,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(18,17,15,0.55)',
  },
  pauseText: { fontFamily: font.bodySemi, fontSize: 16, color: spruceInk },
  hint: {
    marginTop: 8,
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(18,17,15,0.7)',
    color: spruceInk,
    fontFamily: font.bodyMedium,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    overflow: 'hidden',
  },
  sheet: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: paper,
    borderTopWidth: 1,
    borderTopColor: line,
    paddingHorizontal: 18,
    paddingTop: 16,
    gap: 8,
  },
  kicker: { fontFamily: font.bodyMedium, fontSize: 11, letterSpacing: 1.1, textTransform: 'uppercase', color: muted },
  title: { fontFamily: font.display, fontSize: 24, lineHeight: 28, color: body },
  body: { fontFamily: font.body, fontSize: 15, lineHeight: 21, color: body },
  facts: { fontFamily: font.bodyMedium, fontSize: 13, color: muted },
  small: { fontFamily: font.body, fontSize: 12, color: muted },
  button: {
    minHeight: 52,
    justifyContent: 'center',
    paddingHorizontal: 14,
    backgroundColor: paperRaised,
    borderWidth: 1,
    borderColor: line,
    overflow: 'hidden',
  },
  primary: { backgroundColor: spruce, borderColor: spruce },
  pressed: { opacity: 0.82 },
  disabled: { opacity: 0.5 },
  buttonText: { fontFamily: font.display, fontSize: 17, color: body },
  primaryText: { color: spruceInk },
  holdFill: { position: 'absolute', left: 0, top: 0, bottom: 0, backgroundColor: 'rgba(244,241,234,0.25)' },
  toggle: { minHeight: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  toggleLabel: { fontFamily: font.body, fontSize: 15, color: body },
  toggleValue: { fontFamily: font.bodySemi, fontSize: 15, color: muted },
});
