#!/usr/bin/env python3
"""
以下3サイトの全レシピをスクレイピングして recipes.sqlite を生成する。
  - 白ごはん.com        (~576 件)
  - みんなのきょうの料理  (~515 件)
  - レタスクラブ          (~1200 件)
リポジトリルートから実行: python3 scripts/scrape_recipes.py

事前インストール: pip3 install requests beautifulsoup4 lxml
所要時間: 約40〜50分（2300件 × 1秒/件 のレート制限）
既存 DB がある場合はスキップして差分のみ追加する。
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_recipes_url ON recipes(url);
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
EGG_KW  = ["卵", "たまご", "卵白", "卵黄"]
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
ETHNIC_KW  = ["ナンプラー", "コチュジャン", "チリソース", "ガパオ", "カレー粉",
              "クミン", "コリアンダー", "ターメリック", "ライム", "パクチー",
              "スイートチリ", "ニョクマム", "サムジャン"]
WESTERN_KW = ["チーズ", "生クリーム", "パスタ", "スパゲッティ", "トマト缶", "コンソメ",
              "ベーコン", "ソーセージ", "ホワイトソース", "マスタード", "ドミグラス"]

METHOD_AGE   = ["揚げ", "フライ", "天ぷら", "テンプラ", "カツ", "コロッケ", "から揚げ", "唐揚げ", "フリット"]
METHOD_ITA   = ["炒め", "チャーハン", "ソース炒め", "バター炒め", "ガーリック炒め"]
METHOD_MUSHI = ["蒸し", "茶碗蒸し"]
METHOD_NI    = ["煮", "シチュー", "ポトフ", "汁", "スープ", "おでん", "鍋", "ブレイズ", "みそ汁", "味噌汁"]
METHOD_YAKI  = ["焼き", "グリル", "ロースト", "テリヤキ", "照り焼き", "ソテー", "炙り"]


def classify_cuisine(name: str, ing_names: list, keywords: list) -> str:
    text = name + " ".join(ing_names) + " ".join(keywords)
    for k in ETHNIC_KW:
        if k in text: return "エスニック"
    for k in CHINESE_KW:
        if k in text: return "中華"
    western_hit = sum(1 for k in WESTERN_KW if k in text)
    if western_hit >= 2: return "洋食"
    return "和食"


def classify_main(ing_names: list) -> str:
    for n in ing_names:
        if any(k in n for k in MEAT_KW): return "肉"
        if any(k in n for k in FISH_KW): return "魚"
    for n in ing_names:
        if any(k in n for k in TOFU_KW): return "豆腐"
        if any(k in n for k in EGG_KW):  return "卵"
    for n in ing_names:
        if any(k in n for k in VEGGIE_KW): return "野菜"
    return "その他"


def classify_method(name: str, keywords: list) -> str:
    text = name + " ".join(keywords)
    for k in METHOD_AGE:
        if k in text: return "揚げる"
    for k in METHOD_ITA:
        if k in text: return "炒める"
    for k in METHOD_MUSHI:
        if k in text: return "蒸す"
    for k in METHOD_NI:
        if k in text: return "煮る"
    for k in METHOD_YAKI:
        if k in text: return "焼く"
    return "その他"


def estimate_calories(main: str, method: str) -> float:
    base = {"肉": 350, "魚": 250, "野菜": 120, "卵": 150, "豆腐": 120, "その他": 280}.get(main, 250)
    mult = {"揚げる": 1.5, "炒める": 1.2, "焼く": 1.0, "煮る": 0.9, "蒸す": 0.85, "その他": 1.0}.get(method, 1.0)
    return round(base * mult)


def classify_ing_category(name: str) -> str:
    if any(k in name for k in MEAT_KW + FISH_KW): return "肉・魚"
    if any(k in name for k in MILK_KW + EGG_KW):  return "乳製品・卵"
    if any(k in name for k in TOFU_KW):            return "その他"
    if any(k in name for k in GRAIN_KW):           return "穀物・麺類"
    if any(k in name for k in SEASON_KW):          return "調味料"
    if any(k in name for k in VEGGIE_KW):          return "野菜"
    return "その他"


# ─── 共通ユーティリティ ──────────────────────────────────────────────────────

def clean_title(raw: str) -> str:
    raw = re.sub(r'^(定番|基本|人気|簡単|おすすめ|本格|絶品|失敗しない)(の|な)?[！!　 ]*', '', raw)
    raw = re.sub(r'のレシピ.*$', '', raw)
    raw = re.sub(r'レシピ.*$', '', raw)
    raw = re.sub(r'[/／].*$', '', raw)   # "ステーキ/作り方" → "ステーキ"
    return raw.strip("！!　 ").strip()


def parse_amount(text: str):
    text = text.replace('　', ' ').strip()
    text = re.sub(r'（.*?）|\(.*?\)', '', text).strip()
    # 分数: 1/2 → 0.5
    text = re.sub(r'(\d+)/(\d+)', lambda m: str(int(m.group(1)) / int(m.group(2))), text)
    # 帯分数: 4+0.5 → 4.5
    text = re.sub(r'(\d+)\+([\d.]+)', lambda m: str(float(m.group(1)) + float(m.group(2))), text)
    if any(k in text for k in ['少々', '適量', '適宜', 'ひとつまみ']):
        return 1.0, '少々'
    # 日本語単位先頭形式: 大さじ3 / 小さじ0.5 / カップ2
    m = re.match(r'^(大さじ|小さじ|カップ|合)\s*([\d.]+)', text)
    if m:
        try:
            return float(m.group(2)), m.group(1)
        except ValueError:
            pass
    # 数値先頭形式: 150g / 2枚
    m = re.match(r'^([\d.]+)\s*(.*)', text)
    if m:
        try:
            return float(m.group(1)), (m.group(2).strip() or '個')
        except ValueError:
            pass
    return 1.0, '適量'


def insert_recipe(con, recipe: dict) -> bool:
    """DB に1件挿入。URL重複は無視。成功したら True を返す。"""
    for attempt in range(3):
        try:
            rid = str(uuid.uuid4())
            con.execute(
                "INSERT OR IGNORE INTO recipes VALUES (?,?,?,?,?,?,?,?)",
                (rid, recipe['name'], recipe['url'],
                 recipe['cuisine_type'], recipe['main_ingredient'],
                 recipe['cooking_method'], recipe['calories_per_serving'],
                 recipe['serving_size'])
            )
            # INSERT OR IGNORE がスキップした場合 rowcount==0
            if con.execute("SELECT changes()").fetchone()[0] == 0:
                return False
            for ing in recipe['ingredients']:
                con.execute(
                    "INSERT INTO ingredients VALUES (?,?,?,?,?,?)",
                    (str(uuid.uuid4()), rid, ing['name'],
                     ing['amount'], ing['unit'], ing['category'])
                )
            return True
        except sqlite3.OperationalError as e:
            if "locked" in str(e) and attempt < 2:
                time.sleep(2)
                continue
            print(f"  DB insert error: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"  DB insert error: {e}", file=sys.stderr)
            return False
    return False


# ═══════════════════════════════════════════════════════════════════════════════
# サイト別パーサー
# ═══════════════════════════════════════════════════════════════════════════════

# ─── 白ごはん.com ─────────────────────────────────────────────────────────────

def get_sirogohan_urls() -> list:
    print("白ごはん.com のサイトマップを取得中...", flush=True)
    resp = requests.get("https://www.sirogohan.com/sitemap.xml", timeout=30)
    root = ET.fromstring(resp.content)
    ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    urls = []
    for loc in root.findall('.//sm:loc', ns):
        u = (loc.text or '').strip()
        if (re.match(r'https://www\.sirogohan\.com/recipe/[a-z0-9_-]+/$', u)
                and '/index/' not in u and 'page:' not in u and '/sp/' not in u):
            urls.append(u)
    print(f"  {len(urls)} 件のレシピURLを発見", flush=True)
    return urls


def scrape_sirogohan(url: str, session) -> dict | None:
    try:
        resp = session.get(url, timeout=15)
        if resp.status_code != 200: return None
        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
    except Exception as e:
        print(f"  fetch error: {e}", file=sys.stderr)
        return None

    h1 = soup.find('h1')
    if not h1: return None
    name = clean_title(h1.get_text(strip=True))
    if not name: return None

    serving_size = 2
    ingredients = []

    for h3 in soup.find_all(['h2', 'h3']):
        if '材料' in h3.get_text():
            m = re.search(r'(\d+)\s*人分', h3.get_text())
            if m: serving_size = int(m.group(1))
            ul = h3.find_next_sibling(['ul', 'div'])
            if ul:
                for li in ul.find_all('li'):
                    parsed = _parse_sirogohan_ingredient(li.get_text(strip=True))
                    if parsed: ingredients.append(parsed)
            break

    if not ingredients: return None

    ing_names = [i['name'] for i in ingredients]
    keywords  = [a.get_text(strip=True)
                 for a in soup.find_all('a') if '/keyword/' in a.get('href', '')]
    cuisine  = classify_cuisine(name, ing_names, keywords)
    main     = classify_main(ing_names)
    method   = classify_method(name, keywords)
    calories = estimate_calories(main, method)

    return {'name': name, 'url': resp.url,
            'cuisine_type': cuisine, 'main_ingredient': main,
            'cooking_method': method, 'calories_per_serving': calories,
            'serving_size': serving_size, 'ingredients': ingredients}


def _parse_sirogohan_ingredient(text: str):
    text = text.strip()
    if not text or text.startswith('【') or text.startswith('●'):
        return None
    parts = re.split(r'\s*[…‥]{1,3}\s*|　{1,}', text, maxsplit=1)
    name = parts[0].strip()
    if not name: return None
    amount_text = parts[1].strip() if len(parts) > 1 else ''
    amount, unit = parse_amount(amount_text)
    return {'name': name, 'amount': amount, 'unit': unit,
            'category': classify_ing_category(name)}


# ─── みんなのきょうの料理 (kyounoryouri.jp) ────────────────────────────────────

def get_kyounoryouri_urls() -> list:
    print("みんなのきょうの料理 のサイトマップを取得中...", flush=True)
    resp = requests.get("https://www.kyounoryouri.jp/sitemaps/recipe.xml", timeout=30)
    root = ET.fromstring(resp.content)
    ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    urls = []
    for loc in root.findall('.//sm:loc', ns):
        u = (loc.text or '').strip()
        if re.match(r'https://www\.kyounoryouri\.jp/recipe/\d+_.+\.html$', u):
            urls.append(u)
    print(f"  {len(urls)} 件のレシピURLを発見", flush=True)
    return urls


def scrape_kyounoryouri(url: str, session) -> dict | None:
    try:
        resp = session.get(url, timeout=15)
        if resp.status_code != 200: return None
        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
    except Exception as e:
        print(f"  fetch error: {e}", file=sys.stderr)
        return None

    h1 = soup.find('h1', class_='ttl') or soup.find('h1')
    if not h1: return None
    name = clean_title(h1.get_text(strip=True))
    if not name: return None

    # 人数
    serving_size = 2
    detail_sub = soup.find('div', class_='detail-sub')
    if detail_sub:
        m = re.search(r'(\d+)\s*人分', detail_sub.get_text())
        if m: serving_size = int(m.group(1))

    # 食材: <span class=ingredient> の親 <dl> からテキストを取る
    ingredients = []
    for sp in soup.find_all('span', class_='ingredient'):
        dl = sp.find_parent('dl')
        if not dl: continue
        raw = dl.get_text(' ', strip=True).lstrip('・').strip()
        if not raw or raw.startswith('【') or raw.startswith('['):
            continue
        # "さやいんげん 150g" → name / amount
        parts = re.split(r'\s+', raw, maxsplit=1)
        ing_name = parts[0].strip()
        amount_text = parts[1].strip() if len(parts) > 1 else ''
        if not ing_name: continue
        amount, unit = parse_amount(amount_text)
        ingredients.append({'name': ing_name, 'amount': amount, 'unit': unit,
                             'category': classify_ing_category(ing_name)})

    if not ingredients: return None

    ing_names = [i['name'] for i in ingredients]
    cuisine  = classify_cuisine(name, ing_names, [])
    main     = classify_main(ing_names)
    method   = classify_method(name, [])
    calories = estimate_calories(main, method)

    return {'name': name, 'url': resp.url,
            'cuisine_type': cuisine, 'main_ingredient': main,
            'cooking_method': method, 'calories_per_serving': calories,
            'serving_size': serving_size, 'ingredients': ingredients}


# ─── レタスクラブ (lettuceclub.net) ───────────────────────────────────────────

def get_lettuceclub_urls() -> list:
    print("レタスクラブ のサイトマップを取得中...", flush=True)
    resp = requests.get("https://www.lettuceclub.net/sitemap_recipe.xml", timeout=30)
    root = ET.fromstring(resp.content)
    ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    urls = []
    for loc in root.findall('.//sm:loc', ns):
        u = (loc.text or '').strip()
        if re.match(r'https://www\.lettuceclub\.net/recipe/dish/\d+/', u):
            urls.append(u)
    print(f"  {len(urls)} 件のレシピURLを発見", flush=True)
    return urls


def scrape_lettuceclub(url: str, session) -> dict | None:
    try:
        resp = session.get(url, timeout=15)
        if resp.status_code != 200: return None
        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
    except Exception as e:
        print(f"  fetch error: {e}", file=sys.stderr)
        return None

    h1 = soup.find('h1')
    if not h1: return None
    name = clean_title(h1.get_text(strip=True))
    if not name: return None

    # 実カロリー (例: "442kcal")
    calories_actual = None
    for p in soup.find_all('p'):
        m = re.search(r'([\d,]+)\s*kcal', p.get_text(strip=True))
        if m:
            try: calories_actual = float(m.group(1).replace(',', ''))
            except: pass
            break

    # 人数・食材
    serving_size = 2
    ingredients = []

    for h2 in soup.find_all('h2'):
        if '材料' not in h2.get_text(): continue
        m = re.search(r'(\d+)\s*人分', h2.get_text())
        if m: serving_size = int(m.group(1))

        # h2 の祖先 section/div 内の section-content クラス ul を探す
        ul = None
        parent = h2.find_parent('section') or h2.find_parent('div')
        if parent:
            for candidate in parent.find_all('ul'):
                cls = ' '.join(candidate.get('class', []))
                if 'section-content' in cls:
                    ul = candidate
                    break

        if ul:
            for li in ul.find_all('li'):
                parsed = _parse_lettuceclub_ingredient(li)
                if parsed: ingredients.append(parsed)
        break

    if not ingredients: return None

    ing_names = [i['name'] for i in ingredients]
    cuisine  = classify_cuisine(name, ing_names, [])
    main     = classify_main(ing_names)
    method   = classify_method(name, [])
    calories = calories_actual if calories_actual else estimate_calories(main, method)

    return {'name': name, 'url': resp.url,
            'cuisine_type': cuisine, 'main_ingredient': main,
            'cooking_method': method, 'calories_per_serving': calories,
            'serving_size': serving_size, 'ingredients': ingredients}


def _parse_lettuceclub_ingredient(li):
    """li 要素から食材名・分量を抽出する。
    構造: li > [span_name, span_amount] （flex justify-between）
    グループ名行（子要素が1つのみ）はスキップ。
    """
    child_texts = [c.get_text(strip=True) for c in li.children
                   if hasattr(c, 'get_text') and c.get_text(strip=True)]
    if len(child_texts) < 2:
        return None  # "合わせ調味料" などのグループ見出し
    name = child_texts[0].lstrip('・').strip()
    if not name: return None
    amount_text = child_texts[1]
    amount, unit = parse_amount(amount_text)
    return {'name': name, 'amount': amount, 'unit': unit,
            'category': classify_ing_category(name)}


# ─── cookien.com ──────────────────────────────────────────────────────────────

def get_cookien_urls() -> list:
    print("cookien のサイトマップを取得中...", flush=True)
    urls = []
    for suffix in ['', '2']:
        try:
            r = requests.get(f"https://cookien.com/post-sitemap{suffix}.xml", timeout=30)
            root = ET.fromstring(r.content)
            ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
            for loc in root.findall('.//sm:loc', ns):
                u = (loc.text or '').strip()
                if re.match(r'https://cookien\.com/recipe/\d+/', u):
                    urls.append(u)
        except Exception as e:
            print(f"  サイトマップ取得エラー: {e}", file=sys.stderr)
    print(f"  {len(urls)} 件のレシピURLを発見", flush=True)
    return urls


def scrape_cookien(url: str, session) -> dict | None:
    try:
        resp = session.get(url, timeout=15)
        if resp.status_code != 200: return None
        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
    except Exception as e:
        print(f"  fetch error: {e}", file=sys.stderr)
        return None

    h1 = soup.find('h1')
    if not h1: return None
    name = clean_title(h1.get_text(strip=True))
    if not name: return None

    # 新旧両フォーマット共通: <div id="r_contents"> を起点にする
    # 旧: <p class="sozai|chomi">食材名<span>分量</span></p>
    # 新: <p>食材名<span>分量</span></p>  ← plain p タグ
    r_contents = soup.find('div', id='r_contents')
    if not r_contents: return None

    serving_size = 2
    h2 = r_contents.find('h2')
    if h2:
        m = re.search(r'(\d+)\s*人分', h2.get_text())
        if m: serving_size = int(m.group(1))

    ingredients = []
    for p in r_contents.find_all('p'):
        span = p.find('span')
        if not span: continue
        amount_text = span.get_text(strip=True)
        full_text   = p.get_text(strip=True)
        span_text   = span.get_text(strip=True)
        # 食材名 = p テキスト から末尾の span テキストを取り除いたもの
        if full_text.endswith(span_text):
            ing_name = full_text[:-len(span_text)].rstrip()
        else:
            ing_name = full_text.replace(span_text, '').strip()
        ing_name = ing_name.lstrip('◎●※').strip()
        if not ing_name or len(ing_name) > 30: continue
        amount, unit = parse_amount(amount_text)
        ingredients.append({'name': ing_name, 'amount': amount, 'unit': unit,
                             'category': classify_ing_category(ing_name)})

    if not ingredients: return None

    ing_names = [i['name'] for i in ingredients]
    cuisine  = classify_cuisine(name, ing_names, [])
    main     = classify_main(ing_names)
    method   = classify_method(name, [])
    calories = estimate_calories(main, method)

    return {'name': name, 'url': resp.url,
            'cuisine_type': cuisine, 'main_ingredient': main,
            'cooking_method': method, 'calories_per_serving': calories,
            'serving_size': serving_size, 'ingredients': ingredients}


# ═══════════════════════════════════════════════════════════════════════════════
# メイン
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    out = os.path.abspath(OUT_PATH)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    con = sqlite3.connect(out, timeout=30)
    con.execute("PRAGMA journal_mode=WAL")   # 並行アクセス時の locked エラーを防ぐ
    con.execute("PRAGMA synchronous=NORMAL") # WAL では NORMAL が安全かつ高速
    con.executescript(SCHEMA)

    # 既存URLをセットに読み込んでスキップ判定に使う
    existing_urls = {row[0] for row in con.execute("SELECT url FROM recipes").fetchall()}
    print(f"既存レシピ: {len(existing_urls)} 件 (差分のみ追加します)", flush=True)

    session = requests.Session()
    session.headers['User-Agent'] = 'HealthDiaryApp-RecipeScraper/1.0 (personal use)'

    # サイト定義: (表示名, URL取得関数, スクレイパー関数, DB上のサイト合計上限)
    # max_total=None は上限なし。サイト合計上限に達したらそのサイトはスキップ。
    sites = [
        ("白ごはん.com",         get_sirogohan_urls,    scrape_sirogohan,     None),
        ("みんなのきょうの料理",   get_kyounoryouri_urls, scrape_kyounoryouri, 10000),
        ("レタスクラブ",           get_lettuceclub_urls,  scrape_lettuceclub,  15000),
        ("cookien",              get_cookien_urls,       scrape_cookien,        None),
    ]

    total_success = total_skipped = total_already = 0

    for site_name, get_urls, scrape, max_total in sites:
        print(f"\n{'='*55}", flush=True)
        print(f"[{site_name}]", flush=True)
        all_urls  = get_urls()
        new_urls  = [u for u in all_urls if u not in existing_urls]

        # サイト合計上限チェック: 既にDB内にある同サイト分を差し引いた残枠に制限
        if max_total is not None and all_urls:
            site_domain  = all_urls[0].split('/')[2]   # e.g. www.kyounoryouri.jp
            site_current = sum(1 for u in existing_urls if site_domain in u)
            remaining    = max(0, max_total - site_current)
            print(f"  DB内 {site_current} 件 / 上限 {max_total} 件 / 追加可能 {remaining} 件",
                  flush=True)
            if remaining == 0:
                print(f"  ※ 上限に達しているためスキップ", flush=True)
                continue
            new_urls = new_urls[:remaining]

        already = len(all_urls) - len(new_urls)
        total_already += already
        print(f"  新規: {len(new_urls)} 件 / 既存スキップ: {already} 件", flush=True)

        site_success = site_skipped = 0
        for i, url in enumerate(new_urls, 1):
            print(f"  [{i:4d}/{len(new_urls)}] ", end='', flush=True)
            recipe = scrape(url, session)

            if recipe and insert_recipe(con, recipe):
                existing_urls.add(recipe['url'])  # resp.url で登録
                site_success += 1
                print(f"✓ {recipe['name']}", flush=True)
            else:
                site_skipped += 1
                print(f"✗ スキップ ({url})", flush=True)

            if i % 50 == 0:
                con.commit()
                print(f"  → {site_success} 件保存済み", flush=True)

            time.sleep(DELAY)

        con.commit()
        total_success += site_success
        total_skipped += site_skipped
        print(f"  [{site_name}] 完了: {site_success} 件保存, {site_skipped} 件スキップ",
              flush=True)

    # iOS バンドル（読み取り専用）で WAL モードが使えないため DELETE に戻す
    con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    con.execute("PRAGMA journal_mode=DELETE")
    con.commit()
    con.close()
    total_in_db = len(existing_urls)
    print(f"\n{'='*55}")
    print(f"今回追加: {total_success} 件保存, {total_skipped} 件スキップ")
    print(f"DB合計:   {total_in_db} 件")
    print(f"出力:      {out}")


if __name__ == "__main__":
    main()
