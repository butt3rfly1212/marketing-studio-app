"""웹 대시보드의 Strategy 자료를 Flutter 앱 자산으로 내보낸다.

웹 대시보드(dashboard/build_dashboard.py)와 같은 프로필·문서를 읽어서
  - apps/dashboard/assets/strategy/strategy.json  (브랜드·상품·조서·문서 본문)
  - apps/dashboard/assets/strategy/files/           (그림 파일 복사본)
을 만든다. Contents·Operation 자료는 넣지 않는다.

실행: python -I -X utf8 apps/dashboard/tool/export_strategy.py
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

APP = Path(__file__).resolve().parents[1]
ROOT = APP.parents[1]
OUT = APP / "assets" / "strategy"
FILES = OUT / "files"
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif"}

sys.path.insert(0, str(ROOT / "dashboard"))
import build_dashboard as bd  # noqa: E402


def main():
    bd.LINK_BASE = ROOT  # 자산을 data URI 대신 저장소 기준 상대 경로로 받는다
    data, bundle = bd.build_data()

    if FILES.exists():
        shutil.rmtree(FILES)
    FILES.mkdir(parents=True)

    assets = {}
    for logical, rel in bundle.assets.items():
        phys = ROOT / unquote(rel)
        ext = phys.suffix.lower()
        if ext not in IMAGE_EXT or not phys.is_file():
            continue
        name = hashlib.sha1(logical.encode("utf-8")).hexdigest()[:16] + ext
        shutil.copyfile(phys, FILES / name)
        assets[logical] = "assets/strategy/files/" + name

    products = {key: {"documents": view.get("documents") or {}, "strategy": view.get("strategy") or {}}
                for key, view in data["products"].items()}
    for brand in data["brands"]:
        for p in brand["products"]:
            p["stages"] = {"strategy": p["stages"].get("strategy", False)}

    out = {
        "generatedAt": data["generatedAt"],
        "brands": data["brands"],
        "products": products,
        "documents": data["documents"],
        "assets": assets,
    }
    (OUT / "strategy.json").write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
    size = sum(f.stat().st_size for f in FILES.iterdir())
    print("Strategy 자료 내보냄: 브랜드 %d, 상품 %d, 문서 %d, 그림 %d개(%.1fMB)"
          % (len(out["brands"]), len(products), len(out["documents"]), len(assets), size / 1e6))
    for w in bd.WARNINGS:
        print("  주의: " + w)


if __name__ == "__main__":
    main()
