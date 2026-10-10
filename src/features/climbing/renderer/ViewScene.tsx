import { LinearGradient } from 'expo-linear-gradient';
import { Image, StyleSheet, View, type ImageStyle } from 'react-native';

import { presentPose } from '@/features/climbing/animation/poses';
import { PLATFORMS, PLAYER_H, PLAYER_W, groundTop } from '@/features/climbing/simulation/barranco';
import type { ClimbWorld } from '@/features/climbing/simulation/types';

import { backdrop, cameraFor, cloudBands, rockCrop } from './camera';

const FAR = require('../../../../assets/world/far-mountains.png');
const VALLEY = require('../../../../assets/world/diorama-desert.jpg');
const ROCK = require('../../../../assets/world/ground-rock.png');
const CLOUDS = require('../../../../assets/world/clouds.png');
const YOU = require('../../../../assets/world/pixel-you.png');
const LENA = require('../../../../assets/world/pixel-lena.png');
const MARCO = require('../../../../assets/world/pixel-marco.png');
const TENT = require('../../../../assets/world/pixel-tent.png');

const pixel = { imageRendering: 'pixelated' } as ImageStyle;

export function ViewScene({
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
  const { scale, cam, sx } = cameraFor(world.x, width, height);
  const pose = presentPose(world);
  const bob = reduced ? 0 : pose.dy;
  const marcoGone = world.hazards.some((hazard) => hazard.endsWith('marco'));
  const windy = world.hazards.includes('wind') && world.y < 180;
  const clouds = cloudBands(world.seconds, cam, width, reduced);
  const layers = backdrop(width, height, cam, scale);

  return (
    <View style={styles.frame} accessibilityLabel={`Barranco scramble, stamina ${Math.round(world.stamina)}`}>
      <LinearGradient colors={['#f0ddc0', '#d7c4a2', '#8ea8ab', '#314047']} style={StyleSheet.absoluteFill} />
      <Image source={FAR} style={{ position: 'absolute', ...layers.range }} />
      {clouds.map((cloud, index) => (
        <Image
          key={index}
          source={CLOUDS}
          style={{
            position: 'absolute',
            left: cloud.left,
            top: cloud.top,
            width: cloud.width,
            height: cloud.width * 0.28,
            opacity: cloud.opacity,
          }}
        />
      ))}
      <Image source={VALLEY} style={[pixel, { position: 'absolute', opacity: 0.94, ...layers.valley }]} />
      <LinearGradient
        colors={['rgba(240,221,192,0)', 'rgba(49,64,71,0.25)']}
        style={{ position: 'absolute', left: 0, right: 0, top: height * 0.34, height: height * 0.22 }}
      />
      {PLATFORMS.map((platform) => {
        const faceH = Math.min(platform.h * scale, height * 0.62);
        const crop = rockCrop(faceH);
        const faceW = platform.w * scale;
        return (
          <View
            key={`${platform.x}-${platform.y}`}
            style={{
              position: 'absolute',
              left: sx(platform.x),
              top: platform.y * scale,
              width: faceW,
              height: faceH,
              overflow: 'hidden',
              backgroundColor: '#6d6458',
            }}
          >
            <Image
              source={ROCK}
              style={{
                position: 'absolute',
                width: faceW * 1.6,
                height: crop.imageH,
                top: crop.top,
                left: -((platform.x * 0.2) % 120),
              }}
            />
            <LinearGradient colors={['rgba(28,22,16,0)', 'rgba(28,22,16,0.4)']} style={StyleSheet.absoluteFill} />
            <View style={{ height: Math.max(5, 7 * scale), backgroundColor: '#d9c4a4' }} />
          </View>
        );
      })}
      <Image source={TENT} style={[styles.tent, pixel, { left: sx(78), top: (groundTop(80) - 34) * scale }]} />
      <Image
        source={TENT}
        style={[styles.tent, pixel, { left: sx(126), top: (groundTop(130) - 30) * scale, opacity: 0.92 }]}
      />
      {!marcoGone ? (
        <Climber
          source={MARCO}
          left={sx(636)}
          top={(160 - PLAYER_H) * scale}
          width={PLAYER_W * scale}
          height={PLAYER_H * scale}
          facing={1}
          bob={0}
          squash={1}
          lean={0}
        />
      ) : null}
      <Climber
        source={LENA}
        left={sx(world.x - 34)}
        top={(world.y + 8 + bob) * scale}
        width={PLAYER_W * scale * 0.86}
        height={PLAYER_H * scale * 0.86 * pose.squash}
        facing={world.facing}
        bob={0}
        squash={pose.squash}
        lean={pose.lean * 0.5}
      />
      <Climber
        source={YOU}
        left={sx(world.x)}
        top={(world.y + bob) * scale}
        width={PLAYER_W * scale}
        height={PLAYER_H * scale * pose.squash}
        facing={world.facing}
        bob={0}
        squash={pose.squash}
        lean={pose.lean}
      />
      {!reduced && windy
        ? [0, 1, 2, 3].map((index) => (
            <View
              key={index}
              style={{
                position: 'absolute',
                left: ((world.seconds * 80 + index * 70) % width) - 20,
                top: height * (0.28 + index * 0.08),
                width: 46,
                height: 2,
                backgroundColor: 'rgba(255,255,255,0.35)',
              }}
            />
          ))
        : null}
      {!reduced ? (
        <View style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: height * 0.14, overflow: 'hidden' }}>
          <Image
            source={ROCK}
            style={{
              position: 'absolute',
              left: -cam * scale * 1.15,
              width: width * 1.8,
              height: rockCrop(height * 0.14).imageH,
              top: rockCrop(height * 0.14).top,
            }}
          />
        </View>
      ) : null}
      <LinearGradient
        colors={['rgba(49,64,71,0)', 'rgba(18,17,15,0.28)']}
        style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 36 }}
      />
    </View>
  );
}

function Climber({
  source,
  left,
  top,
  width,
  height,
  facing,
  lean,
}: {
  source: number;
  left: number;
  top: number;
  width: number;
  height: number;
  facing: number;
  bob: number;
  squash: number;
  lean: number;
}) {
  return (
    <View style={{ position: 'absolute', left, top, width, height }}>
      <View
        style={{
          position: 'absolute',
          left: width * 0.12,
          top: height - 5,
          width: width * 0.76,
          height: 6,
          borderRadius: 6,
          backgroundColor: 'rgba(20,16,12,0.4)',
        }}
      />
      <Image
        source={source}
        style={[
          pixel,
          {
            width,
            height,
            transform: [{ scaleX: facing }, { rotate: `${lean}deg` }],
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  frame: { flex: 1, overflow: 'hidden', backgroundColor: '#314047' },
  tent: { position: 'absolute', width: 54, height: 34 },
});
