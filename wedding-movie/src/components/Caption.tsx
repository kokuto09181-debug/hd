import React from 'react';
import {interpolate, useVideoConfig} from 'remotion';
import {useTheme} from '../ThemeContext';
import type {PhotoEntry} from '../types';

const pad2 = (n: number) => String(n).padStart(2, '0');

/** 写真の上に添える小さな見出し（年号や年齢）。テーマで見た目が変わる。 */
export const PhotoLabel: React.FC<{
  text: string;
  photoNumber: number;
  align: 'center' | 'left';
  ghost?: boolean;
}> = ({text, photoNumber, align, ghost = false}) => {
  const theme = useTheme();
  const {height} = useVideoConfig();
  const {labelStyle} = theme.caption;
  const {fonts, colors} = theme;

  if (labelStyle === 'pill') {
    return (
      <div
        style={{
          display: 'inline-block',
          fontFamily: fonts.body,
          fontWeight: 700,
          fontSize: height * 0.024,
          letterSpacing: '0.08em',
          color: '#FFFFFF',
          backgroundColor: colors.accent,
          borderRadius: 999,
          padding: `${height * 0.008}px ${height * 0.022}px`,
        }}
      >
        {text}
      </div>
    );
  }

  if (labelStyle === 'stamp') {
    return (
      <div
        style={{
          display: 'inline-block',
          fontFamily: fonts.latin,
          fontWeight: fonts.latinWeight,
          fontSize: height * 0.024,
          letterSpacing: '0.12em',
          textTransform: 'uppercase',
          color: colors.accent,
          border: `1.5px solid ${colors.accent}`,
          padding: `${height * 0.005}px ${height * 0.014}px`,
          transform: 'rotate(-2deg)',
          opacity: 0.9,
        }}
      >
        {text}
      </div>
    );
  }

  if (labelStyle === 'number') {
    if (ghost) {
      // 雑誌風。大きな番号を薄く敷いて、その上にラベルを載せる
      return (
        <div style={{position: 'relative', lineHeight: 1}}>
          <div
            style={{
              fontFamily: fonts.latin,
              fontWeight: fonts.latinWeight,
              fontSize: height * 0.3,
              lineHeight: 0.85,
              color: colors.ink,
              opacity: 0.08,
              letterSpacing: '-0.02em',
            }}
          >
            {pad2(photoNumber)}
          </div>
          <div
            style={{
              position: 'absolute',
              left: 0,
              bottom: 0,
              fontFamily: fonts.latin,
              fontWeight: fonts.latinWeight,
              fontSize: height * 0.026,
              letterSpacing: '0.22em',
              textTransform: 'uppercase',
              color: colors.accent,
              borderLeft: `4px solid ${colors.accent}`,
              paddingLeft: height * 0.014,
            }}
          >
            {text}
          </div>
        </div>
      );
    }
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'baseline',
          gap: height * 0.016,
          justifyContent: align === 'center' ? 'center' : 'flex-start',
        }}
      >
        <span
          style={{
            fontFamily: fonts.latin,
            fontWeight: fonts.latinWeight,
            fontSize: height * 0.05,
            lineHeight: 1,
            color: colors.ink,
          }}
        >
          {pad2(photoNumber)}
        </span>
        <span
          style={{
            fontFamily: fonts.latin,
            fontWeight: fonts.latinWeight,
            fontSize: height * 0.022,
            letterSpacing: '0.24em',
            textTransform: 'uppercase',
            color: colors.inkSoft,
          }}
        >
          {text}
        </span>
      </div>
    );
  }

  if (labelStyle === 'plain') {
    return (
      <div
        style={{
          fontFamily: fonts.latin,
          fontWeight: fonts.latinWeight,
          fontStyle: fonts.latinItalic ? 'italic' : 'normal',
          fontSize: height * 0.03,
          letterSpacing: '0.08em',
          color: colors.accent,
        }}
      >
        {text}
      </div>
    );
  }

  // spaced（既定）
  return (
    <div
      style={{
        fontFamily: fonts.latin,
        fontWeight: fonts.latinWeight,
        fontSize: height * 0.028,
        letterSpacing: '0.22em',
        textTransform: theme.title.uppercase ? 'uppercase' : 'none',
        color: colors.accent,
      }}
    >
      {text}
    </div>
  );
};

/** 見出し＋本文コメントのひとかたまり。下から入ってくる。 */
export const Caption: React.FC<{
  photo: PhotoEntry;
  align: 'center' | 'left';
  progress: number;
  photoNumber: number;
  ghostNumber?: boolean;
  /** 暗い地の上に置くとき（overlay など） */
  onDark?: boolean;
  /** 見出しを外側で描くとき（縦書きなど）は false */
  showLabel?: boolean;
}> = ({photo, align, progress, photoNumber, ghostNumber = false, onDark = false, showLabel = true}) => {
  const theme = useTheme();
  const {height} = useVideoConfig();
  const {fonts, colors, caption} = theme;
  const inkColor = onDark ? theme.colors.sectionInk ?? '#FFFFFF' : colors.ink;

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: align === 'center' ? 'center' : 'flex-start',
        justifyContent: 'center',
        gap: height * 0.02,
        opacity: progress,
        transform: `translateY(${interpolate(progress, [0, 1], [height * 0.03, 0])}px)`,
      }}
    >
      {showLabel && photo.label ? (
        <PhotoLabel
          text={photo.label}
          photoNumber={photoNumber}
          align={align}
          ghost={ghostNumber}
        />
      ) : null}
      {photo.caption ? (
        <div
          style={{
            fontFamily: fonts.body,
            fontWeight: fonts.bodyWeight,
            fontSize: height * 0.042 * caption.scale,
            lineHeight: 1.65,
            letterSpacing: '0.06em',
            color: inkColor,
            textAlign: align,
            whiteSpace: 'pre-line',
          }}
        >
          {photo.caption}
        </div>
      ) : null}
    </div>
  );
};
