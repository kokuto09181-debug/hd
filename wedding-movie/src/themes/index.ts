import {cinema} from './cinema';
import {classic} from './classic';
import {editorial} from './editorial';
import {minimal} from './minimal';
import {natural} from './natural';
import {pop} from './pop';
import type {Theme} from './types';
import {vintage} from './vintage';
import {wa} from './wa';

export const themes: Theme[] = [classic, cinema, natural, vintage, minimal, pop, wa, editorial];

export const themeIds = themes.map((theme) => theme.id);

export const getTheme = (id: string | undefined): Theme => {
  const found = themes.find((theme) => theme.id === id);
  if (!found) {
    throw new Error(
      `テーマ "${id}" はありません。使えるのは: ${themeIds.join(', ')}`,
    );
  }
  return found;
};

export type {Theme} from './types';

/** 地の色が暗いテーマか。文字色や網の向きを決めるのに使う。 */
export const isDarkTheme = (theme: Theme): boolean => {
  const hex = theme.colors.bg.replace('#', '');
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 < 0.5;
};
