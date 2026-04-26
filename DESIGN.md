# HealthDiary 設計書

> 最終更新: 2026-04-22  
> ステータス: 設計フェーズ（実装未着手）  
> 実装前に必ずこのドキュメントを確認すること

---

## 0. アプリ概要・前提

- 家族の健康管理 iOS アプリ（AltStore サイドロード配布）
- オンデバイス LLM（Gemma 4 / MLX, 4bit量子化, ~1GB）を中心に据える
- **LLM は実機専用**。シミュレーターでは `#if !targetEnvironment(simulator)` で分岐済み
- LLM の推論は遅くとも必ず完了する。タイムアウトで打ち切らない。モデル未ロード時のみエラー
- SwiftData (iOS 17+), XcodeGen でプロジェクト管理

---

## 1. ナビゲーション設計

### 1-A. TabView 構成（5タブ）

| # | ラベル | アイコン | View | 変更内容 |
|---|--------|----------|------|---------|
| 1 | ホーム | house.fill | DashboardView | ActivityLog をコンパクトカードとして統合 |
| 2 | 献立 | fork.knife | MealPlannerView | 大幅再設計（§3参照） |
| 3 | 記録 | camera | FoodLogView | カメラ実装追加（§4参照） |
| 4 | 相談 | message.fill | ChatView | **新規追加**（現状は到達不能） |
| 5 | 設定 | gearshape.fill | SettingsView | FamilyProfile をここに統合 |

**削除するタブ**: 「家族」→ 設定画面内の NavigationLink に移動  
**追加するタブ**: 「相談」（ChatView のコードは完成済みだが TabView に含まれていない）

### 1-B. DashboardView レイアウト

```
DashboardView
├── greetingSection（挨拶・日付）
├── todayMealsSection（今日の献立カード）
├── calorieBalanceSection（摂取・消費カロリー）
├── activityCompactCard（歩数・消費カロリーを小さく表示）
│   └── 「詳細 >」NavigationLink → ActivityLogView
├── quickActionsSection
│   ├── [食事を記録] → FoodLogView
│   └── [買い出し・パントリー] → ShoppingListView  ← パントリーと統合
```

### 1-C. SettingsView 内の FamilyProfile

```
SettingsView
├── familySection（新規追加）
│   └── NavigationLink「家族の設定」→ FamilyProfileView
├── aiModelSection
├── subscriptionSection
└── appInfoSection
```

---

## 2. AIチャット機能

### 2-A. 現状の問題

1. ContentView の TabView に ChatView が含まれていない → どこからも到達できない
2. `NewChatView.startChat()` でユーザーの最初のメッセージを保存した後、LLM が返答しない
3. `ChatThreadView.sendMessage()` で `LLMContext.free` をハードコード → スレッドのコンテキストが無視される

### 2-B. コンテキストのマッピング（ChatContext → LLMContext）

| ChatContext | LLMContext | システムプロンプトに含める情報 |
|-------------|------------|----------------------------|
| `.recipe` | `.recipe(name: "", ingredients: [])` | 料理全般の相談として対応 |
| `.mealPlan` | `.mealPlan(days:, members:, allergies:, dislikes:)` | FamilyProfile から家族情報を取得 |
| `.leftover` | `.leftover(recipeName: "")` | **パントリー在庫リスト**を追加で渡す |
| `.health` | `.health` | HealthKit データ（歩数・カロリー）を渡す |
| `.free` | `.free` | — |

`.leftover` コンテキストではパントリーの現在の在庫を LLM に渡すことで、「今ある食材で作れるもの」を提案できる。

### 2-C. 初回メッセージへの自動返答

```
[Input]  ChatThread（初回ユーザーメッセージが1件、アシスタント返答なし）
[Processing]
  1. ChatThreadView.onAppear 時に thread.messages を確認
  2. 最後のメッセージが .user ロール → LLM 呼び出しを自動トリガー
  3. モデル未ロードなら loadModelIfNeeded() を先に await してから生成
[Output]  アシスタント返答が ChatMessage として保存・表示
```

---

## 3. 献立機能

### 3-A. 正しいメンタルモデル（買い出し単位のローリング献立）

**やり直し前の誤ったモデル:**  
「1つの確定プランが常に存在。新しく作ると古いものが降格する」→ 削除

**正しいモデル:**  
買い物 → 料理 → また買い物 のサイクルで、**短いプランを繰り返し作成する**。  
各プランは独立した島であり、他のプランに影響を与えない。

