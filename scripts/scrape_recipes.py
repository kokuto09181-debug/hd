#!/usr/bin/env python3
"""
白ごはん.com の全レシピをスクレイピングして recipes.sqlite を生成する。
リポジトリルートから実行: python3 scripts/scrape_recipes.py

事前インストール: pip3 install requests beautifulsoup4 lxml
所要時間: 約30〜40分（900件 × 1秒/件 のレート制限）
"""
import re
import time
import xml.etree.ElementTree as ET
import sqlite3
import uuid
import os
import sys

# Windows cp932 でも安全に出力できるよう UTF-8 に強制
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ('utf-8', 'utf8'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("依存パッケージが見つかりません。以下を実行してください:")
    print("  pip3 install requests beautifulsoup4 lxml")
    sys.exit(1)

OUT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "Sources", "HealthDiary", "Resources", "recipes.sqlite"
)
SITEMAP_URL = "https://www.sirogohan.com/sitemap.xml"
DELAY = 1.0  # サイトへの負荷を抑えるため1秒待機

SCHEMA = """
CREATE TABLE IF NOT EXISTS recipes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    cuisine_type TEXT NOT NULL,
    main_ingredient TEXT NOT NULL,
    cooking_method TEXT NOT NULL,
    calories_per_serving REAL NOT NULL,
    serving_size INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS ingredients (
    id TEXT PRIMARY KEY,
    recipe_id TEXT NOT NULL,
    name TEXT NOT NULL,
    amount REAL NOT NULL,
    unit TEXT NOT NULL,
    category TEXT NOT NULL,
    FOREIGN KEY (recipe_id) REFERENCES recipes(id)
);
"""

# ─── 分類キーワード ──────────────────────────────────────────────────────────

MEAT_KW = ["鶏", "豚", "牛", "羊", "合いびき", "ひき肉", "ソーセージ", "ウインナー",
           "ベーコン", "ハム", "焼き豚", "チャーシュー", "レバー", "鴨", "ラム"]
FISH_KW = ["鮭", "鯖", "さば", "ぶり", "鯛", "鱈", "たら", "秋刀魚", "さんま", "いわし",
           "あじ", "えび", "蟹", "かに", "いか", "たこ", "ほたて", "あさり", "しじみ",
           "はまぐり", "貝", "ちりめん", "じゃこ", "かまぼこ", "ちくわ", "まぐろ",
           "かつお", "しらす", "なまり", "たちうお", "きす", "ほっけ", "さわら"]
TOFU_KW = ["豆腐", "厚揚げ", "油揚げ", "高野豆腐", "湯葉", "おから", "豆乳"]
EGG_KW = ["卵", "たまご", "卵白", "卵黄"]
GRAIN_KW = ["ご飯", "米", "うどん", "そば", "パスタ", "スパゲッティ", "ラーメン",
            "素麺", "そうめん", "ビーフン", "春雨", "パン", "食パン", "餃子の皮"]
VEGGIE_KW = ["玉ねぎ", "にんじん", "じゃがいも", "大根", "キャベツ", "ほうれん草",
             "トマト", "きゅうり", "なす", "ピーマン", "ブロッコリー", "ごぼう",
             "れんこん", "さつまいも", "かぼちゃ", "ねぎ", "もやし", "白菜",
             "小松菜", "チンゲン菜", "アスパラ", "きのこ", "しめじ", "えのき",
             "まいたけ", "しいたけ", "エリンギ", "セロリ", "レタス", "パプリカ",
             "ズッキーニ", "オクラ", "三つ葉", "みょうが", "しそ", "ニラ", "にら"]
SEASON_KW = ["醤油", "みりん", "砂糖", "酒", "塩", "酢", "味噌", "マヨネーズ",
             "ごま", "七味", "わさび", "からし", "ポン酢", "めんつゆ", "だし",
             "サラダ油", "ごま油", "片栗粉", "薄力粉", "小麦粉", "水", "出汁",
             "コショウ", "黒胡椒", "白胡椒", "バジル", "パセリ", "ローリエ",
             "ドレッシング", "ソース", "タレ", "みそ", "はちみつ", "オリーブオイル"]
MILK_KW = ["牛乳", "バター", "チーズ", "生クリーム", "ヨーグルト"]

CHINESE_KW = ["豆板醤", "甜麺醤", "オイスターソース", "花椒", "五香粉", "XO醤",
              "鶏がらスープ", "紹興酒", "豆鼓"]
