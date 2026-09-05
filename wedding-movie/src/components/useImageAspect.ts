import {getImageDimensions} from '@remotion/media-utils';
import {useEffect, useState} from 'react';
import {continueRender, delayRender} from 'remotion';

/**
 * 写真の縦横比を先に測っておく。
 * 縦位置の写真と横位置の写真でレイアウトを変えたいので、描く前に必要になる。
 */
export const useImageAspect = (src: string): number | null => {
  const [aspect, setAspect] = useState<number | null>(null);
  const [handle] = useState(() => delayRender(`写真を読み込んでいます: ${src}`));

  useEffect(() => {
    let cancelled = false;
    getImageDimensions(src)
      .then(({width, height}) => {
        if (cancelled) return;
        setAspect(width / height);
        continueRender(handle);
      })
      .catch(() => {
        // 測れなくても止めない。横位置とみなして描く。
        if (cancelled) return;
        setAspect(4 / 3);
        continueRender(handle);
      });
    return () => {
      cancelled = true;
    };
  }, [src, handle]);

  return aspect;
};
