import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {SAFE_AREA_PERCENT, theme} from '../theme';
import type {Section} from '../types';
import {Backdrop} from './Backdrop';
import {Diamond, Rule} from './Ornament';

/** 章の扉。新郎パート・新婦パート・ふたりのパートの切り替わりに挟む。 */
export const SectionCard: React.FC<{section: Section; durationInFrames: number}> = ({
  section,
  durationInFrames,
}) => {
  const frame = useCurrentFrame();
  const {fps, height, width} = useVideoConfig();

  const at = (delaySeconds: number) =>
    spring({
      frame: frame - Math.round(fps * delaySeconds),
      fps,
      config: {damping: 200, mass: 0.7},
      durationInFrames: Math.round(fps * 1),
    });

  const label = at(0.1);
  const title = at(0.45);
  const rule = at(0.8);
  const drift = interpolate(frame, [0, durationInFrames], [1, 1.025], {
    extrapolateRight: 'clamp',
  });

  return (
    <Backdrop deep>
      <AbsoluteFill
        style={{
          padding: `${SAFE_AREA_PERCENT}%`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: height * 0.03,
          transform: `scale(${drift})`,
        }}
      >
        {section.label ? (
          <div
            style={{
              fontFamily: theme.latin,
              fontSize: height * 0.032,
              letterSpacing: '0.42em',
              textTransform: 'uppercase',
              color: theme.accent,
              opacity: label,
              transform: `translateY(${interpolate(label, [0, 1], [12, 0])}px)`,
            }}
          >
            {section.label}
          </div>
        ) : null}

        <div
          style={{
            fontFamily: theme.mincho,
            fontWeight: 600,
            fontSize: height * 0.072,
            letterSpacing: '0.16em',
            color: theme.ink,
            textAlign: 'center',
            opacity: title,
            transform: `translateY(${interpolate(title, [0, 1], [20, 0])}px)`,
          }}
        >
          {section.title}
        </div>

        <div style={{display: 'flex', alignItems: 'center', gap: width * 0.01}}>
          <Rule width={width * 0.07} progress={rule} />
          <Diamond size={height * 0.01} opacity={rule} />
          <Rule width={width * 0.07} progress={rule} />
        </div>

        {section.subtitle ? (
          <div
            style={{
              fontFamily: theme.gothic,
              fontSize: height * 0.03,
              letterSpacing: '0.12em',
              lineHeight: 1.9,
              color: theme.inkSoft,
              textAlign: 'center',
              maxWidth: '74%',
              whiteSpace: 'pre-line',
              opacity: rule,
            }}
          >
            {section.subtitle}
          </div>
        ) : null}
      </AbsoluteFill>
    </Backdrop>
  );
};