```
[プランA: 4/20〜4/22]  [プランB: 4/23〜4/26]  [プランC: 4/27〜4/30]
  全食事が過去           今日=4/25が含まれる        まだ未来
  → 表示のみ             → 実行中                  → 下書き・編集可
```

### 3-B. プランのステータス設計

| ステータス | 意味 | 変更操作 |
|-----------|------|---------|
| `.draft` | 作成済み、買い出し前 | 全部自由に変更・再生成・削除 |
| `.shopping` | 買い出し済み（仮確定） | **未来の食事**は変更可（警告あり）。**過去の食事**は変更不可 |

**「完了」はステータスではなく計算値:**
```swift
var isCompleted: Bool { endDate < Calendar.current.startOfDay(for: Date()) }
```

**過去の食事の判断:**
```swift
// DayPlan の date が今日より前なら変更不可
var isPast: Bool { date < Calendar.current.startOfDay(for: Date()) }
```

**現状コードの削除が必要な箇所:**
```swift
// MealPlanCreationView.generate() 内 ← これは削除する
for old in allPlans where old.status == .confirmed {
    old.status = .draft  // ← 他のプランを勝手に変更してはいけない
}
```

### 3-C. プランの独立性ルール

1. `.shopping` プランのデータは他のプランの操作で変更されない
2. 新しいプランを作成・編集しても既存プランには触れない
3. 各プランは独立した DayPlan / PlannedMeal ツリーを持ち、共有しない

**日付の重複防止:**
```
[Input]  新プランの startDate〜endDate、既存の全プランの日付範囲
[Processing]
  既存プランとの重複チェック
  重複あり → 「その期間はプランXと重なっています」と表示し保存しない
[Output]  有効な場合のみ保存
```

**「次の献立」のデフォルト開始日:**
```
[Input]  全プランの endDate 一覧
[Processing]  最も遅い endDate の翌日をデフォルト値として提案
[Output]  MealPlanCreationView の startDate 初期値
```

### 3-D. MealPlannerView 画面設計

```
MealPlannerView
├── [実行中] セクション
│   └── 今日の日付を含む .shopping プラン → DayPlanView で表示
│       ├── 今日のハイライト表示
│       ├── 過去の食事: グレーアウト（変更不可）
│       └── 未来の食事: 通常表示（変更可）
├── [下書き] セクション（.draft プランの一覧）
│   ├── 各プラン行: 期間・日数・作成日
│   ├── タップ → MealPlanDetailView
│   └── スワイプ削除
├── [過去] セクション（isCompleted == true）
│   └── 折りたたみ（デフォルト非表示）
└── ツールバー [+ 次の献立を作る] → MealPlanCreationView
```

### 3-E. MealPlanDetailView 内の操作

```
MealPlanDetailView（1つのプランを表示）
├── ヘッダー: [4/27（日）〜4/30（水）· 4日間]
├── 日付タブ（スクロール）
├── DayPlanView（選択中の日の食事一覧）
│   ├── 各食事行: タップ → MealSlotEditView
│   └── 「この日を再生成」ボタン（.draft のみ・過去の日は不可）
└── ツールバー
    ├── [↻ 全体を再生成]（.draft のみ）
    ├── [🛒 買い出し・パントリーへ] → ShoppingListView
    └── [✓ 買い出し済みにする]（.draft → .shopping）
        ※ .shopping 状態では非表示
```

### 3-F. 再生成の粒度

| 操作 | 対象 | 条件 |
|------|------|------|
| 全体を再生成 | プラン全日程の全食事 | `.draft` のみ |
| 特定の日を再生成 | 1日分の全食事 | `.draft` のみ、かつ `!isPast` |
| 特定の1食を再生成 | 1食のみ | `.draft` のみ、かつ `!isPast` |
| 手動で変更 | 1食のみ（レシピを選び直す） | `.draft` のみ、かつ `!isPast` |
| .shopping プランの変更 | 未来の食事のみ | `!isPast` + 警告「買い出しリストと内容がずれます」表示 |

### 3-G. 献立生成フロー（LLM版）

