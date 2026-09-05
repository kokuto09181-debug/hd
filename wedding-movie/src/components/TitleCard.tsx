import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {SAFE_AREA_PERCENT, safePadding, theme} from '../theme';
import type {MovieConfig} from '../types';
import {Backdrop} from './Backdrop';
import {Diamond, Rule} from './Ornament';

/** オープニング。ふたりの名前と挙式日を出す扉。 */
export const TitleCard: React.FC<{
  opening: MovieConfig['opening'];
  durationInFrames: number;
}> = ({opening, durationInFrames}) => {
  const frame = useCurrentFrame();
  const {fps, height, width} = useVideoConfig();

  const at = (delaySeconds: number) =>
    spring({
      frame: frame - Math.round(fps * delaySeconds),
      fps,
      config: {damping: 200, mass: 0.7},
      durationInFrames: Math.round(fps * 1.1),
    });

  const label = at(0.15);
  const rule = at(0.5);
  const names = at(0.85);
  const date = at(1.4);

  // 全体をごくゆっくり引く。静止画に見えないための保険。
  const drift = interpolate(frame, [0, durationInFrames], [1.03, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <Backdrop>
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
        {opening.label ? (
          <div
            style={{
              fontFamily: theme.latin,
              fontSize: height * 0.03,
              letterSpacing: '0.4em',
              textTransform: 'uppercase',
              color: theme.accent,
              opacity: label,
              transform: `translateY(${interpolate(label, [0, 1], [14, 0])}px)`,
            }}
          >
            {opening.label}
          </div>
        ) : null}

        <div style={{display: 'flex', alignItems: 'center', gap: width * 0.012}}>
          <Rule width={width * 0.09} progress={rule} />
          <Diamond size={height * 0.011} opacity={rule} />
          <Rule width={width * 0.09} progress={rule} />
        </div>

        <div
          style={{
            fontFamily: theme.mincho,
            fontWeight: 600,
            fontSize: height * 0.085,
            letterSpacing: '0.14em',
            color: theme.ink,
            textAlign: 'center',
            opacity: names,
            transform: `translateY(${interpolate(names, [0, 1], [24, 0])}px)`,
          }}
        >
          {opening.names}
        </div>

        <div
          style={{
            fontFamily: theme.mincho,
            fontSize: height * 0.034,
            letterSpacing: '0.18em',
            lineHeight: 1.8,
            color: theme.inkSoft,
            textAlign: 'center',
            whiteSpace: 'pre-line',
            opacity: names,
          }}
        >
          {opening.title}
        </div>

        {opening.date ? (
          <div
            style={{
              marginTop: height * 0.02,
              fontFamily: theme.latin,
              fontSize: height * 0.032,
              letterSpacing: '0.3em',
              color: theme.accent,
              opacity: date,
            }}
          >
            {opening.date}
          </div>
        ) : null}
      </AbsoluteFill>
    </Backdrop>
  );
};
