import type {Theme} from './types';

/** 太いゴシックと大きな数字。雑誌の見開きのように。 */
export const editorial: Theme = {
  id: 'editorial',
  name: 'マガジン',
  tagline: '太い文字と大きな数字。雑誌の見開き',
  colors: {
    bg: '#F1F0EC',
    bgDeep: '#0E0E0E',
    ink: '#0E0E0E',
    inkSoft: '#6E6E6E',
    accent: '#E23D2B',
    accent2: '#D8D6CF',
    section: '#0E0E0E',
    sectionInk: '#F1F0EC',
    veil: 'rgba(241,240,236,0.9)',
    frame: '#0E0E0E',
  },
  fonts: {
    display: '"Zen Kaku Gothic New", sans-serif',
    displayWeight: 900,
    body: '"Zen Kaku Gothic New", sans-serif',
    bodyWeight: 400,
    latin: '"Oswald", sans-serif',
    latinWeight: 500,
    latinItalic: false,
  },
  photo: {
    frame: 'none',
    backdrop: 'solid',
    kenBurns: 1.0,
    zoomMode: 'scale',
    tilt: false,
    filter: 'contrast(1.05)',
  },
  caption: {placement: 'side', align: 'left', labelStyle: 'number', scale: 1},
  transition: {kind: 'wipe', seconds: 0.45},
  decorations: ['grid'],
  motion: 'springy',
  title: {vertical: false, uppercase: true, scale: 1.3, layout: 'bottom-left'},
};
