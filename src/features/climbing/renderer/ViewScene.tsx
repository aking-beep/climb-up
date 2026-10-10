import { Image, StyleSheet, View, type ImageStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';

import {
  PLATFORMS,
  PLAYER_H,
  PLAYER_W,
  WORLD_H,
  WORLD_W,
  groundTop,
} from '@/features/climbing/simulation/barranco';
import type { ClimbWorld } from '@/features/climbing/simulation/types';

const FAR = require('../../../../assets/world/diorama-desert.jpg');
const YOU = require('../../../../assets/world/pixel-you.png');
const LENA = require('../../../../assets/world/pixel-lena.png');
const MARCO = require('../../../../assets/world/pixel-marco.png');
const TENT = require('../../../../assets/world/pixel-tent.png');

const pixel = { imageRendering: 'pixelated' } as ImageStyle;
const ROCK = ['#4e4034', '#3a312a', '#5a4638', '#2c261f', '#685848'];

function rockCourses(width: number, height: number) {
  const courses = [];
  let n = 0;
  for (let row = 14; row < height - 6; row += 24) {
    const stagger = (n % 2) * 14;
    for (let x = 2 + stagger; x < width - 12; x += 36) {
      courses.push({
        x,
        y: row + (n % 3) * 2,
        w: 26 + (n % 4) * 6,
        h: 16 + (n % 3) * 6,
        color: ROCK[n % ROCK.length],
      });
      n += 1;
    }
  }
  return courses;
}

export function ViewScene({ world, width, height }: { world: ClimbWorld; width: number; height: number }) {
  const scale = height / WORLD_H;
  const viewWorld = width / scale;
  const cam = Math.max(0, Math.min(Math.max(0, WORLD_W - viewWorld), world.x - viewWorld * 0.36));
  const sx = (x: number) => (x - cam) * scale;
  const bob = Math.abs(world.vx) > 12 ? Math.sin(world.seconds * 12) * 2 : 0;
  const marcoGone = world.hazards.some((hazard) => hazard.endsWith('marco'));

  return (
    <View style={styles.frame} accessibilityLabel={`Barranco scramble, stamina ${Math.round(world.stamina)}`}>
      <LinearGradient colors={['#e4d2b4', '#9eb0ac', '#243038']} style={StyleSheet.absoluteFill} />
      <Image
        source={FAR}
        style={[
          styles.far,
          pixel,
          { width: width * 1.5, height: height * 0.58, left: -cam * scale * 0.22, top: height * 0.05 },
        ]}
      />
      <View style={[styles.haze, { top: height * 0.42 }]} />
      {PLATFORMS.map((platform) => (
        <View key={`${platform.x}-${platform.y}`}>
          <View
            style={{
              position: 'absolute',
              left: sx(platform.x),
              top: (platform.y + 6) * scale,
              width: platform.w * scale,
              height: platform.h * scale,
              backgroundColor: '#2a241f',
            }}
          />
          {rockCourses(platform.w, platform.h).map((course) => (
            <View
              key={`${platform.x}-${course.x}-${course.y}`}
              style={{
                position: 'absolute',
                left: sx(platform.x + course.x),
                top: (platform.y + course.y) * scale,
                width: course.w * scale,
                height: course.h * scale,
                backgroundColor: course.color,
              }}
            />
          ))}
          <View
            style={{
              position: 'absolute',
              left: sx(platform.x),
              top: platform.y * scale,
              width: platform.w * scale,
              height: 7 * scale,
              backgroundColor: '#6a5644',
            }}
          />
        </View>
      ))}
      <Image source={TENT} style={[styles.tent, pixel, { left: sx(78), top: (groundTop(80) - 34) * scale }]} />
      <Image source={TENT} style={[styles.tent, pixel, { left: sx(124), top: (groundTop(130) - 30) * scale, opacity: 0.9 }]} />
      {!marcoGone ? (
        <Image
          source={MARCO}
          style={[styles.person, pixel, { left: sx(636), top: (160 - PLAYER_H) * scale, width: PLAYER_W * scale, height: PLAYER_H * scale }]}
        />
      ) : null}
      <Image
        source={LENA}
        style={[
          styles.person,
          pixel,
          {
            left: sx(world.x - 34),
            top: (world.y + 6 + bob) * scale,
            width: PLAYER_W * scale * 0.86,
            height: PLAYER_H * scale * 0.86,
            transform: [{ scaleX: world.facing }],
          },
        ]}
      />
      <Image
        source={YOU}
        style={[
          styles.person,
          pixel,
          {
            left: sx(world.x),
            top: (world.y + bob) * scale,
            width: PLAYER_W * scale,
            height: PLAYER_H * scale,
            transform: [{ scaleX: world.facing }],
          },
        ]}
      />
      <View style={styles.mist} />
    </View>
  );
}

const styles = StyleSheet.create({
  frame: { flex: 1, overflow: 'hidden', backgroundColor: '#243038' },
  far: { position: 'absolute', opacity: 0.88 },
  haze: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 48,
    backgroundColor: 'rgba(228,210,180,0.18)',
  },
  tent: { position: 'absolute', width: 54, height: 34 },
  person: { position: 'absolute' },
  mist: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 28,
    backgroundColor: 'rgba(18,17,15,0.35)',
  },
});
