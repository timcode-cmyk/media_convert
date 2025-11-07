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

# 进度条绘制（宽度）
draw_bar() {
  local percent=$1
  local width=${2:-36}
  local filled=$(awk -v p="$percent" -v w="$width" 'BEGIN{printf "%d", (p/100)*w}')
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

# 视频处理函数
funProcessVideo() {
  local input="$1"
  local name="$2"
  local outdir="$3"
  local outfile="${outdir}/${name}_1080x1920_c.mp4"

  echo
  echo "Processing (${CURRENT_INDEX}/${TOTAL_FILES}): $name"
  echo "  input: $input"
  echo "  output: $outfile"

  if [ ! -f "$LOGO_PATH" ]; then
    echo "ERROR: logo not found at $LOGO_PATH" >&2
    return 1
  fi

  local duration
  duration=$(get_duration "$input")
  # 以毫秒为单位解析进度更精确
  # 运行 ffmpeg 并解析 -progress pipe:1 输出
  # 隐藏普通日志，进度通过 stdout 输出 key=value
  (
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
      -progress pipe:1 "$outfile" 2>/dev/null
  ) | {
    # 解析 pipe 输出
    local out_time_ms=0
    local percent=0
    while IFS='=' read -r key value; do
      case "$key" in
        out_time_ms)
          out_time_ms="$value"
          # 计算当前文件进度（秒）
          local out_s
          out_s=$(awk -v ms="$out_time_ms" 'BEGIN{printf "%.3f", ms/1000000}') # ffmpeg out_time_ms is microseconds in some builds; handle both below
          # handle case if it's milliseconds instead of microseconds
          if awk "BEGIN{exit !( $out_s > 10000 )}"; then
            # very large => out_time_ms probably microseconds; convert
            out_s=$(awk -v ms="$out_time_ms" 'BEGIN{printf "%.3f", ms/1000000}')
          else
            # treat as milliseconds
            out_s=$(awk -v ms="$out_time_ms" 'BEGIN{printf "%.3f", ms/1000}')
          fi
          percent=$(awk -v o="$out_s" -v d="$duration" 'BEGIN{p=(o/d)*100; if(p>100)p=100; printf "%.2f", p}')
          ;;
        out_time)
          # fallback if out_time_ms not available: parse HH:MM:SS.micro
          if [ -z "${out_time_ms:-}" ]; then
            # convert HH:MM:SS.micro to seconds
            out_s=$(awk -F: '{h=$1; m=$2; split($3, a, "."); s=a[1]; ms=(a[2]?"."a[2]:"0"); printf "%.3f", h*3600+m*60+s+ms}')
            percent=$(awk -v o="$out_s" -v d="$duration" 'BEGIN{p=(o/d)*100; if(p>100)p=100; printf "%.2f", p}')
          fi
          ;;
        progress)
          if [ "$value" = "continue" ] || [ "$value" = "out_time" ] || [ "$value" = "continue" ]; then
            # 绘制每个文件的进度条与总体进度
            # 当前文件进度: percent ; overall = ((CURRENT_INDEX-1) + percent/100)/TOTAL_FILES *100
            local overall
            overall=$(awk -v idx="$CURRENT_INDEX" -v t="$TOTAL_FILES" -v p="$percent" 'BEGIN{printf "%.2f", ((idx-1) + p/100)/t*100}')
            # 清行并输出
            printf "\r"
            printf "  File: "
            draw_bar "$percent" 36
            printf "  Overall: "
            draw_bar "$overall" 20
            fflush 2>/dev/null || true
          elif [ "$value" = "end" ]; then
            # 文件完成，显示 100%
            percent=100
            overall=$(awk -v idx="$CURRENT_INDEX" -v t="$TOTAL_FILES" 'BEGIN{printf "%.2f", ((idx)/t)*100}')
            printf "\r"
            printf "  File: "
            draw_bar "$percent" 36
            printf "  Overall: "
            draw_bar "$overall" 20
            printf "\n"
          fi
          ;;
      esac
    done
  }

  # ffmpeg return code isn't available from the pipe loop; check output file existence/size
  if [ ! -s "$outfile" ]; then
    echo "Error: output file not created or empty: $outfile" >&2
    return 1
  fi

  echo "Saved: $outfile"
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