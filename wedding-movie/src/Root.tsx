import React from 'react';
import {Composition} from 'remotion';
import movieConfig from '../movie.config.json';
import './fonts';
import {ProfileMovie} from './ProfileMovie';
import {totalDurationInFrames} from './timeline';
import type {MovieConfig} from './types';

const config = movieConfig as MovieConfig;

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="ProfileMovie"
      component={ProfileMovie}
      defaultProps={{config}}
      durationInFrames={totalDurationInFrames(config)}
      fps={config.video.fps}
      width={config.video.width}
      height={config.video.height}
      calculateMetadata={({props}) => {
        // movie.config.json を書き換えたら、尺と解像度は自動で追従する
        const next = props.config;
        return {
          durationInFrames: totalDurationInFrames(next),
          fps: next.video.fps,
          width: next.video.width,
          height: next.video.height,
        };
      }}
    />
  );
};
