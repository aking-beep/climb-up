import { WORLD_H, WORLD_W } from '@/features/climbing/simulation/barranco';

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
