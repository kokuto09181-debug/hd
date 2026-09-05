import React from 'react';
import {theme} from '../theme';

/** 章タイトルなどの下に敷く、中央から開く細い罫。 */
export const Rule: React.FC<{width: number; progress: number; thickness?: number}> = ({
  width,
  progress,
  thickness = 1,
}) => {
  return (
    <div
      style={{
        width,
        height: thickness,
        backgroundColor: theme.accent,
        transform: `scaleX(${progress})`,
        opacity: 0.85,
      }}
    />
  );
};

/** 罫の中央に置く小さな菱形。 */
export const Diamond: React.FC<{size: number; opacity: number}> = ({size, opacity}) => {
  return (
    <div
      style={{
        width: size,
        height: size,
        backgroundColor: theme.accent,
        transform: 'rotate(45deg)',
        opacity,
      }}
    />
  );
};
