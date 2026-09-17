import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {useTheme} from '../ThemeContext';
import type {Decoration} from '../themes/types';

/** 葉の付いた枝を1本描く。角の飾り用。 */
const Sprig: React.FC<{size: number; color: string; flip?: boolean}> = ({
  size,
  color,
  flip = false,
}) => {
  // 茎に沿って葉を交互に置く
  const leaves = Array.from({length: 7}, (_, i) => {
    const t = 0.15 + i * 0.12;
    const x = 20 + t * 200;
    const y = 180 - t * 150 - Math.sin(t * Math.PI) * 30;
    const side = i % 2 === 0 ? -1 : 1;
    // 茎の向き(約-38°)に対して両側へ45°ずつ開く
    const angle = -38 + side * 48;
    const len = 34 - i * 2.2;
    const wid = 11 - i * 0.7;
    // 先の尖った葉。2本の曲線で描く
    const d = `M0 0 Q ${len * 0.5} ${-wid} ${len} 0 Q ${len * 0.5} ${wid} 0 0 Z`;
    return (
      <path
        key={i}
        d={d}
        transform={`translate(${x} ${y}) rotate(${angle})`}
        fill={color}
        opacity={0.85}
      />
    );
  });
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 240 240"
      style={{transform: flip ? 'scale(-1, -1)' : undefined}}
    >
      <path
        d="M20 180 Q 90 120 200 40"
        stroke={color}
        strokeWidth={2.2}
        fill="none"
        strokeLinecap="round"
      />
      {leaves}
    </svg>
  );
};

/**
 * テーマごとの画面の飾り。写真やカードの上下に重ねる。
 * pageLabel は 'grid' の隅に出す文字（ページ番号など）。
 */
export const Decorations: React.FC<{
  layer: 'behind' | 'front';
  pageLabel?: string;
  dark?: boolean;
}> = ({layer, pageLabel, dark = false}) => {
  const theme = useTheme();
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const ink = dark ? theme.colors.sectionInk ?? theme.colors.bg : theme.colors.ink;

  const has = (d: Decoration) => theme.decorations.includes(d);

  return (
    <>
      {layer === 'behind' && has('blobs') ? (
        <AbsoluteFill style={{overflow: 'hidden'}}>
          {[
            {c: theme.colors.accent2, x: -0.08, y: -0.18, r: 0.34, s: 1},
            {c: theme.colors.bgDeep, x: 0.86, y: 0.62, r: 0.36, s: 1.4},
            {c: theme.colors.accent, x: 0.9, y: -0.14, r: 0.16, s: 0.8},
          ].map((b, i) => (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: width * b.x + Math.sin(frame / (40 * b.s)) * 14,
                top: height * b.y + Math.cos(frame / (46 * b.s)) * 14,
                width: height * b.r * 2,
                height: height * b.r * 2,
                borderRadius: '50%',
                backgroundColor: b.c,
                opacity: 0.55,
              }}
            />
          ))}
        </AbsoluteFill>
      ) : null}

      {layer === 'behind' && has('circle') ? (
        <AbsoluteFill style={{overflow: 'hidden'}}>
          <div
            style={{
              position: 'absolute',
              left: width * 0.62,
              top: -height * 0.18,
              width: height * 0.9,
              height: height * 0.9,
              borderRadius: '50%',
              backgroundColor: dark ? theme.colors.bg : theme.colors.accent,
              opacity: dark ? 0.08 : 0.07,
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: width * 0.62 + height * 0.06,
              top: -height * 0.12,
              width: height * 0.78,
              height: height * 0.78,
              borderRadius: '50%',
              border: `1.5px solid ${dark ? theme.colors.bg : theme.colors.accent}`,
              opacity: 0.35,
            }}
          />
        </AbsoluteFill>
      ) : null}

      {layer === 'behind' && has('botanical') ? (
        <AbsoluteFill>
          <div style={{position: 'absolute', left: width * 0.015, top: height * 0.02}}>
            <Sprig size={height * 0.26} color={theme.colors.accent} />
          </div>
          <div
            style={{
              position: 'absolute',
              right: width * 0.015,
              bottom: height * 0.02,
            }}
          >
            <Sprig size={height * 0.26} color={theme.colors.accent} flip />
          </div>
        </AbsoluteFill>
      ) : null}

      {layer === 'front' && has('grid') ? (
        <AbsoluteFill>
          <div
            style={{
              position: 'absolute',
              left: width * 0.05,
              right: width * 0.05,
              top: height * 0.05,
              height: 1,
              backgroundColor: ink,
              opacity: 0.35,
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: width * 0.05,
              top: height * 0.062,
              fontFamily: theme.fonts.latin,
              fontWeight: theme.fonts.latinWeight,
              fontSize: height * 0.02,
              letterSpacing: '0.3em',
              color: ink,
              opacity: 0.7,
            }}
          >
            PROFILE MOVIE
          </div>
          {pageLabel ? (
            <div
              style={{
                position: 'absolute',
                right: width * 0.05,
                top: height * 0.062,
                fontFamily: theme.fonts.latin,
                fontWeight: theme.fonts.latinWeight,
                fontSize: height * 0.02,
                letterSpacing: '0.3em',
                color: ink,
                opacity: 0.7,
              }}
            >
              {pageLabel}
            </div>
          ) : null}
        </AbsoluteFill>
      ) : null}

      {layer === 'front' && has('vignette') ? (
        <AbsoluteFill
          style={{
            background: dark
              ? 'radial-gradient(120% 120% at 50% 50%, rgba(0,0,0,0) 50%, rgba(0,0,0,0.55) 100%)'
              : 'radial-gradient(120% 120% at 50% 50%, rgba(0,0,0,0) 55%, rgba(58,49,41,0.14) 100%)',
            pointerEvents: 'none',
          }}
        />
      ) : null}

      {layer === 'front' && has('grain') ? (
        <AbsoluteFill style={{mixBlendMode: 'multiply', opacity: 0.16}}>
          <svg width={width} height={height}>
            <filter id="grain">
              <feTurbulence
                type="fractalNoise"
                baseFrequency="0.9"
                numOctaves="2"
                seed={frame % 40}
                stitchTiles="stitch"
              />
              <feColorMatrix type="saturate" values="0" />
            </filter>
            <rect width={width} height={height} filter="url(#grain)" />
          </svg>
        </AbsoluteFill>
      ) : null}

      {layer === 'front' && has('letterbox') ? (
        <AbsoluteFill>
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              height: height * 0.06,
              backgroundColor: '#000',
            }}
          />
          <div
            style={{
              position: 'absolute',
              bottom: 0,
              left: 0,
              right: 0,
              height: height * 0.06,
              backgroundColor: '#000',
            }}
          />
        </AbsoluteFill>
      ) : null}
    </>
  );
};
