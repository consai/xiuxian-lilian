import openpyxl
import os
import shutil
import glob

BASE = r'C:\godot\xiuxian\excel_config'
BACKUP = r'C:\godot\xiuxian\excel_config_backup'

TARGET_WIDTH = 400
TARGET_HEIGHT = 600

# 1) 先整体备份一次，防止 openpyxl 保存导致意外损失
if not os.path.exists(BACKUP):
    shutil.copytree(BASE, BACKUP)
    print(f"[备份] 已复制到 {BACKUP}")
else:
    print(f"[备份] 已存在 {BACKUP}，跳过备份")

# 2) 遍历所有 .xlsx（含子目录），跳过 Excel 临时锁文件(~$开头)
xlsx_files = sorted(glob.glob(os.path.join(BASE, '**', '*.xlsx'), recursive=True))
xlsx_files = [p for p in xlsx_files if not os.path.basename(p).startswith('~$')]

print(f"[扫描] 共发现 {len(xlsx_files)} 个 Excel 文件")

total_files = 0
total_comments = 0

for path in xlsx_files:
    try:
        wb = openpyxl.load_workbook(path)
    except Exception as e:
        print(f"[跳过] 无法打开 {path}: {e}")
        continue

    file_comments = 0
    for sheet in wb.worksheets:
        for row in sheet.iter_rows():
            for cell in row:
                if cell.comment:
                    cell.comment.width = TARGET_WIDTH
                    cell.comment.height = TARGET_HEIGHT
                    file_comments += 1

    if file_comments > 0:
        try:
            wb.save(path)
            total_files += 1
            total_comments += file_comments
            print(f"[完成] {os.path.relpath(path, BASE)}  批注数: {file_comments}")
        except Exception as e:
            print(f"[失败] 保存 {path} 出错: {e}")
    else:
        print(f"[无批注] {os.path.relpath(path, BASE)}")

print(f"[汇总] 已修改 {total_files} 个文件，共 {total_comments} 条批注")
print("Python 批量修改批注大小完成！")
