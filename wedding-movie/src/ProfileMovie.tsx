import {linearTiming, TransitionSeries} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import React from 'react';
import {AbsoluteFill} from 'remotion';
import {EndCard} from './components/EndCard';
import {PhotoSlide} from './components/PhotoSlide';
import {SectionCard} from './components/SectionCard';
import {TitleCard} from './components/TitleCard';
import {theme} from './theme';
import {buildScenes, transitionInFrames} from './timeline';
import type {MovieConfig} from './types';

const renderScene = (
  scene: ReturnType<typeof buildScenes>[number],
  config: MovieConfig,
  index: number,
) => {
  switch (scene.kind) {
    case 'opening':
      return (
        <TitleCard opening={config.opening} durationInFrames={scene.durationInFrames} />
      );
    case 'section':
      return (
        <SectionCard section={scene.section} durationInFrames={scene.durationInFrames} />
      );
    case 'photo':
      return (
        <PhotoSlide
          photo={scene.photo}
          durationInFrames={scene.durationInFrames}
          index={index}
        />
      );
    case 'ending':
      return <EndCard ending={config.ending} durationInFrames={scene.durationInFrames} />;
  }
};

export const ProfileMovie: React.FC<{config: MovieConfig}> = ({config}) => {
  const scenes = buildScenes(config);
  const transition = transitionInFrames(config);

  return (
    <AbsoluteFill style={{backgroundColor: theme.paper}}>
      <TransitionSeries>
        {scenes.map((scene, index) => (
          <React.Fragment key={scene.key}>
            {index > 0 ? (
              <TransitionSeries.Transition
                presentation={fade()}
                timing={linearTiming({durationInFrames: transition})}
              />
            ) : null}
            <TransitionSeries.Sequence durationInFrames={scene.durationInFrames}>
              {renderScene(scene, config, index)}
            </TransitionSeries.Sequence>
          </React.Fragment>
        ))}
      </TransitionSeries>
    </AbsoluteFill>
  );
};
