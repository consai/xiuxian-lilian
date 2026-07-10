"""Convert use_effect / fight_effect to compact array format and sync back to Excel."""
import json, openpyxl
from pathlib import Path

json_path = Path(r'C:\godot\xiuxian\data\exportjson\item_items.json')
xlsx_path = Path(r'C:\godot\xiuxian\excel_config\indir\道具.xlsx')

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Clean up HuiQiDan fight_effect: remove trailing nulls
fe = data['items_HuiQiDan']['fight_effect']
data['items_HuiQiDan']['fight_effect'] = [fe[0], fe[1]]
print('HuiQiDan FE cleaned:', data['items_HuiQiDan']['fight_effect'])

# Save JSON
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('JSON saved.')

# Write back to Excel
wb = openpyxl.load_workbook(xlsx_path)
ws = wb['z_item_items']

# Build id→row map
id_to_row = {}
for r in range(5, ws.max_row + 1):
    vid = ws.cell(row=r, column=1).value
    if vid:
        id_to_row[vid] = r

col_use = 13
col_fight = 16
updated = 0

for kid, item in data.items():
    row = id_to_row.get(kid)
    if row is None:
        continue

    for field, col in [('use_effect', col_use), ('fight_effect', col_fight)]:
        val = item.get(field)
        if val is not None:
            ws.cell(row=row, column=col).value = json.dumps(val, ensure_ascii=False)
            updated += 1

wb.save(xlsx_path)
wb.close()
print('Excel updated: {} cells'.format(updated))
print('Done.')
