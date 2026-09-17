import type {Theme} from './types';

/** 退色した写真をポラロイドに。フィルムの粒子とタイプライタ。 */
export const vintage: Theme = {
  id: 'vintage',
  name: 'ヴィンテージ',
  tagline: 'ポラロイドとフィルムの粒子。懐かしい',
  colors: {
    bg: '#EDE3D1',
    bgDeep: '#DCCBB0',
    ink: '#4A3A2E',
    inkSoft: '#85705C',
    accent: '#B0583E',
    accent2: '#8C7A5B',
    veil: 'rgba(237,227,209,0.7)',
    frame: '#FBF8F1',
  },
  fonts: {
    display: '"Shippori Mincho", serif',
    displayWeight: 700,
    body: '"Shippori Mincho", serif',
    bodyWeight: 500,
    latin: '"Courier Prime", monospace',
    latinWeight: 700,
    latinItalic: false,
  },
  photo: {
    frame: 'polaroid',
    backdrop: 'paper',
    kenBurns: 1.06,
    zoomMode: 'crop',
    tilt: true,
    filter: 'sepia(0.32) contrast(0.94) saturate(0.82) brightness(1.02)',
  },
  caption: {placement: 'side-auto', align: 'center', labelStyle: 'stamp', scale: 1},
  transition: {kind: 'fade', seconds: 0.6},
  decorations: ['grain', 'vignette'],
  motion: 'gentle',
  title: {vertical: false, uppercase: true, scale: 1, layout: 'center'},
};
