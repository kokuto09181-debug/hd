import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {useEntrance} from '../motion';
import {SAFE_AREA_PERCENT, safePadding} from '../theme';
import {useTheme} from '../ThemeContext';
import type {MovieConfig} from '../types';
import {Decorations} from './Decorations';
import {Diamond, Rule} from './Ornament';

/** オープニング。ふたりの名前と挙式日を出す扉。 */
export const TitleCard: React.FC<{
  opening: MovieConfig['opening'];
  durationInFrames: number;
}> = ({opening, durationInFrames}) => {
  const theme = useTheme();
  const frame = useCurrentFrame();
  const {height, width} = useVideoConfig();
  const {fonts, colors, title} = theme;

  const label = useEntrance(0.15);
  const rule = useEntrance(0.5);
  const names = useEntrance(0.85);
  const date = useEntrance(1.4);

  // 全体をごくゆっくり引く。静止画に見えないための保険
  const drift = interpolate(frame, [0, durationInFrames], [1.03, 1], {
    extrapolateRight: 'clamp',
  });

  const bottomLeft = title.layout === 'bottom-left';
  const vertical = title.vertical;

  const labelNode = opening.label ? (
    <div
      style={{
        fontFamily: fonts.latin,
        fontWeight: fonts.latinWeight,
        fontStyle: fonts.latinItalic ? 'italic' : 'normal',
        fontSize: height * 0.03 * title.scale,
        letterSpacing: bottomLeft ? '0.3em' : '0.4em',
        textTransform: title.uppercase ? 'uppercase' : 'none',
        color: colors.accent,
        opacity: label,
        transform: `translateY(${interpolate(label, [0, 1], [14, 0])}px)`,
      }}
    >
      {opening.label}
    </div>
  ) : null;

  const rulesNode = theme.decorations.includes('rules') ? (
    <div style={{display: 'flex', alignItems: 'center', gap: width * 0.012}}>
      <Rule width={width * 0.09} progress={rule} />
      <Diamond size={height * 0.011} opacity={rule} />
      <Rule width={width * 0.09} progress={rule} />
    </div>
  ) : bottomLeft ? (
    <div
      style={{
        width: width * 0.12,
        height: 2,
        backgroundColor: colors.accent,
        transform: `scaleX(${rule})`,
        transformOrigin: 'left',
      }}
    />
  ) : null;

  const namesNode = (
    <div
      style={{
        fontFamily: fonts.display,
        fontWeight: fonts.displayWeight,
        fontSize: height * (bottomLeft ? 0.13 : 0.085) * title.scale,
        letterSpacing: vertical ? '0.3em' : bottomLeft ? '-0.01em' : '0.14em',
        lineHeight: 1.1,
        color: colors.ink,
        textAlign: bottomLeft ? 'left' : 'center',
        writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
        opacity: names,
        transform: `translateY(${interpolate(names, [0, 1], [24, 0])}px)`,
      }}
    >
      {opening.names}
    </div>
  );

  const titleNode = (
    <div
      style={{
        fontFamily: fonts.body,
        fontWeight: fonts.bodyWeight,
        fontSize: height * 0.034 * title.scale,
        letterSpacing: '0.18em',
        lineHeight: 1.8,
        color: colors.inkSoft,
        textAlign: bottomLeft ? 'left' : 'center',
        writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
        whiteSpace: 'pre-line',
        opacity: names,
      }}
    >
      {opening.title}
    </div>
  );

  const dateNode = opening.date ? (
    <div
      style={{
        fontFamily: fonts.latin,
        fontWeight: fonts.latinWeight,
        fontSize: height * 0.032 * title.scale,
        letterSpacing: '0.3em',
        color: colors.accent,
        opacity: date,
      }}
    >
      {opening.date}
    </div>
  ) : null;

  return (
    <AbsoluteFill style={{backgroundColor: colors.bg}}>
      <Decorations layer="behind" />
      {vertical ? (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'row-reverse',
            alignItems: 'center',
            justifyContent: 'center',
            gap: width * 0.04,
            transform: `scale(${drift})`,
          }}
        >
          {namesNode}
          {titleNode}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: height * 0.03,
              alignSelf: 'flex-end',
            }}
          >
            {labelNode}
            {dateNode}
          </div>
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
          {namesNode}
          {rulesNode}
          <div style={{display: 'flex', alignItems: 'baseline', gap: width * 0.03}}>
            {titleNode}
            {dateNode}
          </div>
        </AbsoluteFill>
      ) : (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: height * 0.035,
            transform: `scale(${drift})`,
          }}
        >
          {labelNode}
          {rulesNode}
          {namesNode}
          {titleNode}
          {dateNode ? <div style={{marginTop: height * 0.02}}>{dateNode}</div> : null}
        </AbsoluteFill>
      )}
      <Decorations layer="front" />
    </AbsoluteFill>
  );
};
