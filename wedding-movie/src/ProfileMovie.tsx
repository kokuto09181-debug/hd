import {linearTiming, springTiming, TransitionSeries} from '@remotion/transitions';
import type {TransitionPresentation} from '@remotion/transitions';
import {clockWipe} from '@remotion/transitions/clock-wipe';
import {fade} from '@remotion/transitions/fade';
import {iris} from '@remotion/transitions/iris';
import {none} from '@remotion/transitions/none';
import {slide} from '@remotion/transitions/slide';
import {wipe} from '@remotion/transitions/wipe';
import React from 'react';
import {AbsoluteFill} from 'remotion';
import {EndCard} from './components/EndCard';
import {PhotoSlide} from './components/PhotoSlide';
import {SectionCard} from './components/SectionCard';
import {TitleCard} from './components/TitleCard';
import {ThemeProvider} from './ThemeContext';
import {getTheme} from './themes';
import type {Theme} from './themes/types';
import {buildScenes, transitionInFrames} from './timeline';
import type {MovieConfig} from './types';

// 各プレゼンテーションの props 型が違うので、ここだけ緩める
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyPresentation = TransitionPresentation<any>;

const presentationFor = (
  theme: Theme,
  width: number,
  height: number,
  index: number,
): AnyPresentation => {
  switch (theme.transition.kind) {
    case 'slide':
      return slide({direction: index % 2 === 0 ? 'from-right' : 'from-left'});
    case 'wipe':
      return wipe({direction: 'from-left'});
    case 'clockWipe':
      return clockWipe({width, height});
    case 'iris':
      return iris({width, height});
    case 'none':
      return none();
    default:
      return fade();
  }
};

const timingFor = (theme: Theme, frames: number) =>
  theme.motion === 'springy'
    ? springTiming({config: {damping: 200}, durationInFrames: frames})
    : linearTiming({durationInFrames: frames});

export const ProfileMovie: React.FC<{config: MovieConfig}> = ({config}) => {
  // テーマは映像の設定より優先。テーマの遷移秒数を使う
  const theme = getTheme(config.theme ?? 'classic');
  const effective: MovieConfig = {...config, transitionInSeconds: theme.transition.seconds};
  const scenes = buildScenes(effective);
  const transition = transitionInFrames(effective);
  const totalPhotos = scenes.filter((scene) => scene.kind === 'photo').length;
  const {width, height} = config.video;

  let photoNumber = 0;
  let sectionNumber = 0;

  return (
    <ThemeProvider theme={theme}>
      <AbsoluteFill style={{backgroundColor: theme.colors.bg}}>
        <TransitionSeries>
          {scenes.map((scene, index) => {
            let node: React.ReactNode;
            switch (scene.kind) {
              case 'opening':
                node = (
                  <TitleCard opening={config.opening} durationInFrames={scene.durationInFrames} />
                );
                break;
              case 'section':
                sectionNumber++;
                node = (
                  <SectionCard
                    section={scene.section}
                    sectionNumber={sectionNumber}
                    durationInFrames={scene.durationInFrames}
                  />
                );
                break;
              case 'photo':
                photoNumber++;
                node = (
                  <PhotoSlide
                    photo={scene.photo}
                    durationInFrames={scene.durationInFrames}
                    index={index}
                    photoNumber={photoNumber}
                    totalPhotos={totalPhotos}
                  />
                );
                break;
              case 'ending':
                node = (
                  <EndCard ending={config.ending} durationInFrames={scene.durationInFrames} />
                );
                break;
            }
            return (
              <React.Fragment key={scene.key}>
                {index > 0 ? (
                  <TransitionSeries.Transition
                    presentation={presentationFor(theme, width, height, index)}
                    timing={timingFor(theme, transition)}
                  />
                ) : null}
                <TransitionSeries.Sequence durationInFrames={scene.durationInFrames}>
                  {node}
                </TransitionSeries.Sequence>
              </React.Fragment>
            );
          })}
        </TransitionSeries>
      </AbsoluteFill>
    </ThemeProvider>
  );
};
