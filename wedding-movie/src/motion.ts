import {spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {useTheme} from './ThemeContext';

/**
 * 文字や飾りの「入り」。テーマの motion で性格が変わる。
 *   gentle  … すっと入る
 *   slow    … ゆっくり滲むように
 *   springy … 少し行き過ぎて戻る
 */
export const useEntrance = (delaySeconds: number): number => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {motion} = useTheme();

  const delayed = frame - Math.round(fps * delaySeconds);

  if (motion === 'springy') {
    return spring({
      frame: delayed,
      fps,
      config: {damping: 11, stiffness: 130, mass: 0.7},
    });
  }

  const seconds = motion === 'slow' ? 1.6 : 0.9;
  return spring({
    frame: delayed,
    fps,
    config: {damping: 200, mass: motion === 'slow' ? 1.2 : 0.6},
    durationInFrames: Math.round(fps * seconds),
  });
};
