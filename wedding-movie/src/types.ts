export type PhotoEntry = {
  /** public/ からの相対パス。例: "photos/01_groom/01.jpg" */
  src: string;
  /** 写真の上に小さく出る見出し。年号や年齢など。例: "1994.5.20 / 0歳" */
  label?: string;
  /** 本文コメント。1〜2行に収まる長さが読みやすい */
  caption?: string;
  /** この1枚の表示秒数。省略すると defaultPhotoDurationInSeconds */
  durationInSeconds?: number;
};

export type Section = {
  /** 章タイトル（大きく出る日本語） */
  title: string;
  /** 章タイトルの上に出る英字ラベル。例: "Groom" */
  label?: string;
  /** 章タイトルの下に出る一言 */
  subtitle?: string;
  /** 章扉の表示秒数 */
  cardDurationInSeconds?: number;
  photos: PhotoEntry[];
};

export type MovieConfig = {
  video: {
    width: number;
    height: number;
    fps: number;
  };
  /** 写真と写真をつなぐクロスフェードの長さ（秒） */
  transitionInSeconds: number;
  /** 写真1枚あたりの既定の表示秒数 */
  defaultPhotoDurationInSeconds: number;
  opening: {
    label?: string;
    title: string;
    names: string;
    date?: string;
    durationInSeconds: number;
  };
  sections: Section[];
  ending: {
    label?: string;
    lines: string[];
    signature?: string;
    date?: string;
    durationInSeconds: number;
  };
};