```
[Input]
  - numberOfDays: Int（2〜14）
  - startDate: Date
  - slotConfig: SlotConfig
  - familyProfile: FamilyProfile?
  - recentHistory: [MealHistoryEntry]（直近30件、重複回避用）
  - userConditions: [String]（["時短", "魚多め"] 等）
  - recipeList: [RecipeRecord]（SQLiteから最大150件）

[Processing]
  1. recipeList を文字列化:
     "ID:123 名前:豚の生姜焼き 種別:和食 主材料:肉 調理法:焼き カロリー:450kcal"
  2. familyProfile から全メンバーのアレルギー・嫌いな食べ物を union で抽出
  3. プロンプトを組み立て（§3-H 参照）
  4. 生成中UI を表示（§3-I 参照）
  5. LLMService.generate(prompt:, context: .mealPlan(...)) を呼ぶ
     ※ 完了まで待つ。タイムアウトしない
  6. JSON を解析（§3-J 参照）
  7. 解析失敗 → エラー表示（ルールベースフォールバックなし・再試行ボタンあり）
  8. MealPlan(status: .draft), DayPlan, PlannedMeal を SwiftData に保存
  9. 生成条件を MealPlan に保存（再生成時に再利用）

[Output]
  - MealPlan (status: .draft) が SwiftData に保存
  - 既存プランのステータスは変更しない
```

### 3-H. LLM プロンプト仕様

```
あなたは家族向け献立提案アシスタントです。
以下の情報をもとに、{numberOfDays}日分の献立を提案してください。

【家族情報】
- 人数: {members.count}人
- 年齢層: {ageGroups}
- アレルギー: {allergies}（含むレシピは絶対に選ばないこと）
- 苦手な食べ物: {dislikes}

【希望条件】
{userConditions}

【直近で食べたレシピ（なるべく避けること）】
{recentRecipeIDs}

【選択可能なレシピ一覧】
{formattedRecipeList}

【出力形式】
必ず以下のJSONのみ出力。説明文・前置き・コードブロック記号は不要。
{
  "days": [
    {
      "date": "YYYY-MM-DD",
      "meals": {
        "breakfast": {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
        "lunch":     {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""},
        "dinner":    {"recipe_id": "ID", "recipe_name": "料理名", "notes": ""}
      }
    }
  ]
}
スロット外の食事はキーを省略。recipe_id はリスト内のIDのみ使用。
```

### 3-I. 生成中UI（広告連携）

```
[全画面ローディングシート]
┌──────────────────────────────┐
│  献立を考えています...          │
│  ───────────────── （不定進行）│
│                               │
│  ┌────────────────────────┐  │
│  │  無料ユーザー: 動画広告  │  │
│  │  プレミアム: AIアニメ   │  │
│  └────────────────────────┘  │
│                               │
│  ※ 完了すると自動で閉じます    │
└──────────────────────────────┘

- 生成完了 → 自動 dismiss → MealPlannerView の [下書き] セクションに表示
- 広告 SDK は実装フェーズで選定（AdMob 等）
```

### 3-J. JSON パース仕様

```
[Processing]
  1. テキストから "{" 〜 "}" を抽出（前置き文対策）
  2. JSONDecoder でデコード
  3. recipe_id を RecipeDatabase で照合
     成功: recipeID, recipeName, recipeURL, calories をセット
     失敗: recipeName のみ保存、recipeID は nil
[失敗時]
  エラーシート「献立の生成に失敗しました。もう一度お試しください。」
  [再試行] ボタン → 同じ条件で再実行
```

### 3-K. MealPlanCreationView 設計

```
[選択項目]
1. 開始日（DatePicker, default: 既存プランの翌日 or 明日）
2. 日数（Stepper 2〜14日, default: 4）
3. 平日の食事スロット（Toggle: 朝食 / 昼食 / 夕食）
4. 休日の食事スロット（Toggle: 朝食 / 昼食 / 夕食）
5. こだわり条件（複数選択 + 自由テキスト入力）
   - 時短メニュー優先 / 魚料理を多めに / 肉料理を多めに
   - 子供が食べやすいもの / 野菜多め

[ボタン]「AIで献立を作る」→ 生成中UI（§3-I）
```

**MealPlan に追加する生成条件保存用プロパティ:**
```swift
var generationConditions: [String]
var slotConfigWeekday: [String]   // MealType.rawValue の配列
var slotConfigWeekend: [String]
```

---

## 4. 買い出し・パントリー機能

### 4-A. 概念設計

買い出しリストとパントリー（冷蔵庫・食材在庫）は**1つの画面に統合する**。

