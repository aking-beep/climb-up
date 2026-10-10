import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ClimbingCanvas } from '@/features/climbing/renderer/ClimbingCanvas';
import { TouchControls } from '@/features/climbing/input/TouchControls';
import { createBarranco, stepClimb } from '@/features/climbing/simulation/barranco';
import { drainClock } from '@/features/climbing/simulation/clock';
import { EMPTY_INPUT, type ClimbInput, type ClimbWorld } from '@/features/climbing/simulation/types';
import { resolveChallenge } from '@/game/hybrid/coordinator';
import type { ChallengeOutcome } from '@/game/hybrid/types';
import { updateSession, useSession } from '@/game/save/session';
import { Screen } from '@/components/ui/Screen';
import { font, muted, spruceInk } from '@/theme';
import { formatSeed } from '@/utils/number';

function reported(world: ClimbWorld, attemptId: string): ChallengeOutcome | null {
  const result = world.retreated ? 'retreated' : world.finished ? 'completed' : world.failed ? 'failed' : null;
  if (!result) return null;
  return {
    attemptId,
    challengeId: 'barranco-wall',
    eventId: 'kili-wall',
    choiceIndex: 0,
    result,
    elapsedSeconds: world.seconds,
    staminaSpent: Math.max(0, world.staminaStart - world.stamina),
    falls: world.falls,
    hazardsEncountered: world.hazards,
  };
}

function pulse(kind: 'select' | 'good' | 'bad') {
  const run =
    kind === 'select'
      ? Haptics.selectionAsync()
      : Haptics.notificationAsync(
          kind === 'good' ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning,
        );
  void run.catch(() => undefined);
}

