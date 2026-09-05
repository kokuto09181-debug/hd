import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
// 写真の被写体をなめらかに見せるため、品質は高めに固定
Config.setJpegQuality(95);
// blur を多用するのでソフトウェアレンダラを明示（環境差でにじみが出るのを防ぐ）
Config.setChromiumOpenGlRenderer('angle');
