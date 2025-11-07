#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

DIRECTORY="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

OUTPUT_DIR="${DIRECTORY}/output"
if [ ! -d "$OUTPUT_DIR" ]; then
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

# 进度条宽度
FILE_BAR_WIDTH=40
OVERALL_BAR_WIDTH=40

# 进度条绘制（宽度）
draw_bar() {
  local percent=$1
  local width=${2:-$FILE_BAR_WIDTH}
  local filled
  # 计算填充格数，四舍五入
  filled=$(awk -v p="$percent" -v w="$width" 'BEGIN{n=int(p/100*w+0.5); if(n<0) n=0; if(n>w) n=w; printf "%d", n}')
  local empty=$((width - filled))
  printf "["
  for ((i=0;i<filled;i++)); do printf "#"; done
  for ((i=0;i<empty;i++)); do printf "-"; done
  printf "] %6.2f%%" "$percent"
}

# 使用 ffprobe 获取时长（秒，浮点）
get_duration() {
  local file="$1"
  local dur
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || true)
  # 如果没拿到时长则设为 1 避免除零
  if [ -z "$dur" ]; then dur=1; fi
  printf "%s" "$dur"
}

# 把 hh:mm:ss.xx 转秒
time_to_seconds() {
  local t="$1"
  awk -F: '{ split($3,a,"."); s=a[1]; ms=(a[2]?"."a[2]:"0"); printf "%.3f", $1*3600 + $2*60 + s + ms }' <<<"$t"
}


# 视频处理函数
funProcessVideo() {
  local input="$1"
  local name="$2"
  local outdir="$3"
  local outfile="${outdir}/${name}_1080x1920_c.mp4"

  echo
  echo "Processing (${CURRENT_INDEX}/${TOTAL_FILES}): $name"

  if [ ! -f "$LOGO_PATH" ]; then
    echo "ERROR: logo not found at $LOGO_PATH" >&2
    return 1
  fi

  local duration
  duration=$(get_duration "$input")

  # 创建唯一 FIFO（更安全）
  local FIFO
  FIFO="$(mktemp -u "${TMPDIR:-/tmp}/ffmpeg_progress.XXXXXX")"
  mkfifo "$FIFO"
  # 确保退出时删除 FIFO
  trap 'rm -f "$FIFO"' RETURN

  # 启动 ffmpeg，把 -progress 写入 FIFO（隐藏其它输出）
  ffmpeg -y -hide_banner -nostats -loglevel error \
    -i "$input" -i "$LOGO_PATH" \
    -filter_complex \
"[0:v]scale=${TARGET_W}:${TARGET_H}:force_original_aspect_ratio=increase,crop=${TARGET_W}:${TARGET_H},setsar=1[base]; \
[base]split=2[bg][tmp]; \
[tmp]crop=${logox}:${logoy}:${x}:${y},boxblur=10[blurred]; \
[bg][blurred]overlay=${x}:${y}:format=auto[tmp2]; \
[1:v]scale=${logox}:${logoy}[logo]; \
[tmp2][logo]overlay=${x}:${y}:format=auto[outv]" \
    -map "[outv]" -map 0:a? -c:v libx264 -crf 20 -preset medium -c:a copy -movflags +faststart \
    -progress "$FIFO" "$outfile" 2>/dev/null &

  local FF_PID=$!

  # 预留两行用于实时更新（首次打印空行）
  printf "\n\n"

  # 从 FIFO 读取 ffmpeg -progress 输出（通过 fd 3），解析进度
  exec 3< "$FIFO"
  local percent=0
  local out_time_ms=""
  local out_time=""
  while IFS='=' read -r key value <&3; do
    case "$key" in
      out_time_us|out_time_ms)
        out_time_ms="$value"
        # ffmpeg 报告为微秒，转换为秒
        local out_s
        out_s=$(awk -v us="$out_time_ms" 'BEGIN{printf "%.3f", us/1000000}')
        percent=$(awk -v o="$out_s" -v d="$duration" 'BEGIN{p=(o/d)*100; if(p<0)p=0; if(p>100)p=100; printf "%.2f", p}')
        ;;
      out_time)
        out_time="$value"
        if [ -z "${out_time_ms:-}" ]; then
          local out_s2
          out_s2=$(time_to_seconds "$out_time")
          percent=$(awk -v o="$out_s2" -v d="$duration" 'BEGIN{p=(o/d)*100; if(p<0)p=0; if(p>100)p=100; printf "%.2f", p}')
        fi
        ;;
      progress)
        if [ "$value" = "continue" ]; then
          local overall
          overall=$(awk -v idx="$CURRENT_INDEX" -v t="$TOTAL_FILES" -v p="$percent" 'BEGIN{printf "%.2f", ((idx-1) + p/100)/t*100}')
          printf "\033[2A\r"
          printf "  File:    "; draw_bar "$percent" "$FILE_BAR_WIDTH"; printf "\n"
          printf "  Overall: "; draw_bar "$overall" "$OVERALL_BAR_WIDTH"; printf "\n"
        elif [ "$value" = "end" ]; then
          percent=100
          local overall
          overall=$(awk -v idx="$CURRENT_INDEX" -v t="$TOTAL_FILES" 'BEGIN{printf "%.2f", (idx)/t*100}')
          printf "\033[2A\r"
          printf "  File:    "; draw_bar "$percent" "$FILE_BAR_WIDTH"; printf "\n"
          printf "  Overall: "; draw_bar "$overall" "$OVERALL_BAR_WIDTH"; printf "\n"
          break
        fi
        ;;
    esac
  done
  # 关闭 fd3
  exec 3<&-

  # 等待 ffmpeg 完成并获取退出码
  wait "$FF_PID"
  local rc=$?

  # 清理 FIFO（trap 会处理，但确保删除）
  rm -f "$FIFO"
  trap - RETURN

  if [ $rc -ne 0 ]; then
    echo "Error: ffmpeg exited with code $rc" >&2
    return 1
  fi

  if [ ! -s "$outfile" ]; then
    echo "Error: output file not created or empty: $outfile" >&2
    return 1
  fi

  return 0
}

# 收集待处理文件列表
FILES=()
for f in "${DIRECTORY}"/*; do
  [ -f "$f" ] || continue
  ext="${f##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    mp4|mkv|mov|avi) FILES+=("$f") ;;
    *) ;;
  esac
done

TOTAL_FILES=${#FILES[@]}
if [ "$TOTAL_FILES" -eq 0 ]; then
  echo "No video files found in $DIRECTORY"
  exit 0
fi

CURRENT_INDEX=0
for file in "${FILES[@]}"; do
  CURRENT_INDEX=$((CURRENT_INDEX+1))
  name="$(basename "$file")"
  name="${name%.*}"
  funProcessVideo "$file" "$name" "$OUTPUT_DIR" || echo "Failed: $name"
done

echo
echo "All done. Processed $TOTAL_FILES files."
exit 0