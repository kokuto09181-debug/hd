import type {Theme} from './types';

/** 生成りの紙に明朝。式場で一番外さない王道。 */
export const classic: Theme = {
  id: 'classic',
  name: 'クラシック',
  tagline: '生成りの紙に明朝体。落ち着いた王道',
  colors: {
    bg: '#F4EFE7',
    bgDeep: '#E7DFD3',
    ink: '#3A3129',
    inkSoft: '#7A6E60',
    accent: '#A98C63',
    accent2: '#C9B48F',
    veil: 'rgba(244,239,231,0.74)',
    frame: '#FFFFFF',
  },
  fonts: {
    display: '"Zen Old Mincho", serif',
    displayWeight: 600,
    body: '"Zen Old Mincho", serif',
    bodyWeight: 400,
    latin: '"Cormorant Garamond", serif',
    latinWeight: 300,
    latinItalic: false,
  },
  photo: {
    frame: 'shadow',
    backdrop: 'blur',
    kenBurns: 1.055,
    zoomMode: 'scale',
    tilt: false,
    filter: 'none',
  },
  caption: {placement: 'side-auto', align: 'center', labelStyle: 'spaced', scale: 1},
  transition: {kind: 'fade', seconds: 0.8},
  decorations: ['rules', 'vignette'],
  motion: 'gentle',
  title: {vertical: false, uppercase: true, scale: 1, layout: 'center'},
};
