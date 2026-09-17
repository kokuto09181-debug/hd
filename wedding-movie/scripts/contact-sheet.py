# out/samples/ の静止画を1枚の一覧表にまとめる。テーマを見比べるため。
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
samples = root / 'out' / 'samples'
themes = json.loads((root / 'out' / 'samples' / 'themes.json').read_text()) if (samples / 'themes.json').exists() else None

if themes is None:
    # src/themes/*.ts から id/name/tagline を雑に拾う
    import re
    themes = []
    order = ['classic','cinema','natural','vintage','minimal','pop','wa','editorial']
    for tid in order:
        src = (root / 'src' / 'themes' / f'{tid}.ts').read_text()
        name = re.search(r"name: '([^']+)'", src).group(1)
        tagline = re.search(r"tagline: '([^']+)'", src).group(1)
        themes.append({'id': tid, 'name': name, 'tagline': tagline})

scenes = ['opening', 'section', 'photo1', 'photo2', 'ending']
scene_labels = {'opening': 'オープニング', 'section': '章扉', 'photo1': '横写真', 'photo2': '縦写真', 'ending': 'エンディング'}

TW, TH = 448, 252          # サムネイル
GAP = 14
LABEL_W = 300              # 左のテーマ名の欄
HEAD_H = 56
PAD = 28

font_b = ImageFont.truetype(str(root / 'public/fonts/ZenKakuGothicNew-Bold.ttf'), 30)
font_s = ImageFont.truetype(str(root / 'public/fonts/ZenKakuGothicNew-Regular.ttf'), 19)
font_h = ImageFont.truetype(str(root / 'public/fonts/ZenKakuGothicNew-Regular.ttf'), 22)

W = PAD * 2 + LABEL_W + len(scenes) * (TW + GAP)
H = PAD * 2 + HEAD_H + len(themes) * (TH + GAP)
sheet = Image.new('RGB', (W, H), '#F5F4F0')
draw = ImageDraw.Draw(sheet)

for ci, scene in enumerate(scenes):
    x = PAD + LABEL_W + ci * (TW + GAP)
    draw.text((x, PAD + 14), scene_labels[scene], fill='#666', font=font_h)

for ri, theme in enumerate(themes):
    y = PAD + HEAD_H + ri * (TH + GAP)
    draw.text((PAD, y + 60), theme['name'], fill='#111', font=font_b)
    draw.text((PAD, y + 104), f"{theme['id']}", fill='#888', font=font_s)
    # タグラインは長いので折り返す
    words, line, lines = theme['tagline'], '', []
    for ch in words:
        line += ch
        if draw.textlength(line, font=font_s) > LABEL_W - 40:
            lines.append(line); line = ''
    if line: lines.append(line)
    for li, l in enumerate(lines[:3]):
        draw.text((PAD, y + 136 + li * 26), l, fill='#555', font=font_s)
    for ci, scene in enumerate(scenes):
        x = PAD + LABEL_W + ci * (TW + GAP)
        p = samples / f"{theme['id']}-{scene}.png"
        if not p.exists():
            draw.rectangle([x, y, x + TW, y + TH], outline='#ccc')
            continue
        im = Image.open(p).convert('RGB').resize((TW, TH), Image.LANCZOS)
        sheet.paste(im, (x, y))
        draw.rectangle([x, y, x + TW - 1, y + TH - 1], outline='#D8D6D0')

out = root / 'out' / 'samples' / 'contact-sheet.png'
sheet.save(out, optimize=True)
print(f'{out} {W}x{H}')
