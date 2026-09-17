import type {MovieConfig} from './types';

/**
 * テーマを見比べるための短い抜粋。
 * オープニング → 章扉 → 横写真 → 縦写真 → 横写真 → エンディング。
 * 本編の設定から名前や日付を引き継ぎ、写真は先頭の章から3枚だけ使う。
 */
export const buildSampleConfig = (base: MovieConfig, themeId: string): MovieConfig => {
  const section = base.sections[0];
  const pick = (i: number) => section.photos[Math.min(i, section.photos.length - 1)];
  return {
    ...base,
    theme: themeId,
    defaultPhotoDurationInSeconds: 5,
    opening: {...base.opening, durationInSeconds: 5},
    sections: [
      {
        ...section,
        cardDurationInSeconds: 3.5,
        photos: [pick(0), pick(1), pick(3)].map((photo) => ({...photo, durationInSeconds: 5})),
      },
    ],
    ending: {...base.ending, durationInSeconds: 7},
  };
};
