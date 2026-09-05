# 結婚式プロフィールムービー

写真とコメントを設定ファイルに書くだけで、mp4 が出てくる仕組みです。
[Remotion](https://www.remotion.dev/)（React で動画を組み立てるフレームワーク）で作っています。

BGM は入っていません。書き出した mp4 を編集ソフトや式場に渡して、あとから音楽を載せる想定です。
これは手抜きではなく、**無音のまま入稿できれば ISUM 申請が要らなくなる場合がある**ためです（詳しくは後述）。

---

## いちばん短い手順

```bash
cd wedding-movie
npm install          # 初回のみ
npm run setup        # 書体をダウンロード（初回のみ）
npm run check        # 写真の指定とコメントの長さを下読み
npm run render       # out/profile-movie.mp4 が出てくる
```

`npm install` した直後の状態でもダミー画像で通しで動きます。
まず一度回してみて、雰囲気を確認してから中身を差し替えるのが早いです。

---

## 自分たちの内容にする

### 1. 写真を置く

`public/photos/` の下に、章ごとのフォルダを作って写真を入れます。

```
public/photos/
  01_groom/      新郎パート
  02_bride/      新婦パート
  03_together/   ふたりのパート
```

- ファイル名は `01.jpg` `02.jpg` … と番号を振ってください。この順に流れます。
- jpg / png / webp が使えます。**HEIC（iPhone 標準）はそのままでは読めない**ので、jpg に変換してから入れてください。
- 解像度は長辺 2000px 前後あれば十分です。それ以上大きくてもきれいにはならず、書き出しが遅くなるだけです。
- 縦向きの写真は自動で「写真を横、コメントを隣」のレイアウトに切り替わるので、縦横が混ざっていて大丈夫です。

写真は `.gitignore` で除外してあります。git にコミットされることはありません。

### 2. 設定ファイルの雛形を作る

```bash
npm run scaffold
```

`public/photos/` を読んで `movie.config.generated.json` を書き出します。
写真の並びとパスが埋まった状態なので、あとはコメントを書くだけです。

書き終わったら `movie.config.json` にリネーム（上書き）してください。

> 雛形を使わず、最初から入っている `movie.config.json` を直接書き換えても構いません。

### 3. コメントを書く

`movie.config.json` の中身です。

```jsonc
{
  "video": {"width": 1920, "height": 1080, "fps": 30},

  "transitionInSeconds": 0.8,          // 写真と写真をつなぐクロスフェードの長さ
  "defaultPhotoDurationInSeconds": 6,  // 写真1枚あたりの表示秒数

  "opening": {
    "label": "Profile Movie",          // 上に小さく出る英字
    "names": "太郎 & 花子",
    "title": "本日はお集まりいただき\nありがとうございます",
    "date": "2026.11.03",
    "durationInSeconds": 7
  },

  "sections": [
    {
      "label": "Groom",                     // 章扉の英字ラベル
      "title": "新郎 太郎 の生い立ち",
      "subtitle": "1994年5月20日生まれ",
      "cardDurationInSeconds": 4.5,
      "photos": [
        {
          "src": "photos/01_groom/01.jpg",  // public/ からの相対パス
          "label": "1994.5.20",             // 写真の上に小さく出る年号や年齢
          "caption": "3200gの元気な男の子として\n生まれました",
          "durationInSeconds": 8            // 省略可。この1枚だけ長さを変えたいとき
        }
      ]
    }
  ],

  "ending": {
    "label": "Thank You",
    "lines": ["ここまでご覧いただき\nありがとうございました"],
    "signature": "太郎 & 花子",
    "date": "2026.11.03",
    "durationInSeconds": 14
  }
}
```

`\n` を入れるとそこで改行されます。**1枚あたり2行まで**に収めると読みやすいです。

コメントの長さには上限があります。ゲストは「写真を見る」「コメントを読む」を同時にやるので、
**読めるのは1秒あたり約4文字**。表示7秒なら、フェードのぶんを引いて**24文字程度が限界**です。
`npm run check` がこれを自動で数えて、長すぎるコメントを教えてくれます。

`label` `caption` は空文字にすれば消えます。写真だけ見せたいカットに使ってください。

### 4. 下読みして書き出す

```bash
npm run check                         # 写真の指定漏れとコメントの長さを確認
npm run render                        # out/profile-movie.mp4
npm run render -- out/mymovie.mp4     # 出力先を変える
```

尺は `movie.config.json` から自動計算されるので、写真を足しても引いても何も直す必要はありません。

---

## 作りながら確認する

### ブラウザで見る（おすすめ）

```bash
npm run studio
```

ブラウザが開いて、タイムラインを動かしながらリアルタイムで確認できます。
`movie.config.json` を保存すると即座に反映されます。**書き出す前にここで一通り通して見てください。**

### 1コマだけ画像で出す

```bash
npm run still -- 360 out/check.png    # 360フレーム目（30fpsなら12秒地点）
```

全部レンダリングせずに見た目を確認したいときに。

### 設定を下読みする

```bash
npm run check
```

写真の指定漏れとコメントの長さを機械的に見ます。詳しくは次の節。

---

## 尺とコメントの目安

調べた範囲では、だいたい次の数字に収まります（出典は末尾）。

| 項目 | 目安 |
|---|---|
| 全体の尺 | **5〜8分**（6分前後が最も多い） |
| 写真の枚数 | **30〜45枚**（40〜70枚とする情報源もあり） |
| 写真1枚あたり | **5〜8秒**。コメントが短ければ5秒、長ければ7〜8秒 |
| コメントの長さ | **1秒あたり約4文字**。5秒なら20文字が読める限界 |

コメントの文字数がこの範囲を超えていないかは、`npm run check` が自動で見てくれます。

```
$ npm run check
尺        3分25秒（6147フレーム）
写真      28枚 / 章 3つ
画面      1920×1080 (1.78:1) 30fps
章の配分  新郎 太郎 の生い立ち=10枚 / 新婦 花子 の生い立ち=10枚 / ふたりのこと=8枚

  注意  全体が3分25秒です。一般的な目安は5〜8分なので、少し短めです
  注意  写真が28枚です。30〜45枚が一般的な目安です
```

見るのは次の4点です。

- `movie.config.json` が指している写真が実在するか（**書き出す前に落ちる原因の大半がこれ**）
- コメントがその秒数で読み切れる長さか
- 1枚あたりの秒数、全体の尺、写真の枚数が目安の範囲か
- 画面比率が 16:9 か 4:3 になっているか

最初から入っているサンプルは28枚・3分25秒なので、上の2件の注意が出ます。
実際に使うときは写真を30〜45枚に増やしてください。

配分の定番は **新郎4 : 新婦4 : ふたり2**。
新郎・新婦パートは「誕生 → 幼少期 → 小学校 → 中学・高校 → 大学 → 社会人」の流れで並べると、
コメントを考えるのが楽になります。

---

## 式場に出す前の確認

ムービーは**式場によって受け付ける仕様が違います**。作り始める前に必ず担当者に確認してください。

### 提出形式 — ここが一番の落とし穴

「mp4 を渡せば終わり」とは限りません。**現在でも多くの会場が DVD-Video 形式での持ち込みを指定します**。
DVD-Video が必要な場合、mp4 から DVD へのオーサリング（日本国内は **NTSC 方式**）が別途必要です。
このプロジェクトが出すのは mp4 までなので、そこから先は DVD 作成ソフトの仕事になります。

データ入稿でよい会場も増えていますが、**形式・コーデック・提出方法は会場の指示に従ってください**。
書き出し設定は `scripts/render.mjs` に H.264 / yuv420p で書いてあります。指定が違えばここを変えます。

### 画面比率

**16:9 が主流**です（ある制作業者の集計では式場の82%が16:9）。既定値も 16:9 にしてあります。
4:3 指定の会場もまだあるので、式場ヒアリングシートの「アスペクト比」欄を確認してください。

4:3 なら `movie.config.json` の `video` を `{"width": 1440, "height": 1080, "fps": 30}` に変えるだけです。
レイアウトは比率に追従するので、それ以外に直すところはありません。

### 期限

**挙式の2週間前まで**の提出を求められることが多いです。
写真を集めてコメントを考えるだけで1〜2ヶ月かかるので、**3ヶ月前**から動き出すのが安全です。

### 試写

当日と同じプロジェクタで一度流させてもらえるなら必ずやってください。
DVD 入稿なら自宅の機器と式場の機器の両方で再生確認を。予備をもう1枚焼いておくと安心です。

### 画面の端が切れる問題

プロジェクタは映像の**上下左右5〜10%を切り落とすこと**があります。
そのため文字は端から10%の内側にしか置いていません（`src/theme.ts` の `SAFE_AREA_PERCENT`）。
写真は多少切れても致命傷ではないので5%（`ACTION_SAFE_PERCENT`）まで使っています。

## BGM と著作権

このムービーには音声が入っていません。**これは仕様であり、著作権の面では有利に働きます。**

市販曲を結婚式で使うとき、権利は2つに分かれます。

- **演奏権** — 会場でCDをそのまま流すぶん。式場がJASRACと契約していれば会場側でカバーされます。
- **複製権** — 曲をムービーに焼き込むぶん。**これはISUM申請が必要**です（著作権と原盤権の両方）。

つまり、**曲を映像に焼き込まず、無音のまま式場に渡して、音響担当にCDを合わせて流してもらえば、
ISUM申請そのものが不要になる場合があります。** この方法が使えるかは式場に確認してください。

焼き込む場合は ISUM 申請が必要です。調べた範囲では次のとおりです。

- **新郎新婦が個人で直接ISUMに申請することはできません。** 式場かISUM加盟事業者を通す必要があります。
- 申請は**挙式の180日前から**可能。処理は代行業者によっては最短で翌日という情報もありますが、
  **式場側の提出締切はそれとは別**にあるので、そちらに合わせてください。
- 費用の目安は**1曲あたり4,000〜6,000円**程度（曲・長さ・権利者により変動）。
- 式場がISUMに対応していない場合、権利者ひとりひとりに個別に許諾を取ることになります。

**曲を決める前に、式場の担当者に「ISUM対応か」「無音入稿は可能か」を聞いてください。**
どちらも面倒な場合は、著作権フリーの音源を使うのが確実です。

## 見た目を変えたい

| 変えたいもの | 場所 |
|---|---|
| 色・書体 | `src/theme.ts` |
| 文字を置ける範囲（タイトルセーフ） | `src/theme.ts` の `SAFE_AREA_PERCENT`（既定10%） |
| 写真を置ける範囲（アクションセーフ） | `src/theme.ts` の `ACTION_SAFE_PERCENT`（既定5%） |
| 写真の寄り（ケン・バーンズ）の強さ | `src/components/PhotoSlide.tsx` の `zoom` |
| 縦写真と判定する境目 | `src/components/PhotoSlide.tsx` の `PORTRAIT_THRESHOLD` |
| オープニング / 章扉 / エンディングの構成 | `src/components/` の各ファイル |
| シーンのつなぎ方 | `src/ProfileMovie.tsx` |

書体を変える場合は `scripts/fetch-fonts.mjs` の `FONTS` に足して `npm run setup` を実行し、
`src/fonts.ts` と `src/theme.ts` を合わせて直してください。

---

## うまくいかないとき

**`書体の読み込みに失敗しました` と出る**
`npm run setup` を実行してください。`public/fonts/` に ttf が4つ入っていれば OK です。

**写真が出ない / 真っ白になる**
`movie.config.json` の `src` は `public/` からの相対パスです（`public/photos/…` ではなく `photos/…`）。
拡張子の大文字小文字も実際のファイルと合わせてください。

**`Failed to launch the browser process` と出る**
Remotion が Chrome を見つけられていません。`npx remotion browser ensure` で取得できます。

**書き出しが遅い**
写真の解像度を落とすのが一番効きます。長辺 2000px 程度で十分です。
`npm run render -- --concurrency=4` で並列数を指定することもできます。
目安として、1920×1080 / 30fps の3分半で20〜30分ほどかかります。

**`npm run check` で「ファイルが見つかりません」と出る**
`movie.config.json` の `src` と、実際に `public/photos/` にあるファイル名が食い違っています。
拡張子（`.jpg` と `.JPG`）の違いもよくある原因です。`npm run scaffold` で作り直すのが確実です。

---

## ライセンスについて

Remotion は MIT ではなく独自ライセンスです。同梱の `node_modules/remotion/LICENSE.md` が原文です。

- **個人は無料**（商用利用も可）
- 従業員3名までの営利法人、非営利団体も無料
- **従業員4名以上の営利法人は有料**（Company License）

自分たちの結婚式のムービーを作るぶんには、個人利用なので費用はかかりません。
なお LICENSE.md に「Remotion 5.0 でライセンスを一部変更する」と書かれているので、
将来メジャーバージョンを上げるときは条件を読み直してください。

書体（Zen Old Mincho / Zen Kaku Gothic New / Cormorant Garamond）はいずれも
SIL Open Font License で、商用利用も埋め込みも可能です。

---

## 調べたこと（出典）

README 中の数字は、次の情報源に当たって確認したものです。
ただし**式場ごとの決まりが最優先**なので、最後は必ず担当者に確認してください。

**尺・写真枚数・1枚あたりの秒数・コメントの文字数**
- [結婚式のプロフィールムービーの時間は何分がベスト？（むびるプラス）](https://movieru.jp/plus/profile-movie-time/)
- [プロフィールムービーの写真枚数は何枚？30〜45枚の目安とパート別配分（makerry）](https://makerry-wedding.com/profilemovie-photo-count-2/)
- [プロフィールムービーの写真表示時間は平均すると1枚5秒（ピタラボ）](https://pitalabo.com/column/photo-display-time-for-wedding-profile-movie-on-average-5-seconds-per-sheet/)
- [プロフィールムービーは1スライド何秒？（Movers）](https://movers-wedding-movie.net/)
- [結婚式で流す「ムービー」はどんな内容や長さが一般的？（CORDY）](https://cordy.jp/blogs/cordy-magazine/htwp0044)

**セーフゾーン（画面の端が切れる問題）**
- [セーフゾーンとは？結婚式ムービーの文字切れを防ぐ安全範囲と確認方法（makerry）](https://makerry-wedding.com/wedding-movie-safe-zone-text-cut/)
- [初心者必見！結婚式ムービーのアスペクト比とセーフティーゾーン](https://7716wedding.com/mag/aspect-ratio/)
- [自作ムービーの端が切れる原因（nonnofilm）](https://www.nonnofilm.jp/self/profile/pr-self-made/pr_safezone.html)

**提出形式・DVD・アスペクト比・期限**
- [結婚式のプロフィールムービーを自作したい！（結婚スタイルマガジン）](https://www.niwaka.com/ksm/radio/wedding/picture-movie/movie/04/)
- [自作プロフィールムービーに必要なフォーマットと形式の基礎知識（nonnofilm）](https://www.nonnofilm.jp/self/profile/pr-self-made/pr-format.html)
- [結婚式DVD画面比率16:9 vs 4:3完全判断ガイド（NONNOFILM.app）](https://app.nonnofilm.jp/wedding-dvd/wedding-dvd-guide/dvd-aspect-ratio/)
- [結婚式ムービーの画面比率・解像度ガイド](https://weddingvideowish.com/magazin/wedding-movie-specs)

**BGM の著作権・ISUM**
- [ISUM 公式（一般社団法人 音楽特定利用促進機構）](https://isum.or.jp/)
- [ISUM よくある質問](https://isum.or.jp/faq/)
- [結婚式ムービーや会場BGMの曲には著作権が発生するって本当？（みんなのウェディング）](https://www.mwed.jp/articles/257/)
- [ISUMは個人では申請できない？結婚式場に依頼する理由（ボンマリアージュ）](https://bonmariage-bridal.com/blog/%E6%A5%BD%E6%9B%B2%E3%83%BBbgm%E4%BD%BF%E7%94%A8%E6%99%82%E3%81%AE%E6%B3%A8%E6%84%8F%E7%82%B9/post-1343/)
- [【ISUM申請とは】料金相場や個人申請の方法（kanade.design）](https://kanade.design/mag/ISUM01)

**Remotion のライセンス**
- 同梱の `node_modules/remotion/LICENSE.md`（原文）
- [Remotion Company Licensing](https://www.remotion.pro/license)
