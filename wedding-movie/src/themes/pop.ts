import type {Theme} from './types';

/** 丸ゴシックと明るい色。弾む動き。 */
export const pop: Theme = {
  id: 'pop',
  name: 'ポップ',
  tagline: '丸い文字と明るい色。弾む',
  colors: {
    bg: '#FFF8E8',
    bgDeep: '#FFE9A8',
    ink: '#2A2A2A',
    inkSoft: '#6B6B6B',
    accent: '#FF6B6B',
    accent2: '#4ECDC4',
    section: '#FF6B6B',
    sectionInk: '#FFFFFF',
    veil: 'rgba(255,248,232,0.85)',
    frame: '#FFFFFF',
  },
  fonts: {
    display: '"Zen Maru Gothic", sans-serif',
    displayWeight: 900,
    body: '"Zen Maru Gothic", sans-serif',
    bodyWeight: 700,
    latin: '"Nunito", sans-serif',
    latinWeight: 800,
    latinItalic: false,
  },
  photo: {
    frame: 'border',
    backdrop: 'solid',
    kenBurns: 1.05,
    zoomMode: 'crop',
    tilt: true,
    filter: 'saturate(1.08)',
  },
  caption: {placement: 'side-auto', align: 'center', labelStyle: 'pill', scale: 1.05},
  transition: {kind: 'slide', seconds: 0.5},
  decorations: ['blobs'],
  motion: 'springy',
  title: {vertical: false, uppercase: true, scale: 1.1, layout: 'center'},
};
