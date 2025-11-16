#!/usr/bin/env python3
"""
视频批处理 CLI
依赖：ffmpeg, ffprobe 在 PATH 中

许可证声明：
本产品使用了 FFmpeg，其在 LGPL/GPL 下发布。
更多信息请参考项目的 README 文件。
"""
from pathlib import Path
import subprocess
import shutil
import sys
import argparse

# 目标分辨率
TARGET_W = 1080
TARGET_H = 1920

# 模糊/logo 的位置与尺寸
X = 590
Y = 1810
LOGO_W = 475
LOGO_H = 95

# 支持的文件类型
SUPPORTED_EXTS = {".mp4", ".mkv", ".mov", ".avi"}

def check_tools():
    """
    检查依赖
    """
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("请先安装 ffmpeg/ffprobe 并确保它们在 PATH 中。")
        sys.exit(1)

def find_videos(directory: Path):
    """
    遍历视频文件
    """
    return sorted([p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS])

def get_duration(path: Path) -> float:
    """
    使用ffmpore获取时长
    """
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration",
           "-of", "default=noprint_wrappers=1:nokey=1", str(path)]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        return float(out) if out else 1.0
    except Exception:
        return 1.0

def print_progress_line(file_pct: float, overall_pct: float, name: str):
    """
    打印进度条
    """
    bar_len = 40
    def bar(p):
        filled = int(p / 100 * bar_len + 0.5)
        return "[" + "#" * filled + "-" * (bar_len - filled) + f"] {p:6.2f}%"
    line = f"File: {bar(file_pct)}  Overall: {bar(overall_pct)}"
    print("\r" + line[:(shutil.get_terminal_size().columns - 1)], end="", flush=True)

def process_file(input_path: Path, output_path: Path, logo_path: Path, duration: float, idx: int, total: int):
    """
    视频处理
    """
    # 构造 filter_complex：scale cover -> crop -> 模糊区域 -> overlay logo
    filter_complex = (
        f"[0:v]scale={TARGET_W}:{TARGET_H}:force_original_aspect_ratio=increase,crop={TARGET_W}:{TARGET_H},setsar=1[base];"
        f"[base]split=2[bg][tmp];"
        f"[tmp]crop={LOGO_W}:{LOGO_H}:{X}:{Y},boxblur=10[blurred];"
        f"[bg][blurred]overlay={X}:{Y}:format=auto[tmp2];"
        f"[1:v]scale={LOGO_W}:{LOGO_H}[logo];"
        f"[tmp2][logo]overlay={X}:{Y}:format=auto[outv]"
    )

    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-nostats", "-loglevel", "error",
        "-i", str(input_path), "-i", str(logo_path),
        "-filter_complex", filter_complex,
        "-map", "[outv]", "-map", "0:a?", "-c:v", "libx264", "-crf", "20",
        "-preset", "medium", "-c:a", "copy", "-movflags", "+faststart",
        "-progress", "pipe:1", str(output_path)
    ]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

    file_pct = 0.0
    overall_pct = 0.0
    try:
        for raw in proc.stdout:
            line = raw.strip()
            if not line:
                continue
            # 解析 ffmpeg -progress 的 key=value
            if "=" in line:
                k, v = line.split("=", 1)
                if k in ("out_time_ms", "out_time_us"):
                    # ffmpeg 可能以微秒提供
                    try:
                        us = int(v)
                        seconds = us / 1_000_000.0
                    except Exception:
                        seconds = 0.0
                    file_pct = min(100.0, (seconds / duration) * 100.0)
                elif k == "out_time":
                    # 格式 HH:MM:SS.xxx
                    try:
                        hh, mm, ss = v.split(":")
                        seconds = int(hh) * 3600 + int(mm) * 60 + float(ss)
                        file_pct = min(100.0, (seconds / duration) * 100.0)
                    except Exception:
                        pass
                elif k == "progress" and v == "end":
                    file_pct = 100.0
            overall_pct = ((idx - 1) + file_pct / 100.0) / total * 100.0
            print_progress_line(file_pct, overall_pct, input_path.stem)
        proc.wait()
    finally:
        if proc.poll() is None:
            proc.kill()
    # ensure final print ends with newline
    print()

def main():
    parser = argparse.ArgumentParser(description="简单视频批处理：等比裁切+模糊+叠加logo（单线程）")
    parser.add_argument("--dir", "-d", default=".", help="要处理的视频所在目录（默认当前目录）")
    parser.add_argument("--logo", "-l", default="bin/vidu.png", help="logo 路径（相对于脚本或绝对路径）")
    parser.add_argument("--out", "-o", default="output", help="输出目录")
    args = parser.parse_args()

    check_tools()
    work_dir = Path(args.dir).expanduser().resolve()
    logo_path = (Path(args.logo) if Path(args.logo).is_absolute() else Path.cwd() / args.logo).expanduser().resolve()
    out_dir = work_dir / args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    videos = find_videos(work_dir)
    if not videos:
        print("未在目录中找到支持的视频文件。")
        return

    if not logo_path.exists():
        print(f"警告：logo 未找到：{logo_path} ；脚本将失败或跳过。")

    total = len(videos)
    for idx, v in enumerate(videos, start=1):
        name = v.stem
        out_file = out_dir / f"{name}_1080x1920_c.mp4"
        duration = get_duration(v)
        print(f"Processing ({idx}/{total}): {name}")
        process_file(v, out_file, logo_path, duration, idx, total)

if __name__ == "__main__":
    main()