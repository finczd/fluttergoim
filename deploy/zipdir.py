#!/usr/bin/env python3
"""跨平台目录打包：强制正斜杠路径 + UTF-8 文件名（Linux unzip 兼容）。

用法: python zipdir.py <父目录> <输出.zip>
把 <父目录>/<首层子目录>（如 package/im-project）整体压进 zip。
"""
import sys
import zipfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("用法: python zipdir.py <父目录> <输出.zip>", file=sys.stderr)
        return 2
    parent = Path(sys.argv[1])
    out = Path(sys.argv[2])
    if not parent.is_dir():
        print(f"目录不存在: {parent}", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(parent.rglob("*")):
            rel = p.relative_to(parent).as_posix()  # 正斜杠
            if p.is_dir():
                z.writestr(rel + "/", "")
            else:
                z.write(p, rel)  # arcname 含中文时自动写 UTF-8 标志
    print(f"打包完成: {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