ETHNIC_KW = ["ナンプラー", "コチュジャン", "チリソース", "ガパオ", "カレー粉",
             "クミン", "コリアンダー", "ターメリック", "ライム", "パクチー",
             "スイートチリ", "ニョクマム", "サムジャン", "고추장"]
WESTERN_KW = ["チーズ", "生クリーム", "パスタ", "スパゲッティ", "トマト缶", "コンソメ",
              "ベーコン", "ソーセージ", "ホワイトソース", "マスタード", "ドミグラス"]

METHOD_AGE = ["揚げ", "フライ", "天ぷら", "テンプラ", "カツ", "コロッケ", "から揚げ", "唐揚げ", "フリット"]
METHOD_ITA = ["炒め", "チャーハン", "ソース炒め", "バター炒め", "ガーリック炒め"]
METHOD_MUSHI = ["蒸し", "茶碗蒸し"]
METHOD_NI = ["煮", "シチュー", "ポトフ", "汁", "スープ", "おでん", "鍋", "ブレイズ", "みそ汁", "味噌汁"]
METHOD_YAKI = ["焼き", "グリル", "ロースト", "テリヤキ", "照り焼き", "ソテー", "炙り"]


def classify_cuisine(name: str, ing_names: list, keywords: list) -> str:
    text = name + " ".join(ing_names) + " ".join(keywords)
    for k in ETHNIC_KW:
        if k in text:
            return "エスニック"
    for k in CHINESE_KW:
        if k in text:
            return "中華"
    western_hit = sum(1 for k in WESTERN_KW if k in text)
    if western_hit >= 2:
        return "洋食"
    return "和食"


def classify_main(ing_names: list) -> str:
    for n in ing_names:
        if any(k in n for k in MEAT_KW):
            return "肉"
        if any(k in n for k in FISH_KW):
            return "魚"
    for n in ing_names:
        if any(k in n for k in TOFU_KW):
            return "豆腐"
        if any(k in n for k in EGG_KW):
            return "卵"
    for n in ing_names:
        if any(k in n for k in VEGGIE_KW):
            return "野菜"
    return "その他"


def classify_method(name: str, keywords: list) -> str:
    text = name + " ".join(keywords)
    for k in METHOD_AGE:
        if k in text:
            return "揚げる"
    for k in METHOD_ITA:
        if k in text:
            return "炒める"
    for k in METHOD_MUSHI:
        if k in text:
            return "蒸す"
    for k in METHOD_NI:
        if k in text:
            return "煮る"
    for k in METHOD_YAKI:
        if k in text:
            return "焼く"
    return "その他"


def estimate_calories(main: str, method: str) -> float:
    base = {"肉": 350, "魚": 250, "野菜": 120, "卵": 150, "豆腐": 120, "その他": 280}.get(main, 250)
    mult = {"揚げる": 1.5, "炒める": 1.2, "焼く": 1.0, "煮る": 0.9, "蒸す": 0.85, "その他": 1.0}.get(method, 1.0)
    return round(base * mult)


def classify_ing_category(name: str) -> str:
    if any(k in name for k in MEAT_KW + FISH_KW):
        return "肉・魚"
    if any(k in name for k in MILK_KW + EGG_KW):
        return "乳製品・卵"
    if any(k in name for k in TOFU_KW):
        return "その他"
    if any(k in name for k in GRAIN_KW):
        return "穀物・麺類"
    if any(k in name for k in SEASON_KW):
        return "調味料"
    if any(k in name for k in VEGGIE_KW):
        return "野菜"
    return "その他"


# ─── ページ解析 ──────────────────────────────────────────────────────────────

def clean_title(raw: str) -> str:
    raw = re.sub(r'^(定番|基本|人気|簡単|おすすめ|本格|絶品|失敗しない)(の|な)?[！!　 ]*', '', raw)
    raw = re.sub(r'のレシピ.*$', '', raw)
    raw = re.sub(r'レシピ.*$', '', raw)
    return raw.strip("！!　 ").strip()


def parse_amount(text: str):
    text = text.replace('　', ' ').strip()
    text = re.sub(r'（.*?）|\(.*?\)', '', text).strip()
    text = re.sub(r'(\d+)/(\d+)', lambda m: str(int(m.group(1)) / int(m.group(2))), text)
    if any(k in text for k in ['少々', '適量', '適宜', 'ひとつまみ']):
        return 1.0, '少々'
    m = re.match(r'^([\d.]+)\s*(.*)', text)
    if m:
        try:
            return float(m.group(1)), (m.group(2).strip() or '個')
        except ValueError:
            pass
    return 1.0, '適量'


