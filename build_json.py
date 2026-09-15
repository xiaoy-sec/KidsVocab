import os
import json

# 配置
BASE_PATH = "." 
OUTPUT_JSON = "index.json"

def generate_index():
    manifest = {"categories": []}
    # 忽略这些非分类文件夹
    ignored_folders = ["audio", "logic", "conversations", "icons", "body", "Assets.xcassets", "Frameworks", ".git", "__pycache__"]

    all_entries = os.listdir(BASE_PATH)
    folders = [f for f in all_entries if os.path.isdir(os.path.join(BASE_PATH, f)) and f not in ignored_folders]
    
    for folder in folders:
        cat_path = os.path.join(BASE_PATH, folder)
        items = []
        
        for file in os.listdir(cat_path):
            # 🌟 核心修复：增加了 not file.startswith(".") 来排除隐藏文件
            if (file.endswith(".webp") and 
                "_" in file and 
                "_icon" not in file and 
                not file.startswith(".")):
                
                name_part = file.replace(".webp", "")
                parts = name_part.split("_")
                if len(parts) >= 2:
                    en, cn = parts[0], parts[1]
                    items.append({
                        "en": en,
                        "cn": cn,
                        "image": f"{folder}/{file}",
                        "audio": f"{en}.mp3" 
                    })
        
        # 读取 info.txt
        title_cn = ""
        info_file = os.path.join(cat_path, "info.txt")
        if os.path.exists(info_file):
            with open(info_file, "r", encoding="utf-8") as f:
                title_cn = f.read().strip()

        manifest["categories"].append({
            "id": folder,
            "title": f"{folder.capitalize()} {title_cn}",
            "icon": f"{folder}_icon.webp",
            "items": items
        })

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 修复完成！已过滤隐藏文件并生成 {OUTPUT_JSON}")

if __name__ == "__main__":
    generate_index()