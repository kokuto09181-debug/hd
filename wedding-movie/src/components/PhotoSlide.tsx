import React from 'react';
import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {useEntrance} from '../motion';
import {ACTION_SAFE_PERCENT, SAFE_AREA_PERCENT} from '../theme';
import {useTheme} from '../ThemeContext';
import {isDarkTheme} from '../themes';
import type {PhotoEntry} from '../types';
import {Caption} from './Caption';
import {Decorations} from './Decorations';
import {useImageAspect} from './useImageAspect';

/** これより縦長の写真は、横に余白が空きすぎるので文字を横に置く */
const PORTRAIT_THRESHOLD = 0.92;

const pad2 = (n: number) => String(n).padStart(2, '0');

/**
 * 写真1枚ぶんのシーン。
 * 写真の縦横比を先に測って、額・コメント・背景をテーマの指定どおりに組む。
 */
export const PhotoSlide: React.FC<{
  photo: PhotoEntry;
  durationInFrames: number;
  index: number;
  photoNumber: number;
  totalPhotos: number;
}> = ({photo, durationInFrames, index, photoNumber, totalPhotos}) => {
  const theme = useTheme();
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const src = staticFile(photo.src);
  const aspect = useImageAspect(src);
  const dark = isDarkTheme(theme);

  // ケン・バーンズ。止め絵に見せないための、気づかない程度のゆっくりした寄り
  const zoom = interpolate(frame, [0, durationInFrames], [1, theme.photo.kenBurns], {
    extrapolateRight: 'clamp',
  });
  const captionIn = useEntrance(0.25);

  if (aspect === null) {
    return <AbsoluteFill style={{backgroundColor: theme.colors.bg}} />;
  }

  const hasText = Boolean(photo.label || photo.caption);
  const isPortrait = aspect < PORTRAIT_THRESHOLD;

  // --- 置き場所を決める ---
  const padX = (width * ACTION_SAFE_PERCENT) / 100;
  const padY = (height * ACTION_SAFE_PERCENT) / 100;
  const textInsetX = (width * (SAFE_AREA_PERCENT - ACTION_SAFE_PERCENT)) / 100;
  const textInsetY = (height * (SAFE_AREA_PERCENT - ACTION_SAFE_PERCENT)) / 100;
  const letterbox = theme.decorations.includes('letterbox') ? height * 0.06 : 0;
  const safeX = padX;
  const safeY = padY + letterbox;
  const safeW = width - padX * 2;
  const safeH = height - padY * 2 - letterbox * 2;

  const requested = theme.caption.placement;
  const placement: 'below' | 'side' | 'overlay' = !hasText
    ? 'below'
    : requested === 'side-auto'
      ? isPortrait
        ? 'side'
        : 'below'
      : requested;

  const gap = height * 0.035;
  const bandH = height * 0.19 * theme.caption.scale;
  const photoOnLeft = requested === 'side' ? true : index % 2 === 0;
  const colW = safeW * 0.46;

  let area: {x: number; y: number; w: number; h: number};
  if (placement === 'side') {
    area = {
      x: photoOnLeft ? safeX : safeX + safeW - colW,
      y: safeY,
      w: colW,
      h: safeH,
    };
  } else if (placement === 'overlay') {
    area = {x: safeX, y: safeY, w: safeW, h: safeH - (hasText ? height * 0.12 : 0)};
  } else {
    area = {x: safeX, y: safeY, w: safeW, h: safeH - (hasText ? bandH + gap : 0)};
  }

  // --- 額の余白 ---
  const unit = Math.min(area.w, area.h);
  let padT = 0;
  let padR = 0;
  let padB = 0;
  let padL = 0;
  let borderW = 0;
  if (theme.photo.frame === 'polaroid') {
    const p = unit * 0.04;
    padT = padL = padR = p;
    padB = p * 4.2;
  } else if (theme.photo.frame === 'hairline') {
    padT = padR = padB = padL = unit * 0.035;
  } else if (theme.photo.frame === 'border') {
    borderW = Math.round(height * 0.009);
    padT = padR = padB = padL = borderW;
  }

  // 額ごと寄せる場合は、寄り切っても枠に収まるよう素の状態を小さく置く
  const headroom = theme.photo.zoomMode === 'scale' ? 1 / theme.photo.kenBurns : 1;
  const innerW = (area.w - padL - padR) * headroom;
  const innerH = (area.h - padT - padB) * headroom;
  const pw = Math.min(innerW, innerH * aspect);
  const ph = pw / aspect;
  const fw = pw + padL + padR;
  const fh = ph + padT + padB;
  const fx = area.x + (area.w - fw) / 2;
  const fy = area.y + (area.h - fh) / 2;

  const tilt = theme.photo.tilt ? (index % 2 === 0 ? -1.8 : 1.6) : 0;
  const frameTransform = `rotate(${tilt}deg) scale(${theme.photo.zoomMode === 'scale' ? zoom : 1})`;

  const borderColor = index % 2 === 0 ? theme.colors.accent : theme.colors.accent2;
  const frameStyle: React.CSSProperties = (() => {
    switch (theme.photo.frame) {
      case 'shadow':
        return {filter: 'drop-shadow(0 22px 44px rgba(58,49,41,0.30))'};
      case 'polaroid':
        return {
          backgroundColor: theme.colors.frame,
          boxShadow: '0 18px 40px rgba(60,40,20,0.28), 0 2px 6px rgba(60,40,20,0.18)',
        };
      case 'hairline':
        return {
          backgroundColor: theme.colors.frame,
          border: `1px solid ${theme.colors.ink}`,
          boxShadow: '0 10px 30px rgba(0,0,0,0.08)',
        };
      case 'rounded':
        return {
          borderRadius: unit * 0.035,
          overflow: 'hidden',
          boxShadow: '0 20px 50px rgba(70,72,62,0.22)',
        };
      case 'border':
        return {
          borderRadius: unit * 0.05,
          overflow: 'hidden',
          backgroundColor: borderColor,
          boxShadow: '0 16px 36px rgba(0,0,0,0.14)',
        };
      default:
        return {};
    }
  })();

  const innerRadius =
    theme.photo.frame === 'border' ? Math.max(0, unit * 0.05 - borderW) : 0;

  const image = (
    <div
      style={{
        position: 'absolute',
        left: fx,
        top: fy,
        width: fw,
        height: fh,
        transform: frameTransform,
        transformOrigin: 'center',
        ...frameStyle,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: padL,
          top: padT,
          width: pw,
          height: ph,
          overflow: 'hidden',
          borderRadius: innerRadius,
        }}
      >
        <Img
          src={src}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
            filter: theme.photo.filter,
            transform: theme.photo.zoomMode === 'crop' ? `scale(${zoom})` : undefined,
          }}
        />
      </div>
    </div>
  );

  const verticalLabel =
    hasText && theme.caption.labelStyle === 'vertical' && photo.label ? (
      <div
        style={{
          position: 'absolute',
          left: fx + fw + height * 0.022,
          top: fy,
          writingMode: 'vertical-rl',
          textOrientation: 'mixed',
          fontFamily: theme.fonts.display,
          fontWeight: theme.fonts.displayWeight,
          fontSize: height * 0.028,
          letterSpacing: '0.24em',
          color: theme.colors.accent,
          opacity: captionIn,
        }}
      >
        {photo.label}
      </div>
    ) : null;

  const captionNode = (() => {
    if (!hasText) return null;
    const common = {
      photo,
      progress: captionIn,
      photoNumber,
      showLabel: theme.caption.labelStyle !== 'vertical',
    };
    if (placement === 'side') {
      return (
        <div
          style={{
            position: 'absolute',
            top: safeY + textInsetY,
            bottom: safeY + textInsetY,
            left: photoOnLeft ? safeX + colW + safeW * 0.06 : safeX + textInsetX,
            right: photoOnLeft ? safeX + textInsetX : safeX + colW + safeW * 0.06,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <Caption
            {...common}
            align="left"
            ghostNumber={theme.caption.labelStyle === 'number' && requested === 'side'}
          />
        </div>
      );
    }
    if (placement === 'overlay') {
      return (
        <>
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.42,
              background: dark
                ? 'linear-gradient(to top, rgba(0,0,0,0.78), rgba(0,0,0,0))'
                : `linear-gradient(to top, ${theme.colors.bg}, rgba(255,255,255,0))`,
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: safeX + textInsetX,
              bottom: safeY + textInsetY,
              maxWidth: '58%',
              display: 'flex',
              gap: height * 0.024,
            }}
          >
            <div
              style={{
                width: 2,
                backgroundColor: theme.colors.accent,
                opacity: captionIn,
                alignSelf: 'stretch',
              }}
            />
            <Caption {...common} align="left" onDark={dark} />
          </div>
        </>
      );
    }
    return (
      <div
        style={{
          position: 'absolute',
          left: safeX + textInsetX,
          right: safeX + textInsetX,
          top: area.y + area.h + gap,
          bottom: safeY + textInsetY,
          display: 'flex',
          alignItems: 'center',
          justifyContent: theme.caption.align === 'center' ? 'center' : 'flex-start',
        }}
      >
        <div style={{maxWidth: theme.caption.align === 'center' ? '84%' : '70%'}}>
          <Caption {...common} align={theme.caption.align} />
        </div>
      </div>
    );
  })();

  return (
    <AbsoluteFill style={{backgroundColor: theme.colors.bg}}>
      {theme.photo.backdrop === 'blur' || theme.photo.backdrop === 'blur-dark' ? (
        <>
          <AbsoluteFill style={{overflow: 'hidden'}}>
            <Img
              src={src}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'cover',
                transform: `scale(${1.25 * zoom})`,
                filter: `blur(48px) saturate(1.15)${
                  theme.photo.backdrop === 'blur-dark' ? ' brightness(0.7)' : ''
                }`,
              }}
            />
          </AbsoluteFill>
          <AbsoluteFill style={{backgroundColor: theme.colors.veil}} />
        </>
      ) : null}
      {theme.photo.backdrop === 'paper' ? (
        <AbsoluteFill
          style={{
            background: `radial-gradient(90% 80% at 50% 45%, rgba(255,250,240,0.55) 0%, rgba(255,250,240,0) 70%), ${theme.colors.bg}`,
          }}
        />
      ) : null}

      <Decorations layer="behind" />
      {image}
      {verticalLabel}
      {captionNode}
      <Decorations layer="front" pageLabel={`${pad2(photoNumber)} / ${pad2(totalPhotos)}`} />
    </AbsoluteFill>
  );
};
