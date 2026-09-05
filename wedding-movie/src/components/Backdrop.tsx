import React from 'react';
import {AbsoluteFill} from 'remotion';
import {theme} from '../theme';

/** 全シーン共通の紙の地。四隅をわずかに落として写真を中央に引き寄せる。 */
export const Backdrop: React.FC<{children?: React.ReactNode; deep?: boolean}> = ({
  children,
  deep = false,
}) => {
  return (
    <AbsoluteFill style={{backgroundColor: deep ? theme.paperDeep : theme.paper}}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(120% 90% at 50% 42%, rgba(255,253,250,0.9) 0%, rgba(255,253,250,0) 55%), radial-gradient(120% 120% at 50% 50%, rgba(0,0,0,0) 55%, rgba(58,49,41,0.13) 100%)`,
        }}
      />
      {children}
    </AbsoluteFill>
  );
};
