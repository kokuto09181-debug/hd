import type {Theme} from './types';

/** 黒地に細いゴシック。映画の予告編のような静けさ。 */
export const cinema: Theme = {
  id: 'cinema',
  name: 'シネマ',
  tagline: '黒地に細い文字。映画のような静けさ',
  colors: {
    bg: '#0C0C0E',
    bgDeep: '#000000',
    ink: '#F1EEE8',
    inkSoft: '#9A968F',
    accent: '#C8A45C',
    accent2: '#6E6A62',
    veil: 'rgba(12,12,14,0.62)',
    frame: '#000000',
  },
  fonts: {
    display: '"Zen Kaku Gothic New", sans-serif',
    displayWeight: 300,
    body: '"Zen Kaku Gothic New", sans-serif',
    bodyWeight: 300,
    latin: '"Montserrat", sans-serif',
    latinWeight: 300,
    latinItalic: false,
  },
  photo: {
    frame: 'none',
    backdrop: 'blur-dark',
    kenBurns: 1.09,
    zoomMode: 'scale',
    tilt: false,
    filter: 'contrast(1.04) saturate(0.92)',
  },
  caption: {placement: 'overlay', align: 'left', labelStyle: 'spaced', scale: 0.92},
  transition: {kind: 'fade', seconds: 1.2},
  decorations: ['letterbox', 'vignette'],
  motion: 'slow',
  title: {vertical: false, uppercase: true, scale: 1.05, layout: 'center'},
};