def parse_ing_line(text: str):
    text = text.strip()
    if not text or text.startswith('【') or text.startswith('●'):
        return None
    # "鶏もも肉　…　1枚" or "鶏もも肉　1枚"
    parts = re.split(r'\s*[…‥]{1,3}\s*|　{1,}', text, maxsplit=1)
    name = parts[0].strip()
    if not name:
        return None
    amount_text = parts[1].strip() if len(parts) > 1 else ''
    amount, unit = parse_amount(amount_text)
    return {'name': name, 'amount': amount, 'unit': unit,
            'category': classify_ing_category(name)}


def scrape_recipe(url: str, session) -> dict | None:
    try:
        resp = session.get(url, timeout=15)
        if resp.status_code != 200:
            return None
        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
    except Exception as e:
        print(f"  fetch error: {e}", file=sys.stderr)
        return None

    h1 = soup.find('h1')
    if not h1:
        return None
    name = clean_title(h1.get_text(strip=True))
    if not name:
        return None

    serving_size = 2
    ingredients = []

    for h3 in soup.find_all(['h2', 'h3']):
        if '材料' in h3.get_text():
            m = re.search(r'(\d+)\s*人分', h3.get_text())
            if m:
                serving_size = int(m.group(1))
            ul = h3.find_next_sibling(['ul', 'div'])
            if ul:
                for li in ul.find_all('li'):
                    parsed = parse_ing_line(li.get_text(strip=True))
                    if parsed:
                        ingredients.append(parsed)
            break

    if not ingredients:
        return None

    ing_names = [i['name'] for i in ingredients]
    keywords = [a.get_text(strip=True)
                for a in soup.find_all('a')
                if '/keyword/' in a.get('href', '')]

    cuisine = classify_cuisine(name, ing_names, keywords)
    main = classify_main(ing_names)
    method = classify_method(name, keywords)
    calories = estimate_calories(main, method)

    return {
        'name': name, 'url': url,
        'cuisine_type': cuisine, 'main_ingredient': main,
        'cooking_method': method, 'calories_per_serving': calories,
        'serving_size': serving_size, 'ingredients': ingredients
    }


def get_recipe_urls() -> list:
    print("サイトマップを取得中...", flush=True)
    resp = requests.get(SITEMAP_URL, timeout=30)
    root = ET.fromstring(resp.content)
    ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    urls = []
    for loc in root.findall('.//sm:loc', ns):
        u = (loc.text or '').strip()
        if (re.match(r'https://www\.sirogohan\.com/recipe/[a-z0-9_-]+/$', u)
                and '/index/' not in u and 'page:' not in u and '/sp/' not in u):
            urls.append(u)
    print(f"{len(urls)} 件のレシピURLを発見", flush=True)
    return urls


def main():
    out = os.path.abspath(OUT_PATH)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    if os.path.exists(out):
        os.remove(out)

    con = sqlite3.connect(out)
    con.executescript(SCHEMA)

    urls = get_recipe_urls()
    session = requests.Session()
    session.headers['User-Agent'] = 'HealthDiaryApp-RecipeScraper/1.0 (personal use)'

    success = skipped = 0

    for i, url in enumerate(urls, 1):
        print(f"[{i:3d}/{len(urls)}] ", end='', flush=True)
        recipe = scrape_recipe(url, session)

        if recipe:
            rid = str(uuid.uuid4())
            con.execute("INSERT OR IGNORE INTO recipes VALUES (?,?,?,?,?,?,?,?)",
                        (rid, recipe['name'], recipe['url'],
                         recipe['cuisine_type'], recipe['main_ingredient'],
                         recipe['cooking_method'], recipe['calories_per_serving'],
                         recipe['serving_size']))
            for ing in recipe['ingredients']:
                con.execute("INSERT INTO ingredients VALUES (?,?,?,?,?,?)",
                            (str(uuid.uuid4()), rid, ing['name'],
                             ing['amount'], ing['unit'], ing['category']))
            success += 1
            print(f"✓ {recipe['name']}", flush=True)
        else:
            skipped += 1
            print(f"✗ スキップ ({url})", flush=True)

        if i % 50 == 0:
            con.commit()
            print(f"  → {success} 件保存済み", flush=True)

        time.sleep(DELAY)

    con.commit()
    con.close()
    print(f"\n完了: {success} 件保存, {skipped} 件スキップ")
    print(f"出力: {out}")


if __name__ == "__main__":
    main()
