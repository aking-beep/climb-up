import { campVisible, dayPhase, expeditionHour, groundFor, partyCaption, partyPoses, routeProgress, snowDensity } from './scene';

describe('expedition world', () => {
  test('the day starts in the morning and the phase follows the clock', () => {
    expect(expeditionHour(0)).toBe(9);
    expect(dayPhase(expeditionHour(0))).toBe('day');
    expect(dayPhase(12)).toBe('day');
    expect(dayPhase(18)).toBe('dusk');
    expect(dayPhase(22)).toBe('night');
    expect(dayPhase(expeditionHour(9))).toBe('dusk');
    expect(dayPhase(expeditionHour(13))).toBe('night');
  });

  test('altitude moves the camera from the valley to the summit', () => {
    expect(routeProgress(1400)).toBe(0);
    expect(routeProgress(8849)).toBe(1);
    expect(routeProgress(5000)).toBeGreaterThan(0.4);
    expect(routeProgress(5000)).toBeLessThan(0.6);
    expect(routeProgress(9000)).toBe(1);
  });

  test('ground and camps follow the route without inventing a new one', () => {
    expect(groundFor('valley')).toBe('valley');
    expect(groundFor('forest')).toBe('forest');
    expect(groundFor('moraine')).toBe('rock');
    expect(groundFor('icefall')).toBe('snow');
    expect(groundFor('ridge')).toBe('snow');
    expect(campVisible('approach')).toBe(false);
    expect(campVisible('ebc')).toBe(true);
    expect(campVisible('camp4')).toBe(true);
    expect(campVisible('summit')).toBe(false);
  });

  test('a tired team puts Marco on his knee', () => {
    expect(partyPoses(90, 88)).toEqual(['walk', 'walk', 'walk', 'walk']);
    expect(partyPoses(60, 70)[1]).toBe('lag');
    expect(partyPoses(30, 80)[1]).toBe('kneel');
    expect(partyPoses(80, 20)[1]).toBe('kneel');
    expect(partyCaption(partyPoses(30, 80))).toBe('Marco is down on the rope.');
    expect(partyCaption(partyPoses(90, 88))).toBeNull();
  });

  test('snow belongs to altitude and storms, not the valley on a fair morning', () => {
    expect(snowDensity(1400, 10)).toBe(0);
    expect(snowDensity(6400, 10)).toBeGreaterThan(0.3);
    expect(snowDensity(1400, 90)).toBeGreaterThan(0.4);
    expect(snowDensity(8849, 100)).toBeLessThanOrEqual(1);
  });
});
