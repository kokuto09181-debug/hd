import type {Theme} from './types';

/** 和紙に藍と朱。縦書きの章扉。 */
export const wa: Theme = {
  id: 'wa',
  name: '和モダン',
  tagline: '和紙に藍と朱。縦書きの章扉',
  colors: {
    bg: '#F3EFE6',
    bgDeep: '#1E2A47',
    ink: '#1C1C1C',
    inkSoft: '#6B6B66',
    accent: '#B8432E',
    accent2: '#1E2A47',
    section: '#1E2A47',
    sectionInk: '#F3EFE6',
    veil: 'rgba(243,239,230,0.88)',
    frame: '#F3EFE6',
  },
  fonts: {
    display: '"Shippori Mincho", serif',
    displayWeight: 700,
    body: '"Shippori Mincho", serif',
    bodyWeight: 500,
    latin: '"Cormorant Garamond", serif',
    latinWeight: 300,
    latinItalic: false,
  },
  photo: {
    frame: 'hairline',
    backdrop: 'solid',
    kenBurns: 1.03,
    zoomMode: 'scale',
    tilt: false,
    filter: 'saturate(0.9)',
  },
  caption: {placement: 'below', align: 'center', labelStyle: 'vertical', scale: 1},
  transition: {kind: 'wipe', seconds: 0.7},
  decorations: ['circle'],
  motion: 'slow',
  title: {vertical: true, uppercase: false, scale: 1, layout: 'center'},
};
