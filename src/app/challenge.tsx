import { router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ClimbingCanvas } from '@/features/climbing/renderer/ClimbingCanvas';
import { TouchControls } from '@/features/climbing/input/TouchControls';
import { createBarranco, stepClimb } from '@/features/climbing/simulation/barranco';
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

export default function ChallengeScreen() {
  const insets = useSafeAreaInsets();
  const session = useSession();
  const pending = session.pending;
  const [world, setWorld] = useState<ClimbWorld>(() => createBarranco(session.state.energy));
  const [stage, setStage] = useState({ width: 0, height: 0 });
  const inputRef = useRef<ClimbInput>(EMPTY_INPUT);
  const filed = useRef(false);

  useEffect(() => {
    if (!session.booted) return;
    if (!session.pending) router.replace('/climb');
  }, [session.booted, session.pending]);

  useEffect(() => {
    let frame = 0;
    let last = performance.now();
    const loop = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      const input = inputRef.current;
      const held = input.left || input.right || input.scramble || input.rest;
      if (held) setWorld((current) => stepClimb(current, input, dt));
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  }, []);

  function hold(input: ClimbInput) {
    inputRef.current = input;
    const moving = input.left || input.right || input.scramble || input.rest || input.help || input.continue || input.retreat;
    if (!moving) return;
    setWorld((current) => stepClimb(current, input, 0.28));
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
        <View>
          <Text style={styles.kicker}>Barranco · Morning</Text>
          <Text style={styles.title}>The scramble</Text>
        </View>
        <View style={styles.readout}>
          <Text style={styles.kicker}>Stamina {Math.round(world.stamina)}</Text>
          <Text style={styles.kicker}>Falls {world.falls}</Text>
        </View>
      </View>
      <View style={styles.stage} onLayout={(event) => setStage(event.nativeEvent.layout)}>
        <ClimbingCanvas world={world} width={stage.width} height={stage.height} />
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
  kicker: {
    fontFamily: font.bodyMedium,
    fontSize: 12,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: spruceInk,
  },
  title: { marginTop: 2, fontFamily: font.display, fontSize: 28, color: spruceInk },
  readout: { alignItems: 'flex-end', gap: 2 },
  stage: { flex: 1, backgroundColor: '#243038' },
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