export default function ChallengeScreen() {
  const insets = useSafeAreaInsets();
  const session = useSession();
  const pending = session.pending;
  const [world, setWorld] = useState<ClimbWorld>(() => createBarranco(session.state.energy));
  const [stage, setStage] = useState({ width: 0, height: 0 });
  const [paused, setPaused] = useState(false);
  const [calm, setCalm] = useState(false);
  const inputRef = useRef<ClimbInput>(EMPTY_INPUT);
  const pausedRef = useRef(false);
  const calmRef = useRef(false);
  const filed = useRef(false);
  const felt = useRef({ falls: 0, done: false });

  useEffect(() => {
    if (!session.booted) return;
    if (!session.pending) router.replace('/climb');
  }, [session.booted, session.pending]);

  useEffect(() => {
    let frame = 0;
    let last = performance.now();
    let accumulator = 0;
    const loop = (now: number) => {
      const frameDt = (now - last) / 1000;
      last = now;
      if (!pausedRef.current && !filed.current) {
        const drained = drainClock(accumulator, frameDt, calmRef.current);
        accumulator = drained.accumulator;
        const input = inputRef.current;
        if (drained.steps > 0) {
          setWorld((current) => {
            let next = current;
            for (let step = 0; step < drained.steps; step += 1) next = stepClimb(next, input, drained.dt);
            return next;
          });
        }
      } else {
        accumulator = 0;
      }
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    if (world.falls > felt.current.falls) {
      felt.current.falls = world.falls;
      pulse('bad');
    }
    const done = world.finished || world.failed || world.retreated;
    if (done && !felt.current.done) {
      felt.current.done = true;
      pulse(world.finished ? 'good' : 'bad');
    }
  }, [world.falls, world.finished, world.failed, world.retreated]);

  function hold(input: ClimbInput) {
    if (pausedRef.current && !input.retreat) return;
    inputRef.current = input;
    const moving = input.left || input.right || input.scramble || input.rest || input.help || input.continue || input.retreat;
    if (!moving) return;
    if (input.scramble || input.retreat || input.help) pulse('select');
    setWorld((current) => stepClimb(current, input, 1 / 30));
  }

  function togglePause() {
    inputRef.current = EMPTY_INPUT;
    setPaused((value) => {
      pausedRef.current = !value;
      return !value;
    });
    pulse('select');
  }

  function toggleCalm() {
    setCalm((value) => {
      calmRef.current = !value;
      return !value;
    });
    pulse('select');
  }

  useEffect(() => {
    if (!pending || filed.current) return;
    const outcome = reported(world, pending.attemptId);
    if (!outcome) return;
    filed.current = true;
    const next = resolveChallenge(session.state, pending, outcome);
    updateSession({ state: next, pending: null });
    router.replace({ pathname: '/climb', params: { code: formatSeed(next.seed) } });
  }, [pending, session.state, world]);

  return (
    <Screen>
      <StatusBar style="light" />
      <View style={[styles.hud, { paddingTop: insets.top + 8 }]}>
        <View style={styles.titles}>
          <Text style={styles.kicker}>Barranco · Morning</Text>
          <Text style={styles.title}>The scramble</Text>
        </View>
        <View style={styles.readout}>
          <Text style={styles.kicker}>Stamina {Math.round(world.stamina)}</Text>
          <Text style={styles.kicker}>Falls {world.falls}</Text>
          <View style={styles.tools}>
            <Pressable accessibilityRole="button" accessibilityLabel={paused ? 'Resume' : 'Pause'} onPress={togglePause}>
              <Text style={styles.tool}>{paused ? 'Resume' : 'Pause'}</Text>
            </Pressable>
            <Pressable accessibilityRole="button" accessibilityLabel={calm ? 'Full view' : 'Calm view'} onPress={toggleCalm}>
              <Text style={styles.tool}>{calm ? 'Full view' : 'Calm'}</Text>
            </Pressable>
          </View>
        </View>
      </View>
      <View style={styles.stage} onLayout={(event) => setStage(event.nativeEvent.layout)}>
        <ClimbingCanvas world={world} width={stage.width} height={stage.height} reduced={calm} />
        {paused ? (
          <View style={styles.pause}>
            <Text style={styles.pauseTitle}>Paused</Text>
            <Text style={styles.pauseCopy}>The rock can wait.</Text>
          </View>
        ) : null}
      </View>
      {world.prompt ? (
        <Text style={styles.prompt}>Marco is off the pace. The party can wait, rest, or go on.</Text>
      ) : (
        <Text style={styles.prompt}>Walk the rock. Scramble only where the ledge asks for it.</Text>
      )}
      <View style={{ paddingBottom: insets.bottom + 8 }}>
        <TouchControls prompt={world.prompt} onHold={hold} />
        <Text style={styles.note}>A fictional scramble. Not a route.</Text>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hud: {
    paddingHorizontal: 16,
    paddingBottom: 8,
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: '#1c2824',
  },
  titles: { flexShrink: 1 },
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: spruceInk,
  },
  title: { marginTop: 2, fontFamily: font.display, fontSize: 28, color: spruceInk },
  readout: { alignItems: 'flex-end', gap: 2 },
  tools: { flexDirection: 'row', gap: 12, marginTop: 4 },
  tool: { fontFamily: font.bodyMedium, fontSize: 13, color: spruceInk },
  stage: { flex: 1, backgroundColor: '#243038' },
  pause: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(18,17,15,0.45)',
    pointerEvents: 'none',
  },
  pauseTitle: { fontFamily: font.display, fontSize: 32, color: spruceInk },
  pauseCopy: { marginTop: 4, fontFamily: font.italic, fontSize: 16, color: spruceInk },
  prompt: {
    paddingHorizontal: 16,
    paddingTop: 8,
    fontFamily: font.italic,
    fontSize: 15,
    color: '#1c1915',
    backgroundColor: '#f3efe6',
  },
  note: {
    textAlign: 'center',
    fontFamily: font.body,
    fontSize: 11,
    color: muted,
    backgroundColor: '#f3efe6',
  },
});
