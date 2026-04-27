@echo off
setlocal
cd /d "%~dp0"

echo === sirogohan.com レシピスクレーパー ===
echo.

:: --- 1. 仮想環境の作成 ---
if not exist .venv (
    echo [1/4] Python仮想環境を作成中...
    python -m venv .venv
    if errorlevel 1 (
        echo エラー: Python が見つかりません。Python 3.9以上をインストールしてください。
        pause
        exit /b 1
    )
) else (
    echo [1/4] 既存の仮想環境を使用します
)

:: --- 2. 仮想環境を有効化 ---
echo [2/4] 仮想環境を有効化中...
call .venv\Scripts\activate.bat

:: --- 3. 依存ライブラリのインストール ---
echo [3/4] 依存ライブラリをインストール中...
pip install -r requirements.txt --quiet
if errorlevel 1 (
    echo エラー: pip install に失敗しました。
    pause
    exit /b 1
)

:: --- 4. スクレーパーの実行 ---
echo [4/4] スクレーパーを実行中（レート制限: 1秒/リクエスト）...
python scrape_recipes.py
if errorlevel 1 (
    echo エラー: スクレーパーが異常終了しました。
    pause
    exit /b 1
)

echo.
echo === スクレープ完了 ===
echo.
echo 次のステップ（git への追加）:
echo.
echo   1. DBを再ビルドする（プロジェクトルートから）:
echo      python scripts/create_db.py
echo.
echo   2. 変更をコミットする:
echo      git add Sources/HealthDiary/Resources/recipes.db
echo      git add scripts/recipes_scraped.json
echo      git commit -m "レシピDBを更新 (sirogohan.com スクレープ)"
echo      git push
echo.
echo ※ .venv/ と __pycache__/ は .gitignore で除外済みです
echo.
pause
endlocal
