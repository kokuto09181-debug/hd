import React from 'react';
import {Composition, Folder} from 'remotion';
import movieConfig from '../movie.config.json';
import './fonts';
import {ProfileMovie} from './ProfileMovie';
import {buildSampleConfig} from './sample';
import {getTheme, themes} from './themes';
import {totalDurationInFrames} from './timeline';
import type {MovieConfig} from './types';

const config = movieConfig as MovieConfig;

/** movie.config.json を書き換えたら、尺と解像度は自動で追従する */
const metadata = ({props}: {props: {config: MovieConfig}}) => {
  const next = props.config;
  const theme = getTheme(next.theme ?? 'classic');
  return {
    durationInFrames: totalDurationInFrames({
      ...next,
      transitionInSeconds: theme.transition.seconds,
    }),
    fps: next.video.fps,
    width: next.video.width,
    height: next.video.height,
  };
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="ProfileMovie"
        component={ProfileMovie}
        defaultProps={{config}}
        durationInFrames={1}
        fps={config.video.fps}
        width={config.video.width}
        height={config.video.height}
        calculateMetadata={metadata}
      />
      <Folder name="Themes">
        {themes.map((theme) => (
          <Composition
            key={theme.id}
            id={`Theme-${theme.id}`}
            component={ProfileMovie}
            defaultProps={{config: {...config, theme: theme.id}}}
            durationInFrames={1}
            fps={config.video.fps}
            width={config.video.width}
            height={config.video.height}
            calculateMetadata={metadata}
          />
        ))}
      </Folder>
      <Folder name="Samples">
        {themes.map((theme) => (
          <Composition
            key={theme.id}
            id={`Sample-${theme.id}`}
            component={ProfileMovie}
            defaultProps={{config: buildSampleConfig(config, theme.id)}}
            durationInFrames={1}
            fps={config.video.fps}
            width={config.video.width}
            height={config.video.height}
            calculateMetadata={metadata}
          />
        ))}
      </Folder>
    </>
  );
};
