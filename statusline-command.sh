#!/bin/bash
# Claude Code Custom Statusline (jq optimized)

# ANSI colors
ORANGE='\033[38;5;208m'
BLUE='\033[34m'
PURPLE='\033[35m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[90m'
RST='\033[0m'

# Read stdin JSON once
STDIN=""
if [ ! -t 0 ]; then
  STDIN=$(cat)
fi

# Parse all values in a single jq call
eval "$(echo "$STDIN" | jq -r '
def make_bar(pct): (((pct + 10) / 20) | floor) as $filled |
  if $filled > 5 then 5 elif $filled < 0 then 0 else $filled end |
  . as $f | ("■" * $f) + ("□" * (5 - $f));

def reset_str(epoch; days):
  if epoch == null or epoch == 0 then ""
  else ((epoch - now) | floor) as $diff |
    if $diff <= 0 then ""
    elif days then
      (($diff / 86400 | floor) | tostring) + "d" + (($diff % 86400 / 3600 | floor) | tostring) + "h"
    else
      (($diff / 3600 | floor) | tostring) + "h" + (($diff % 3600 / 60 | floor) | tostring | if length < 2 then "0" + . else . end) + "m"
    end
  end;

def color_tier(pct; lo; hi):
  if pct < lo then "GREEN" elif pct < hi then "YELLOW" else "RED" end;

(.model.id // "") as $model |
((.context_window.used_percentage // "") | tostring) as $ctx |
(.cwd // "") as $cwd |
(.rate_limits.five_hour // {}) as $five |
(.rate_limits.seven_day // {}) as $week |

# 5h rate limit
(if ($five | has("used_percentage")) then
  ($five.used_percentage | floor) as $p5 |
  "RL5_CLR=\"" + color_tier($p5; 50; 80) + "\"\n" +
  "RL5_TXT=\"5h " + make_bar($p5) + "(" + ($p5|tostring) + "%)" +
    (reset_str($five.resets_at; false) | if . != "" then "(" + . + ")" else "" end) + "\""
else
  "RL5_CLR=\"\"\nRL5_TXT=\"\""
end) + "\n" +

# 1w rate limit
(if ($week | has("used_percentage")) then
  ($week.used_percentage | floor) as $pw |
  "RL1W_CLR=\"" + color_tier($pw; 50; 80) + "\"\n" +
  "RL1W_TXT=\"1w " + make_bar($pw) + "(" + ($pw|tostring) + "%)" +
    (reset_str($week.resets_at; true) | if . != "" then "(" + . + ")" else "" end) + "\""
else
  "RL1W_CLR=\"\"\nRL1W_TXT=\"\""
end) + "\n" +

"MODEL_ID=\"" + $model + "\"\n" +
"CTX_PCT=\"" + $ctx + "\"\n" +
"STDIN_CWD=\"" + $cwd + "\""
' 2>/dev/null)"

# ── Model symbol (orange) ──
case "$MODEL_ID" in
  *opus*)   STARS="${ORANGE}✳${RST}" ;;
  *sonnet*) STARS="${ORANGE}✦${RST}" ;;
  *haiku*)  STARS="${ORANGE}•${RST}" ;;
  *)        STARS="${DIM}·${RST}"    ;;
esac

# ── Directory (blue, shorten home) ──
DIR="${STDIN_CWD:-$PWD}"
DIR="${DIR/#$HOME/~}"
if [ "$(echo "$DIR" | tr '/' '\n' | wc -l)" -gt 3 ]; then
  DIR="…/$(echo "$DIR" | rev | cut -d'/' -f1-2 | rev)"
fi
DIR="${BLUE}${DIR}${RST}"

# ── Git info (purple) ──
GIT=""
if BRANCH=$(git -C "${STDIN_CWD:-$PWD}" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  GIT="${PURPLE}⎇ ${BRANCH}${RST}"
fi

# ── Context battery bar (5 blocks, 30/60 thresholds) ──
CTX=""
if [ -n "$CTX_PCT" ]; then
  CTX_INT="${CTX_PCT%.*}"
  if [ "$CTX_INT" -lt 30 ] 2>/dev/null; then
    CTX_CLR="$GREEN"
  elif [ "$CTX_INT" -lt 60 ] 2>/dev/null; then
    CTX_CLR="$YELLOW"
  else
    CTX_CLR="$RED"
  fi
  FILLED=$(( (CTX_INT + 10) / 20 ))
  [ "$FILLED" -gt 5 ] && FILLED=5
  [ "$FILLED" -lt 0 ] && FILLED=0
  EMPTY=$(( 5 - FILLED ))
  BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}■"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}□"; done
  CTX="${CTX_CLR}${BAR} ${CTX_INT}%${RST}"
fi

# ── Rate limits ──
RL5="" RL1W=""
if [ -n "$RL5_TXT" ]; then
  case "$RL5_CLR" in
    GREEN)  RL5="${GREEN}${RL5_TXT}${RST}" ;;
    YELLOW) RL5="${YELLOW}${RL5_TXT}${RST}" ;;
    RED)    RL5="${RED}${RL5_TXT}${RST}" ;;
  esac
fi
if [ -n "$RL1W_TXT" ]; then
  case "$RL1W_CLR" in
    GREEN)  RL1W="${GREEN}${RL1W_TXT}${RST}" ;;
    YELLOW) RL1W="${YELLOW}${RL1W_TXT}${RST}" ;;
    RED)    RL1W="${RED}${RL1W_TXT}${RST}" ;;
  esac
fi

# ── Assemble ──
SEP="${DIM} │ ${RST}"
OUT="$STARS"
[ -n "$DIR" ]  && OUT="${OUT}${SEP}${DIR}"
[ -n "$GIT" ]  && OUT="${OUT}${SEP}${GIT}"
[ -n "$CTX" ]  && OUT="${OUT}${SEP}${CTX}"
[ -n "$RL5" ]  && OUT="${OUT}${SEP}${RL5}"
[ -n "$RL1W" ] && OUT="${OUT}${SEP}${RL1W}"

echo -e "$OUT"
