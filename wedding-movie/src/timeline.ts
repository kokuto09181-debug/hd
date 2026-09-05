import type {MovieConfig, PhotoEntry, Section} from './types';

export type Scene =
  | {key: string; kind: 'opening'; durationInFrames: number}
  | {key: string; kind: 'section'; durationInFrames: number; section: Section}
  | {key: string; kind: 'photo'; durationInFrames: number; photo: PhotoEntry}
  | {key: string; kind: 'ending'; durationInFrames: number};

export const transitionInFrames = (config: MovieConfig) =>
  Math.max(1, Math.round(config.transitionInSeconds * config.video.fps));

/**
 * TransitionSeries は「前後のトランジションの合計より長いシーン」しか受け付けない。
 * 設定で短い秒数を書かれても落ちないよう、ここで下限を当てる。
 */
const clampSceneLength = (frames: number, transition: number) =>
  Math.max(frames, transition * 2 + 1);

export const buildScenes = (config: MovieConfig): Scene[] => {
  const {fps} = config.video;
  const transition = transitionInFrames(config);
  const toFrames = (seconds: number) =>
    clampSceneLength(Math.round(seconds * fps), transition);

  const scenes: Scene[] = [
    {
      key: 'opening',
      kind: 'opening',
      durationInFrames: toFrames(config.opening.durationInSeconds),
    },
  ];

  config.sections.forEach((section, sectionIndex) => {
    scenes.push({
      key: `section-${sectionIndex}`,
      kind: 'section',
      section,
      durationInFrames: toFrames(section.cardDurationInSeconds ?? 4),
    });

    section.photos.forEach((photo: PhotoEntry, photoIndex) => {
      scenes.push({
        key: `photo-${sectionIndex}-${photoIndex}`,
        kind: 'photo',
        photo,
        durationInFrames: toFrames(
          photo.durationInSeconds ?? config.defaultPhotoDurationInSeconds,
        ),
      });
    });
  });

  scenes.push({
    key: 'ending',
    kind: 'ending',
    durationInFrames: toFrames(config.ending.durationInSeconds),
  });

  return scenes;
};

export const totalDurationInFrames = (config: MovieConfig): number => {
  const scenes = buildScenes(config);
  const transition = transitionInFrames(config);
  const sum = scenes.reduce((acc, scene) => acc + scene.durationInFrames, 0);
  // シーンどうしは重ねてつなぐので、重なった分だけ全体は短くなる
  return Math.max(1, sum - transition * Math.max(0, scenes.length - 1));
};
