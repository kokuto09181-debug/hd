import React from 'react';
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {ACTION_SAFE_PERCENT, SAFE_AREA_PERCENT, safePadding, theme} from '../theme';
import type {PhotoEntry} from '../types';
import {useImageAspect} from './useImageAspect';

/** これより縦長の写真は、横に余白が空きすぎるので文字を横に置く */
const PORTRAIT_THRESHOLD = 0.92;

const Caption: React.FC<{
  photo: PhotoEntry;
  align: 'center' | 'left';
  progress: number;
}> = ({photo, align, progress}) => {
  const {height} = useVideoConfig();

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: align === 'center' ? 'center' : 'flex-start',
        justifyContent: 'center',
        gap: height * 0.02,
        opacity: progress,
        transform: `translateY(${interpolate(progress, [0, 1], [height * 0.03, 0])}px)`,
      }}
    >
      {align === 'left' ? (
        <div
          style={{
            width: height * 0.06,
            height: 1,
            backgroundColor: theme.accent,
            opacity: 0.85,
            marginBottom: height * 0.005,
          }}
        />
      ) : null}
      {photo.label ? (
        <div
          style={{
            fontFamily: theme.latin,
            fontWeight: 300,
            fontSize: height * 0.028,
            letterSpacing: '0.22em',
            color: theme.accent,
          }}
        >
          {photo.label}
        </div>
      ) : null}
      {photo.caption ? (
        <div
          style={{
            fontFamily: theme.mincho,
            fontWeight: 400,
            fontSize: height * 0.042,
            lineHeight: 1.65,
            letterSpacing: '0.06em',
            color: theme.ink,
            textAlign: align,
            whiteSpace: 'pre-line',
          }}
        >
          {photo.caption}
        </div>
      ) : null}
    </div>
  );
};

/**
 * 写真1枚ぶんのシーン。
 * 前面は contain で写真の全体を見せ、背面に同じ写真をぼかして敷いて余白を埋める。
 * 縦位置の写真だけは文字を横に置いて、左右が間延びしないようにしている。
 */
export const PhotoSlide: React.FC<{
  photo: PhotoEntry;
  durationInFrames: number;
  index: number;
}> = ({photo, durationInFrames, index}) => {
  const frame = useCurrentFrame();
  const {fps, height, width} = useVideoConfig();
  const src = staticFile(photo.src);

  // 写真は多少切れても致命傷ではないので 5%、文字は切れると読めないので 10% の内側に置く
  const textInsetX = (width * (SAFE_AREA_PERCENT - ACTION_SAFE_PERCENT)) / 100;
  const textInsetY = (height * (SAFE_AREA_PERCENT - ACTION_SAFE_PERCENT)) / 100;
  const aspect = useImageAspect(src);

  // ケン・バーンズ。止め絵に見せないための、気づかない程度のゆっくりした寄り。
  const zoom = interpolate(frame, [0, durationInFrames], [1, 1.055], {
    extrapolateRight: 'clamp',
  });

  // コメントは写真から少し遅れて下から入れる
  const captionIn = spring({
    frame: frame - Math.round(fps * 0.25),
    fps,
    config: {damping: 200, mass: 0.6},
    durationInFrames: Math.round(fps * 0.9),
  });

  const hasText = Boolean(photo.label || photo.caption);
  const isPortrait = aspect !== null && aspect < PORTRAIT_THRESHOLD;
  // 縦写真が続いたときに同じ絵にならないよう、左右を交互に入れ替える
  const photoOnLeft = index % 2 === 0;

  const image = (
    <Img
      src={src}
      style={{
        // ケン・バーンズで 5.5% 寄っても枠に収まるよう、素の状態は少し小さく置く
        maxWidth: '94%',
        maxHeight: '94%',
        objectFit: 'contain',
        transform: `scale(${zoom})`,
        filter: 'drop-shadow(0 22px 44px rgba(58,49,41,0.30))',
      }}
    />
  );

  return (
    <AbsoluteFill style={{backgroundColor: theme.paper}}>
      <AbsoluteFill style={{overflow: 'hidden'}}>
        <Img
          src={src}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            transform: `scale(${1.25 * zoom})`,
            filter: 'blur(48px) saturate(1.15)',
          }}
        />
      </AbsoluteFill>
      <AbsoluteFill style={{backgroundColor: 'rgba(244,239,231,0.74)'}} />

      {aspect === null ? null : isPortrait && hasText ? (
        <AbsoluteFill
          style={{
            padding: safePadding(width, height, ACTION_SAFE_PERCENT),
            display: 'flex',
            flexDirection: photoOnLeft ? 'row' : 'row-reverse',
            alignItems: 'center',
            gap: '5%',
          }}
        >
          <div
            style={{
              flex: '0 0 42%',
              height: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minWidth: 0,
            }}
          >
            {image}
          </div>
          <div
            style={{
              flex: 1,
              minWidth: 0,
              // 画面の外側にあたる辺だけ、タイトルセーフまで余白を足す
              paddingRight: photoOnLeft ? textInsetX : 0,
              paddingLeft: photoOnLeft ? 0 : textInsetX,
              paddingBlock: textInsetY,
            }}
          >
            <Caption photo={photo} align="left" progress={captionIn} />
          </div>
        </AbsoluteFill>
      ) : (
        <AbsoluteFill
          style={{
            padding: `${(height * ACTION_SAFE_PERCENT) / 100}px ${
              (width * ACTION_SAFE_PERCENT) / 100
            }px ${(height * SAFE_AREA_PERCENT) / 100}px`,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <div
            style={{
              flex: 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minHeight: 0,
            }}
          >
            {image}
          </div>
          {hasText ? (
            <div
              style={{
                // 3行以上のコメントが来たら、はみ出さずに写真側を詰める
                minHeight: height * 0.19,
                marginTop: height * 0.035,
                flexShrink: 0,
                display: 'flex',
                justifyContent: 'center',
              }}
            >
              <div style={{maxWidth: '84%'}}>
                <Caption photo={photo} align="center" progress={captionIn} />
              </div>
            </div>
          ) : null}
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
};
