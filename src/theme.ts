import type { Weather } from '@/game/world';

export const ink = '#14110e';
export const inkDeep = '#100e0c';
export const paper = '#f3efe4';
export const paperRaised = '#fffdf8';
export const rust = '#7d2e16';
export const rustInk = '#f6f1e8';
export const body = '#1c1915';
export const muted = '#4a453e';
export const line = 'rgba(26, 22, 18, 0.14)';
export const lost = '#8d2d1f';

export const font = {
  display: 'FrauncesSemi',
  displayBold: 'FrauncesBold',
  italic: 'FrauncesItalic',
  body: 'Outfit',
  bodyMedium: 'OutfitMedium',
  bodySemi: 'OutfitSemi',
};

export const SKY: Record<Weather, readonly [string, string, string]> = {
  clear: ['#1b3346', '#c45c32', '#f0d3b2'],
  rising: ['#243044', '#8d5a3a', '#e0c2a4'],
  whiteout: ['#7f8b96', '#d5dee4', '#f4f7f8'],
  storm: ['#101218', '#2a303a', '#3e3a38'],
};

export function skyInk(weather: Weather): string {
  return weather === 'whiteout' ? '#1c1915' : '#f6f1e8';
}
