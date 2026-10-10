import { WORLD_H, WORLD_W } from '@/features/climbing/simulation/barranco';

/** First row of ground-rock.png and far-mountains.png that actually holds pixels. */
export const ROCK_ROW = 300 / 540;
export const RANGE_ROW = 400 / 540;

export function rockCrop(faceH: number) {
  const imageH = faceH / (1 - ROCK_ROW);
  return { imageH, top: -ROCK_ROW * imageH };
}

export function backdrop(width: number, height: number, cam: number, scale: number) {
  const rangeH = height * 0.62;
  return {
    range: {
      left: -cam * scale * 0.12,
      top: height * 0.36 - rangeH,
      width: width * 1.8,
      height: rangeH,
    },
    valley: {
      left: -cam * scale * 0.28,
      top: height * 0.3,
      width: width * 1.5,
      height: height * 0.42,
    },
  };
}

export function cameraFor(x: number, width: number, height: number) {
  const scale = height / WORLD_H;
  const viewWorld = width / Math.max(scale, 0.001);
  const cam = Math.max(0, Math.min(Math.max(0, WORLD_W - viewWorld), x - viewWorld * 0.36));
  return {
    scale,
    cam,
    sx: (worldX: number) => (worldX - cam) * scale,
  };
}

export function cloudBands(seconds: number, cam: number, width: number, reduced: boolean) {
  return [0, 1, 2].map((index) => {
    const travel = reduced ? 0 : seconds * (10 + index * 4) - cam * 0.18;
    const span = width + 180;
    const left = ((index * 210 + travel) % span + span) % span - 90;
    return {
      left,
      top: 8 + index * 22,
      width: 120 + index * 36,
      opacity: 0.55 + index * 0.1,
    };
  });
}
