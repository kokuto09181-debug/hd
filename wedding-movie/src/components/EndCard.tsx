import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {SAFE_AREA_PERCENT, theme} from '../theme';
import type {MovieConfig} from '../types';
import {Backdrop} from './Backdrop';
import {Diamond, Rule} from './Ornament';

/** エンディング。感謝の言葉を1行ずつ置いて、最後に静かに引く。 */
export const EndCard: React.FC<{
  ending: MovieConfig['ending'];
  durationInFrames: number;
}> = ({ending, durationInFrames}) => {
  const frame = useCurrentFrame();
  const {fps, height, width} = useVideoConfig();

  const at = (delaySeconds: number) =>
    spring({
      frame: frame - Math.round(fps * delaySeconds),
      fps,
      config: {damping: 200, mass: 0.8},
      durationInFrames: Math.round(fps * 1.2),
    });

  // 最後の1.4秒で文字を引かせ、暗転ではなく余韻で終わらせる。
  const fadeOutStart = durationInFrames - Math.round(fps * 1.4);
  const fadeOut = interpolate(frame, [fadeOutStart, durationInFrames - 1], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const label = at(0.2);
  const signature = at(0.6 + ending.lines.length * 0.55);

  return (
    <Backdrop>
      <AbsoluteFill
        style={{
          padding: `${SAFE_AREA_PERCENT}%`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: height * 0.032,
          opacity: fadeOut,
        }}
      >
        {ending.label ? (
          <div
            style={{
              fontFamily: theme.latin,
              fontSize: height * 0.032,
              letterSpacing: '0.42em',
              textTransform: 'uppercase',
              color: theme.accent,
              opacity: label,
              marginBottom: height * 0.01,
            }}
          >
            {ending.label}
          </div>
        ) : null}

        {ending.lines.map((line, index) => {
          const progress = at(0.6 + index * 0.55);
          return (
            <div
              key={index}
              style={{
                fontFamily: theme.mincho,
                fontSize: height * 0.044,
                lineHeight: 1.8,
                letterSpacing: '0.1em',
                color: theme.ink,
                textAlign: 'center',
                maxWidth: '84%',
                whiteSpace: 'pre-line',
                opacity: progress,
                transform: `translateY(${interpolate(progress, [0, 1], [16, 0])}px)`,
              }}
            >
              {line}
            </div>
          );
        })}

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: width * 0.01,
            marginTop: height * 0.03,
          }}
        >
          <Rule width={width * 0.06} progress={signature} />
          <Diamond size={height * 0.009} opacity={signature} />
          <Rule width={width * 0.06} progress={signature} />
        </div>

        {ending.signature ? (
          <div
            style={{
              fontFamily: theme.mincho,
              fontWeight: 600,
              fontSize: height * 0.05,
              letterSpacing: '0.16em',
              color: theme.ink,
              opacity: signature,
            }}
          >
            {ending.signature}
          </div>
        ) : null}

        {ending.date ? (
          <div
            style={{
              fontFamily: theme.latin,
              fontSize: height * 0.028,
              letterSpacing: '0.3em',
              color: theme.accent,
              opacity: signature,
            }}
          >
            {ending.date}
          </div>
        ) : null}
      </AbsoluteFill>
    </Backdrop>
  );
};
