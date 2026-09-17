import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {useEntrance} from '../motion';
import {SAFE_AREA_PERCENT, safePadding} from '../theme';
import {useTheme} from '../ThemeContext';
import type {MovieConfig} from '../types';
import {Decorations} from './Decorations';
import {Diamond, Rule} from './Ornament';

/** エンディング。感謝の言葉を1行ずつ置いて、最後に静かに引く。 */
export const EndCard: React.FC<{
  ending: MovieConfig['ending'];
  durationInFrames: number;
}> = ({ending, durationInFrames}) => {
  const theme = useTheme();
  const frame = useCurrentFrame();
  const {fps, height, width} = useVideoConfig();
  const {fonts, colors, title} = theme;

  // 最後の1.4秒で文字を引かせ、暗転ではなく余韻で終わらせる
  const fadeOutStart = durationInFrames - Math.round(fps * 1.4);
  const fadeOut = interpolate(frame, [fadeOutStart, durationInFrames - 1], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const label = useEntrance(0.2);
  const signature = useEntrance(0.6 + ending.lines.length * 0.55);
  const bottomLeft = title.layout === 'bottom-left';
  const vertical = title.vertical;
  const align = bottomLeft ? 'flex-start' : 'center';
  const textAlign = bottomLeft ? 'left' : 'center';

  const lines = ending.lines.map((line, index) => (
    <Line
      key={index}
      text={line}
      index={index}
      textAlign={textAlign}
      vertical={vertical}
      compact={bottomLeft}
    />
  ));

  // 縦書きは「右上から読み始めて、左下で署名する」並びにする
  if (vertical) {
    return (
      <AbsoluteFill style={{backgroundColor: colors.bg}}>
        <Decorations layer="behind" />
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, SAFE_AREA_PERCENT),
            display: 'flex',
            flexDirection: 'row-reverse',
            alignItems: 'flex-start',
            justifyContent: 'center',
            gap: width * 0.03,
            opacity: fadeOut,
          }}
        >
          {ending.label ? (
            <div
              style={{
                fontFamily: fonts.latin,
                fontWeight: fonts.latinWeight,
                fontSize: height * 0.028,
                letterSpacing: '0.42em',
                color: colors.accent,
                opacity: label,
                writingMode: 'vertical-rl',
                marginRight: width * 0.02,
              }}
            >
              {ending.label}
            </div>
          ) : null}
          {lines}
          <div
            style={{
              alignSelf: 'flex-end',
              display: 'flex',
              flexDirection: 'row-reverse',
              alignItems: 'flex-end',
              gap: width * 0.018,
              marginLeft: width * 0.02,
            }}
          >
            <div
              style={{
                width: 1.5,
                height: height * 0.12,
                backgroundColor: colors.accent,
                transform: `scaleY(${signature})`,
                transformOrigin: 'top',
                alignSelf: 'flex-start',
              }}
            />
            {ending.signature ? (
              <div
                style={{
                  fontFamily: fonts.display,
                  fontWeight: fonts.displayWeight,
                  fontSize: height * 0.05,
                  letterSpacing: '0.2em',
                  color: colors.ink,
                  opacity: signature,
                  writingMode: 'vertical-rl',
                }}
              >
                {ending.signature}
              </div>
            ) : null}
            {ending.date ? (
              <div
                style={{
                  fontFamily: fonts.latin,
                  fontWeight: fonts.latinWeight,
                  fontSize: height * 0.026,
                  letterSpacing: '0.3em',
                  color: colors.accent,
                  opacity: signature,
                  writingMode: 'vertical-rl',
                }}
              >
                {ending.date}
              </div>
            ) : null}
          </div>
        </AbsoluteFill>
        <Decorations layer="front" />
      </AbsoluteFill>
    );
  }

  return (
    <AbsoluteFill style={{backgroundColor: colors.bg}}>
      <Decorations layer="behind" />
      <AbsoluteFill
        style={{
          padding: safePadding(width, height, SAFE_AREA_PERCENT),
          display: 'flex',
          flexDirection: vertical ? 'row-reverse' : 'column',
          alignItems: vertical ? 'center' : align,
          justifyContent: bottomLeft ? 'flex-end' : 'center',
          gap: height * (bottomLeft ? 0.022 : 0.032),
          opacity: fadeOut,
        }}
      >
        {ending.label ? (
          <div
            style={{
              fontFamily: fonts.latin,
              fontWeight: fonts.latinWeight,
              fontStyle: fonts.latinItalic ? 'italic' : 'normal',
              fontSize: height * (bottomLeft ? 0.06 : 0.032) * title.scale,
              lineHeight: 1,
              letterSpacing: bottomLeft ? '0.04em' : '0.42em',
              textTransform: title.uppercase ? 'uppercase' : 'none',
              color: colors.accent,
              opacity: label,
              marginBottom: height * 0.01,
              alignSelf: vertical ? 'flex-end' : undefined,
              writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
            }}
          >
            {ending.label}
          </div>
        ) : null}

        {lines}

        <div
          style={{
            display: 'flex',
            flexDirection: vertical ? 'column' : 'row',
            alignItems: 'center',
            gap: width * 0.01,
            marginTop: vertical ? 0 : height * 0.03,
            alignSelf: vertical ? 'flex-start' : undefined,
          }}
        >
          {theme.decorations.includes('rules') ? (
            <>
              <Rule width={width * 0.06} progress={signature} />
              <Diamond size={height * 0.009} opacity={signature} />
              <Rule width={width * 0.06} progress={signature} />
            </>
          ) : (
            <div
              style={{
                width: vertical ? 2 : width * (bottomLeft ? 0.12 : 0.05),
                height: vertical ? height * 0.08 : 2,
                backgroundColor: colors.accent,
                transform: vertical ? `scaleY(${signature})` : `scaleX(${signature})`,
                transformOrigin: bottomLeft ? 'left' : 'center',
              }}
            />
          )}
        </div>

        {ending.signature ? (
          <div
            style={{
              fontFamily: fonts.display,
              fontWeight: fonts.displayWeight,
              fontSize: height * 0.05 * title.scale,
              letterSpacing: '0.16em',
              color: colors.ink,
              opacity: signature,
              writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
            }}
          >
            {ending.signature}
          </div>
        ) : null}

        {ending.date ? (
          <div
            style={{
              fontFamily: fonts.latin,
              fontWeight: fonts.latinWeight,
              fontSize: height * 0.028,
              letterSpacing: '0.3em',
              color: colors.accent,
              opacity: signature,
              writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
            }}
          >
            {ending.date}
          </div>
        ) : null}
      </AbsoluteFill>
      <Decorations layer="front" />
    </AbsoluteFill>
  );
};

const Line: React.FC<{
  text: string;
  index: number;
  textAlign: 'left' | 'center';
  vertical: boolean;
  compact?: boolean;
}> = ({text, index, textAlign, vertical, compact = false}) => {
  const theme = useTheme();
  const {height} = useVideoConfig();
  const progress = useEntrance(0.6 + index * 0.55);
  return (
    <div
      style={{
        fontFamily: theme.fonts.body,
        fontWeight: theme.fonts.bodyWeight,
        fontSize: height * (vertical ? 0.038 : compact ? 0.038 : 0.044) * theme.caption.scale,
        lineHeight: vertical ? 2.1 : compact ? 1.6 : 1.8,
        letterSpacing: vertical ? '0.06em' : '0.1em',
        color: theme.colors.ink,
        textAlign,
        maxWidth: '84%',
        whiteSpace: 'pre-line',
        writingMode: vertical ? 'vertical-rl' : 'horizontal-tb',
        opacity: progress,
        transform: `translateY(${interpolate(progress, [0, 1], [16, 0])}px)`,
      }}
    >
      {text}
    </div>
  );
};
