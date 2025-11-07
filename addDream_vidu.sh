#!/usr/bin/env bash

DIRECTORY="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

OUTPUT_DIR="${DIRECTORY}/output"
if [ ! -d $OUTPUT_DIR ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# 目标分辨率（竖屏）
TARGET_W=1080
TARGET_H=1920

# 模糊/logo 参数与位置/尺寸
x=700
y=1810
logox=360
logoy=90

# 外部 logo 路径（可替换为绝对路径或传参）
LOGO_PATH="${SCRIPT_DIR}/bin/vidu.png"

funProcessVideo() {
  local input="$1"
  local name="$2"
  local outdir="$3"
  local outfile="${outdir}/${name}_1080x1920_c.mp4"

  echo "Processing video: $input"

  if [ ! -f "$LOGO_PATH" ]; then
    echo "ERROR: logo not found at $LOGO_PATH" >&2
    return 1
  fi

  # 流程：
  # 1) 等比缩放并 cover 到 1080x1920，裁切多余部分（去黑边或多余区域）
  # 2) 在缩放后的视频上，裁出需要模糊的区域并 boxblur
  # 3) 将模糊区域 overlay 回原位
  # 4) 缩放 logo 并 overlay 到同一位置
  ffmpeg -y -i "$input" -i "$LOGO_PATH" -filter_complex \
"[0:v]scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=increase,crop=${TARGET_W}:${TARGET_H},setsar=1[base]; \
[base]split=2[bg][tmp]; \
[tmp]crop=${logox}:${logoy}:${x}:${y},boxblur=10[blurred]; \
[bg][blurred]overlay=${x}:${y}:format=auto[tmp2]; \
[1:v]scale=${logox}:${logoy}[logo]; \
[tmp2][logo]overlay=${x}:${y}:format=auto[outv]" \
    -map "[outv]" -map 0:a? -c:v libx264 -crf 20 -preset medium -c:a copy -movflags +faststart \
    "$outfile"

  if [ $? -ne 0 ]; then
    echo "Error processing: $input" >&2
    return 1
  fi

  echo "Saved: $outfile"
  return 0
}

# 遍历视频文件并处理
for file in ${DIRECTORY}/*; do
  if [ -f $file ]; then
    ext=${file##*.}
    ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    if [ "$ext" == "mp4" ]; then
      name="$(basename "$file" ."$ext")"
      funProcessVideo $file $name $OUTPUT_DIR
    fi
  fi
done