```
ShoppingListView（買い出し・パントリー統合画面）
├── [今回買うもの] セクション（通常表示）
│   ⬜ 豚バラ肉  300g
│   ⬜ ピーマン   3個
├── [家にあるかも] セクション（半透明・グレー）
│   🔲 玉ねぎ   1/2個   （パントリー: 2個）
│   🔲 醤油              （パントリー: 残少）
└── [パントリー管理] セクション
    ├── 現在の在庫一覧
    ├── 手動追加ボタン
    └── 「残り物で何か作れる？」→ Chat (.leftover) を開く
```

**アクセス経路:**
- ダッシュボードのクイックアクション「買い出し・パントリー」
- MealPlanDetailView のツールバー「🛒 買い出し・パントリーへ」
- タブには置かない

### 4-B. パントリーのデータ設計

```swift
@Model
final class PantryItem {
    var name: String
    var amount: Double?           // nil = 「あるかどうか」だけ管理
    var unit: String?
    var category: IngredientCategory
    var addedAt: Date
    var source: PantrySource
}

enum PantrySource: String, Codable {
    case shopping  // 買い出しリストのチェックから自動追加
    case manual    // ユーザーが手動追加
}
```

### 4-C. パントリーへの自動追加・消費フロー

```
[自動追加]
  Input:  ShoppingItem（ユーザーが「買った ✓」をチェック）
  Processing: 同名の PantryItem があれば amount を加算、なければ新規作成
  Output: PantryItem が更新される

[自動消費]
  Input:  PlannedMeal の日付が過去（isPast == true）になったとき
  Processing:
    1. そのレシピの食材を RecipeDatabase から取得
    2. 対応する PantryItem の amount を減算
    3. amount <= 0 になったら PantryItem を削除
  Output: PantryItem が減る・消える
```

### 4-D. 買い出しリスト生成フロー

```
[Input]
  - 対象プランの未来の PlannedMeal 全件
  - 現在の PantryItem 全件

[Processing]
  1. 未来の食事に必要な全食材を RecipeDatabase から集計
  2. PantryItem と名前・単位でマッチング
     - パントリーに十分ある → 「家にあるかも」セクション
     - パントリーにない or 不足 → 「今回買うもの」セクション
  3. 食事を変更した場合は差分を計算
     - 追加で必要になった食材: 「買うもの」に追加
     - 不要になった食材: 「買うもの」から削除

[Output]
  セクション分けされた ShoppingItem リスト
```

### 4-E. 食事変更後の警告

`.shopping` プランの未来の食事を変更した場合:

```
「買い出しリストと内容が変わります。
 追加で買う必要があるもの: ○○、△△
 不要になったもの: □□
 リストを更新しますか？」
[更新する] [このまま]
```

### 4-F. LLM との連携

```
パントリー在庫一覧 → 「残り物で何か作れる？」ボタン
  → ChatView を開く（コンテキスト: .leftover）
  → LLM のシステムプロンプトにパントリー内容を自動挿入:
    「現在の冷蔵庫にある食材: {pantryItems の一覧}
     これらを使ったレシピを提案してください」
```

---

## 5. 食事記録・カメラ機能

### 5-A. 現状の問題

1. カメラボタンが `useCamera = true` にするだけで何も起きない
2. Apple Vision の汎用分類器は食品認識精度が低い
3. LLM と連携していない

### 5-B. カメラ実装設計

```
[UIImagePickerController ラッパー（新規作成）]
  Input:  sourceType（.camera or .photoLibrary）
  Processing: UIViewControllerRepresentable として実装
  Output: UIImage

FoodPhotoCaptureView の変更:
  useCamera = true → CameraPickerView をシートで表示（.camera sourceType）
  撮影完了 → capturedImage にセット → 認識処理へ
```

### 5-C. 食品認識フロー（Vision + LLM）

```
[Phase 1: Vision 高速認識]
  Input:  UIImage
  Processing: VNClassifyImageRequest → confidence > 0.3 の上位3件
  Output: topLabels: [String]（例: ["fried_rice", "rice", "food"]）

[Phase 2: LLM 詳細分析]
  Input:  topLabels
  Processing:
    プロンプト:
      「画像認識結果: {topLabels}
       日本語の料理名と推定カロリー(kcal)を以下の形式で答えてください:
       料理名|推定カロリー
       例: 炒飯|550」
    LLMService.generate(prompt:, context: .foodAnalysis) を呼ぶ
    "料理名|カロリー" をパース
  Output: recognizedFoodName: String, estimatedCalories: Int

[UI]
  認識結果と推定カロリーを編集可能 TextField に自動入力
  「このまま記録」→ FoodLogEntry を保存
```

