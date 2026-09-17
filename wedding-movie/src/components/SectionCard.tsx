import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {useEntrance} from '../motion';
import {SAFE_AREA_PERCENT, safePadding} from '../theme';
import {useTheme} from '../ThemeContext';
import type {Section} from '../types';
import {Decorations} from './Decorations';
import {Diamond, Rule} from './Ornament';

const pad2 = (n: number) => String(n).padStart(2, '0');

/** 章の扉。新郎パート・新婦パート・ふたりのパートの切り替わりに挟む。 */
export const SectionCard: React.FC<{
  section: Section;
  sectionNumber: number;
  durationInFrames: number;
}> = ({section, sectionNumber, durationInFrames}) => {
  const theme = useTheme();
  const frame = useCurrentFrame();
  const {height, width} = useVideoConfig();
  const {fonts, colors, title} = theme;

  const bg = colors.section ?? colors.bgDeep;
  const ink = colors.sectionInk ?? colors.ink;
  const dark = Boolean(colors.sectionInk);
  const soft = dark ? ink : colors.inkSoft;
  const accent = dark ? ink : colors.accent;

  const label = useEntrance(0.1);
  const titleIn = useEntrance(0.45);
  const rule = useEntrance(0.8);
  const drift = interpolate(frame, [0, durationInFrames], [1, 1.025], {
    extrapolateRight: 'clamp',
  });

  const bottomLeft = title.layout === 'bottom-left';
  const vertical = title.vertical;

  const labelNode = section.label ? (
    <div
      style={{
        fontFamily: fonts.latin,
        fontWeight: fonts.latinWeight,
        fontStyle: fonts.latinItalic ? 'italic' : 'normal',
        fontSize: height * (bottomLeft ? 0.16 : 0.032) * title.scale,
        lineHeight: 1,
        letterSpacing: bottomLeft ? '0.02em' : '0.42em',
        textTransform: title.uppercase ? 'uppercase' : 'none',
        color: bottomLeft ? accent : accent,
        opacity: label,
        transform: `translateY(${interpolate(label, [0, 1], [12, 0])}px)`,
      }}
    >
      {bottomLeft ? `${pad2(sectionNumber)} ${section.label}` : section.label}
    </div>
  ) : null;

  const titleNode = (
    <div
      style={{
        fontFamily: fonts.display,
        fontWeight: fonts.displayWeight,
        fontSize: height * (bottomLeft ? 0.062 : 0.072) * title.scale,
        letterSpacing: vertical ? '0.32em' : '0.16em',
        lineHeight: 1.3,
        color: ink,
        textAlign: bottomLeft ? 'left' : 'center',
        writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
        opacity: titleIn,
        transform: `translateY(${interpolate(titleIn, [0, 1], [20, 0])}px)`,
      }}
    >
      {section.title}
    </div>
  );

  const rulesNode = theme.decorations.includes('rules') ? (
    <div style={{display: 'flex', alignItems: 'center', gap: width * 0.01}}>
      <Rule width={width * 0.07} progress={rule} />
      <Diamond size={height * 0.01} opacity={rule} />
      <Rule width={width * 0.07} progress={rule} />
    </div>
  ) : vertical ? (
    // 和風は朱の印を置く
    <div
      style={{
        width: height * 0.075,
        height: height * 0.075,
        backgroundColor: colors.accent,
        color: colors.bg,
        fontFamily: fonts.display,
        fontWeight: fonts.displayWeight,
        fontSize: height * 0.03,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        writingMode: 'vertical-rl',
        letterSpacing: '0.1em',
        opacity: rule,
        transform: `scale(${interpolate(rule, [0, 1], [0.6, 1])})`,
      }}
    >
      {pad2(sectionNumber)}
    </div>
  ) : (
    <div
      style={{
        width: width * (bottomLeft ? 0.12 : 0.06),
        height: 2,
        backgroundColor: accent,
        transform: `scaleX(${rule})`,
        transformOrigin: bottomLeft ? 'left' : 'center',
        opacity: 0.9,
      }}
    />
  );

  const subtitleNode = section.subtitle ? (
    <div
      style={{
        fontFamily: fonts.body,
        fontWeight: fonts.bodyWeight,
        fontSize: height * 0.03 * title.scale,
        letterSpacing: '0.12em',
        lineHeight: 1.9,
        color: soft,
        opacity: dark ? 0.8 * rule : rule,
        textAlign: bottomLeft ? 'left' : 'center',
        writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
        maxWidth: '74%',
        whiteSpace: 'pre-line',
      }}
    >
      {section.subtitle}
    </div>
  ) : null;

  return (
    <AbsoluteFill style={{backgroundColor: bg}}>
      <Decorations layer="behind" dark={dark} />
      {vertical ? (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'row-reverse',
            alignItems: 'center',
            justifyContent: 'center',
            gap: width * 0.035,
            transform: `scale(${drift})`,
          }}
        >
          {titleNode}
          {subtitleNode}
          <div style={{alignSelf: 'flex-start', marginTop: height * 0.02}}>{rulesNode}</div>
          <div style={{alignSelf: 'flex-end', writingMode: 'vertical-rl'}}>{labelNode}</div>
        </AbsoluteFill>
      ) : bottomLeft ? (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            justifyContent: 'flex-end',
            gap: height * 0.03,
          }}
        >
          {labelNode}
          {rulesNode}
          {titleNode}
          {subtitleNode}
        </AbsoluteFill>
      ) : (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: height * 0.03,
            transform: `scale(${drift})`,
          }}
        >
          {labelNode}
          {titleNode}
          {rulesNode}
          {subtitleNode}
        </AbsoluteFill>
      )}
      <Decorations layer="front" dark={dark} pageLabel={pad2(sectionNumber)} />
    </AbsoluteFill>
  );
};
