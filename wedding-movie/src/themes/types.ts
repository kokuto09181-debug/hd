/** 写真の額の付け方 */
export type PhotoFrame =
  | 'shadow' // 影だけ。額なし
  | 'none' // 何もなし
  | 'polaroid' // 白い厚紙。下が広い
  | 'hairline' // 細い1本線と、余白のマット
  | 'rounded' // 角丸＋やわらかい影
  | 'border'; // 太い色付きの縁

/** 写真の後ろに何を敷くか */
export type PhotoBackdrop =
  | 'blur' // 同じ写真をぼかして敷く（明）
  | 'blur-dark' // 同じ写真をぼかして敷く（暗）
  | 'solid' // 地の色だけ
  | 'paper'; // 地の色＋紙の質感

/** コメントをどこに置くか */
export type CaptionPlacement =
  | 'below' // 常に写真の下
  | 'side-auto' // 縦写真のときだけ横
  | 'side' // 常に横
  | 'overlay'; // 写真の上に重ねる

export type LabelStyle =
  | 'spaced' // 欧文を字間広めで
  | 'pill' // 色付きの丸い帯
  | 'stamp' // タイプライタ＋枠。スタンプ風
  | 'number' // 大きな数字を添える
  | 'vertical' // 縦書きで写真の脇に
  | 'plain';

export type TransitionKind = 'fade' | 'slide' | 'wipe' | 'clockWipe' | 'iris' | 'none';

export type Decoration =
  | 'rules' // 罫と菱形
  | 'letterbox' // 上下の黒帯
  | 'grain' // フィルムの粒子
  | 'botanical' // 葉のあしらい
  | 'blobs' // 色の丸
  | 'circle' // 大きな輪
  | 'grid' // 細い格子とページ番号
  | 'vignette'; // 四隅を落とす

export type Motion = 'gentle' | 'slow' | 'springy';

export type Theme = {
  id: string;
  name: string;
  tagline: string;
  colors: {
    bg: string;
    bgDeep: string;
    ink: string;
    inkSoft: string;
    accent: string;
    accent2: string;
    /** 章扉の地。省略時は bgDeep */
    section?: string;
    /** 章扉の文字。省略時は ink */
    sectionInk?: string;
    /** ぼかし背景の上に被せる色（rgba） */
    veil: string;
    /** 額の色 */
    frame: string;
  };
  fonts: {
    display: string;
    displayWeight: number;
    body: string;
    bodyWeight: number;
    latin: string;
    latinWeight: number;
    latinItalic: boolean;
  };
  photo: {
    frame: PhotoFrame;
    backdrop: PhotoBackdrop;
    /** 1.0 で動きなし。1.05 で 5% 寄る */
    kenBurns: number;
    /** crop: 額の中で寄る（端が切れる） / scale: 額ごと寄る（切れない） */
    zoomMode: 'crop' | 'scale';
    /** 交互に ±2° 傾ける */
    tilt: boolean;
    /** CSS filter。セピアなど */
    filter: string;
  };
  caption: {
    placement: CaptionPlacement;
    align: 'center' | 'left';
    labelStyle: LabelStyle;
    /** 文字サイズの倍率 */
    scale: number;
  };
  transition: {
    kind: TransitionKind;
    seconds: number;
  };
  decorations: Decoration[];
  motion: Motion;
  title: {
    /** 縦書き */
    vertical: boolean;
    /** 欧文ラベルを大文字に */
    uppercase: boolean;
    /** 文字サイズの倍率 */
    scale: number;
    /** 中央寄せか、左下に寄せるか */
    layout: 'center' | 'bottom-left';
  };
};
