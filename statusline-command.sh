#!/usr/bin/env bash
# Claude Code status line
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
cwd="${cwd/#$home/\~}"

# Build context bar segment with color based on usage level
ctx_seg=""
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")

  # Determine color based on usage
  if [ "$used_int" -ge 85 ]; then
    ctx_color=$'\033[0;31m'   # Red: danger (85%+)
  elif [ "$used_int" -ge 60 ]; then
    ctx_color=$'\033[0;33m'   # Orange: caution (60-84%)
  else
    ctx_color=$'\033[0;32m'   # Green: safe (0-59%)
  fi
  reset=$'\033[0m'

  # Build block progress bar (10 blocks total)
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty);  do bar="${bar}░"; done

  ctx_seg=" | ${ctx_color}[${bar}] ${used_int}%${reset}"
fi

printf $'\033[0;36m%s\033[0m | \033[0;33m%s\033[0m%s' "$cwd" "$model" "$ctx_seg"
