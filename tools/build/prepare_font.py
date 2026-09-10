#!/usr/bin/env python3
"""Bundle an OFL-licensed CJK font subset covering every shipped string."""
from pathlib import Path
import argparse
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('font', help='NotoSansCJK-Regular.ttc from fonts-noto-cjk')
args = parser.parse_args()
text = ''.join(chr(i) for i in range(32,127))
for directory in ['game', 'content']:
    for path in (ROOT / directory).rglob('*'):
        if path.suffix in {'.gd','.json','.tscn','.po'}:
            text += path.read_text(encoding='utf-8')
font = TTFont(args.font, fontNumber=2)  # Simplified Chinese face
options = subset.Options()
options.name_IDs = ['*']
options.name_legacy = True
options.name_languages = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
for record in font['name'].names:
    if record.nameID in {1,3,4,6,16,17}:
        value = 'AftermapUI' if record.nameID != 17 else 'Regular'
        record.string = value.encode(record.getEncoding())
out = ROOT / 'game/assets_art/fonts'
out.mkdir(exist_ok=True)
font.save(out / 'AftermapUI.otf')
print('Wrote',out / 'AftermapUI.otf')
