# 同じシーンを8テーマ分、大きめに並べた比較画像を作る（シーンごとに1枚）。
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
samples = root / 'out' / 'samples'
order = ['classic', 'cinema', 'natural', 'vintage', 'minimal', 'pop', 'wa', 'editorial']
names = {}
for tid in order:
    src = (root / 'src' / 'themes' / f'{tid}.ts').read_text()
    names[tid] = re.search(r"name: '([^']+)'", src).group(1)

scenes = {
    'opening': 'オープニング', 'section': '章扉', 'photo1': '横写真',
    'photo2': '縦写真', 'ending': 'エンディング',
}
TW, TH, GAP, LABEL = 960, 540, 24, 44
font = ImageFont.truetype(str(root / 'public/fonts/ZenKakuGothicNew-Bold.ttf'), 26)
font_s = ImageFont.truetype(str(root / 'public/fonts/ZenKakuGothicNew-Regular.ttf'), 20)

for scene, jp in scenes.items():
    cols, rows = 2, 4
    W = GAP + cols * (TW + GAP)
    H = GAP + rows * (TH + LABEL + GAP)
    sheet = Image.new('RGB', (W, H), '#EDEBE6')
    draw = ImageDraw.Draw(sheet)
    for i, tid in enumerate(order):
        r, c = divmod(i, cols)
        x = GAP + c * (TW + GAP)
        y = GAP + r * (TH + LABEL + GAP)
        draw.text((x + 4, y + 8), f"{names[tid]}", fill='#111', font=font)
        draw.text((x + 4 + draw.textlength(names[tid], font=font) + 14, y + 13), tid, fill='#888', font=font_s)
        p = samples / f'{tid}-{scene}.png'
        im = Image.open(p).convert('RGB').resize((TW, TH), Image.LANCZOS)
        sheet.paste(im, (x, y + LABEL))
        draw.rectangle([x, y + LABEL, x + TW - 1, y + LABEL + TH - 1], outline='#CFCCC4')
    out = samples / f'grid-{scene}.png'
    sheet.save(out, optimize=True)
    print(out.name, sheet.size)
