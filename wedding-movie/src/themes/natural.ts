import type {Theme} from './types';

/** 手書き風の文字と葉のあしらい。ガーデンウェディング向け。 */
export const natural: Theme = {
  id: 'natural',
  name: 'ナチュラル',
  tagline: '手書き風の文字と葉のあしらい。やわらかい',
  colors: {
    bg: '#F8F5EE',
    bgDeep: '#E7EBDF',
    ink: '#45483E',
    inkSoft: '#7F8577',
    accent: '#7D8F6B',
    accent2: '#C9A27E',
    veil: 'rgba(248,245,238,0.8)',
    frame: '#FFFFFF',
  },
  fonts: {
    display: '"Klee One", serif',
    displayWeight: 600,
    body: '"Klee One", serif',
    bodyWeight: 400,
    latin: '"Playfair Display", serif',
    latinWeight: 400,
    latinItalic: true,
  },
  photo: {
    frame: 'rounded',
    backdrop: 'solid',
    kenBurns: 1.04,
    zoomMode: 'crop',
    tilt: false,
    filter: 'saturate(0.95) brightness(1.02)',
  },
  caption: {placement: 'side-auto', align: 'center', labelStyle: 'plain', scale: 1.02},
  transition: {kind: 'fade', seconds: 0.9},
  decorations: ['botanical'],
  motion: 'gentle',
  title: {vertical: false, uppercase: false, scale: 1, layout: 'center'},
};
