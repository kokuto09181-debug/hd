import type {Theme} from './types';

/** 真っ白に極細のゴシック。余白で見せる。 */
export const minimal: Theme = {
  id: 'minimal',
  name: 'ミニマル',
  tagline: '白に極細の文字。余白で見せる',
  colors: {
    bg: '#FFFFFF',
    bgDeep: '#F3F3F1',
    ink: '#141414',
    inkSoft: '#8A8A8A',
    accent: '#141414',
    accent2: '#D9D9D9',
    veil: 'rgba(255,255,255,0.85)',
    frame: '#FFFFFF',
  },
  fonts: {
    display: '"Zen Kaku Gothic New", sans-serif',
    displayWeight: 300,
    body: '"Zen Kaku Gothic New", sans-serif',
    bodyWeight: 300,
    latin: '"DM Sans", sans-serif',
    latinWeight: 300,
    latinItalic: false,
  },
  photo: {
    frame: 'none',
    backdrop: 'solid',
    kenBurns: 1.0,
    zoomMode: 'scale',
    tilt: false,
    filter: 'none',
  },
  caption: {placement: 'below', align: 'left', labelStyle: 'number', scale: 0.95},
  transition: {kind: 'slide', seconds: 0.55},
  decorations: ['grid'],
  motion: 'gentle',
  title: {vertical: false, uppercase: true, scale: 1.15, layout: 'bottom-left'},
};
