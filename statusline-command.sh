#!/bin/bash
# Claude Code Statusline — [model-symbol] | directory | branch | ctx N% | 5h M% | 1w K%

BLUE='\033[34m'
PURPLE='\033[35m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
ORANGE='\033[38;5;214m'
DIM='\033[90m'
RST='\033[0m'

STDIN=""
if [ ! -t 0 ]; then
  STDIN=$(cat)
fi

# Model symbol
MODEL_ID=$(echo "$STDIN" | jq -r '.model.id // ""' 2>/dev/null)
case "$MODEL_ID" in
  *opus*)   MODEL_SYMBOL="*" ;;
  *sonnet*) MODEL_SYMBOL="✦" ;;
  *haiku*)  MODEL_SYMBOL="◦" ;;
  *)        MODEL_SYMBOL="" ;;
esac

# Directory (shortened)
CWD=$(echo "$STDIN" | jq -r '.cwd // ""' 2>/dev/null)
if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi
SHORT_DIR="${CWD/#$HOME/~}"

# Git branch
GIT_BRANCH=""
if [ -d "${CWD}/.git" ] || git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_BRANCH=$(git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null)
fi

eval "$(echo "$STDIN" | jq -r '
def color_tier(pct; lo; hi):
  if pct < lo then "GREEN" elif pct < hi then "YELLOW" else "RED" end;

((.context_window.used_percentage // "") | if . == "" then "" else floor | tostring end) as $ctx |
(.rate_limits.five_hour // {}) as $five |
(.rate_limits.seven_day // {}) as $week |

"CTX_PCT=\"" + $ctx + "\"\n" +

(if ($five | has("used_percentage")) then
  ($five.used_percentage | floor) as $p |
  "RL5_PCT=\"" + ($p|tostring) + "\"\nRL5_CLR=\"" + color_tier($p; 50; 80) + "\""
else "RL5_PCT=\"\"\nRL5_CLR=\"\"" end) + "\n" +

(if ($week | has("used_percentage")) then
  ($week.used_percentage | floor) as $p |
  "RL1W_PCT=\"" + ($p|tostring) + "\"\nRL1W_CLR=\"" + color_tier($p; 50; 80) + "\""
else "RL1W_PCT=\"\"\nRL1W_CLR=\"\"" end)
' 2>/dev/null)"

# Color helper
colorize() {
  local clr="$1" val="$2"
  case "$clr" in
    GREEN)  printf "${GREEN}%s${RST}" "$val" ;;
    YELLOW) printf "${YELLOW}%s${RST}" "$val" ;;
    RED)    printf "${RED}%s${RST}" "$val" ;;
    *)      printf "%s" "$val" ;;
  esac
}

SEP="${DIM} | ${RST}"

# model symbol
if [ -n "$MODEL_SYMBOL" ]; then
  OUT="${ORANGE}${MODEL_SYMBOL}${RST}${SEP}"
else
  OUT=""
fi

# directory
OUT="${OUT}${BLUE}${SHORT_DIR}${RST}"

# branch
if [ -n "$GIT_BRANCH" ]; then
  OUT="${OUT}${SEP}${PURPLE}${GIT_BRANCH}${RST}"
fi

# ctx
if [ -n "$CTX_PCT" ]; then
  if [ "$CTX_PCT" -lt 30 ] 2>/dev/null; then CTX_CLR="GREEN"
  elif [ "$CTX_PCT" -lt 60 ] 2>/dev/null; then CTX_CLR="YELLOW"
  else CTX_CLR="RED"; fi
  OUT="${OUT}${SEP}${DIM}ctx ${RST}$(colorize "$CTX_CLR" "${CTX_PCT}%")"
fi

# 5h
if [ -n "$RL5_PCT" ]; then
  OUT="${OUT}${SEP}${DIM}5h ${RST}$(colorize "$RL5_CLR" "${RL5_PCT}%")"
fi

# 1w
if [ -n "$RL1W_PCT" ]; then
  OUT="${OUT}${SEP}${DIM}1w ${RST}$(colorize "$RL1W_CLR" "${RL1W_PCT}%")"
fi

printf "%b\n" "$OUT"