### 5-D. LLMContext への追加

```swift
// LLMContext に追加
case foodAnalysis
// システムプロンプト: "食事の画像認識結果から日本語の料理名と推定カロリーを答えてください。"
```

---

## 6. レシピリンク問題

### 6-A. 現状

収集した URL（sirogohan.com 等）がサイトリニューアルで無効化されている。

### 6-B. 対応方針

**現時点**: URL はそのまま残す。UI では「参考レシピを見る」ボタンを `SFSafariViewController` で開く。「ページが表示されない場合があります」の注意書きを添える。

**将来（別フェーズ・時期未定）**: `scripts/validate_urls.py` を作成して URL 生存確認 → 無効 URL を NULL に更新。

---

## 7. アクティビティ・HealthKit

ActivityLogView はコード完成済みで到達不能なのみ。ダッシュボードのコンパクトカードから NavigationLink でアクセスできるようにする。

---

## 8. データモデル変更サマリー

| モデル | 変更内容 |
|--------|---------|
| `MealPlanStatus` | `.confirmed` を `.shopping` にリネーム（意味の明確化） |
| `MealPlan` | `generationConditions: [String]`, `slotConfigWeekday: [String]`, `slotConfigWeekend: [String]` を追加 |
| `PantryItem` | **新規追加**（§4-B 参照） |
| `PantrySource` | **新規追加**（enum） |
| `LLMContext` | `.mealPlan` の引数を拡充、`.foodAnalysis` を追加 |

---

## 9. 実装フェーズ計画

| Phase | 内容 | 備考 |
|-------|------|------|
| **1** | TabView 変更（Chat追加・Family削除）+ Settings に FamilyProfile + Dashboard に ActivityLog 統合 | 既存コードの接続のみ |
| **2** | AIチャット修正（コンテキストバグ・初回自動返答） | LLMContext 変換関数の追加 |
| **3** | 献立 LLM 化（生成・再生成・日付重複チェック・プラン独立性） | MealPlanStatus のリネームも含む |
| **4** | 買い出し・パントリー統合（PantryItem モデル・ShoppingListView 再設計） | Phase 3 完了後 |
| **5** | カメラ実装（UIImagePickerController + LLM 食品認識） | Phase 2 完了後 |
| **6** | レシピ URL 検証スクリプト | 独立して実施可能 |

---

## 10. 確定した設計判断

| # | 項目 | 決定内容 |
|---|------|---------|
| A | カメラ権限文言 | 「食事の写真を撮影して、AIが料理名とカロリーを自動認識します」を Info.plist に設定 |
| B | 広告SDK | **後回し**。生成中はアニメーションのみ。AdMob 等は将来フェーズで対応 |
| C | 食材名マッチング | 正規化テーブル＋LLM判定のハイブリッド方式（§4-G 参照） |

---

## 11. 食材名正規化設計（§4-C の補足）

### ハイブリッドマッチング

```
[Input]  比較したい2つの食材名（例: 「玉ねぎ」と「タマネギ」）

[Processing]
  Step 1: 完全一致チェック → 一致すれば終了
  Step 2: 正規化テーブルで検索
           { "タマネギ": "玉ねぎ", "onion": "玉ねぎ", "たまねぎ": "玉ねぎ", ... }
           両方を正規化形に変換して一致すれば同一視
  Step 3: テーブルに未登録 → LLMで判定
           プロンプト: 「「{A}」と「{B}」は同じ食材ですか？「はい」または「いいえ」で答えてください」
           「はい」なら同一視
  Step 4: LLMの判定結果を正規化テーブルに自動追記（次回からStep2で解決）

[Output]  isSameIngredient: Bool
```

### 正規化テーブル

- `Resources/IngredientNormalization.json` として同梱
- 初期セット: よく使う食材 200件程度（ひらがな・カタカナ・漢字・英語表記のバリエーション）
- LLMの学習結果は SwiftData の別モデル `IngredientAlias` に追記（アプリ内で育てる）

```swift
@Model
final class IngredientAlias {
    var alias: String       // 例: "タマネギ"
    var canonical: String   // 例: "玉ねぎ"
    var addedAt: Date
}
```
