#!/bin/bash
# sirogohan.com レシピスクレーパー（macOS / Linux 用）
# 実行前に chmod +x scripts/run_scraper.sh で実行権限を付与してください
set -euo pipefail
cd "$(dirname "$0")"

echo "=== sirogohan.com レシピスクレーパー ==="
echo

# --- 1. 仮想環境の作成 ---
if [ ! -d ".venv" ]; then
    echo "[1/4] Python仮想環境を作成中..."
    python3 -m venv .venv
else
    echo "[1/4] 既存の仮想環境を使用します"
fi

# --- 2. 仮想環境を有効化 ---
echo "[2/4] 仮想環境を有効化中..."
# shellcheck disable=SC1091
source .venv/bin/activate

# --- 3. 依存ライブラリのインストール ---
echo "[3/4] 依存ライブラリをインストール中..."
pip install -r requirements.txt --quiet

# --- 4. スクレーパーの実行 ---
echo "[4/4] スクレーパーを実行中（レート制限: 1秒/リクエスト）..."
python scrape_recipes.py

echo
echo "=== スクレープ完了 ==="
echo
echo "次のステップ（git への追加）:"
echo
echo "  1. DBを再ビルドする（プロジェクトルートから）:"
echo "     python scripts/create_db.py"
echo
echo "  2. 変更をコミットする:"
echo "     git add Sources/HealthDiary/Resources/recipes.db"
echo "     git add scripts/recipes_scraped.json"
echo "     git commit -m 'レシピDBを更新 (sirogohan.com スクレープ)'"
echo "     git push"
echo
echo "※ .venv/ と __pycache__/ は .gitignore で除外済みです"
