#!/bin/bash
TYPE="${1:-complete}"
LANG="${CLAUDE_RESULT_SPEAK_CAT_LANGUAGE:-en}"
DISPLAY_SECS="${CLAUDE_RESULT_SPEAK_CAT_DISPLAY_SECONDS:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$LANG" in
  en)
    DEFAULT_COMPLETE="Done!"
    DEFAULT_PERMISSION="Waiting for permission..."
    DEFAULT_IDLE="Waiting for input..."
    ;;
  cat)
    DEFAULT_COMPLETE="できたにゃ！"
    DEFAULT_PERMISSION="確認してにゃ..."
    DEFAULT_IDLE="待ってるにゃ..."
    ;;
  *)
    DEFAULT_COMPLETE="できたよ！"
    DEFAULT_PERMISSION="権限確認待ち..."
    DEFAULT_IDLE="入力待ち..."
    ;;
esac

case "$TYPE" in
  complete)
    MSG="${CLAUDE_RESULT_SPEAK_CAT_MESSAGE_COMPLETE:-}"
    EMOJI="✨"
    [[ -z "$MSG" ]] && MSG="$DEFAULT_COMPLETE"
    ;;
  permission)
    MSG="${CLAUDE_RESULT_SPEAK_CAT_MESSAGE_PERMISSION:-}"
    EMOJI="🐟"
    [[ -z "$MSG" ]] && MSG="$DEFAULT_PERMISSION"
    ;;
  idle)
    MSG="${CLAUDE_RESULT_SPEAK_CAT_MESSAGE_IDLE:-}"
    EMOJI="🐾"
    [[ -z "$MSG" ]] && MSG="$DEFAULT_IDLE"
    ;;
  *) exit 0 ;;
esac

FULL_MSG="$EMOJI $MSG"
ASSETS_DIR="$SCRIPT_DIR/../assets"

case "$TYPE" in
  complete)   BASES=(cat1 cat3 cat7) ;;
  permission) BASES=(cat1 cat2 cat5) ;;
  idle)       BASES=(cat1 cat4 cat6) ;;
esac
PET_BASE="${BASES[$RANDOM % ${#BASES[@]}]}"

# macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/show-pet.py" \
      "$FULL_MSG" "$ASSETS_DIR" "$PET_BASE" "$ASSETS_DIR/label.png" "$DISPLAY_SECS" \
      >/dev/null 2>&1 &
  else
    osascript -e "display notification \"$FULL_MSG\" with title \"Claude Code\"" >/dev/null 2>&1 &
  fi
  exit 0
fi

# WSL2
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  exit 0
fi

WIN_ASSETS_DIR=$(wslpath -w "$ASSETS_DIR" 2>/dev/null || echo "")
WIN_LABEL_IMAGE=$(wslpath -w "$ASSETS_DIR/label.png" 2>/dev/null || echo "")
WIN_PS1=$(wslpath -w "$SCRIPT_DIR/Show-Pet.ps1")

safe=$(printf '%s' "$FULL_MSG" | sed "s/'/''/g")

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$WIN_PS1" \
  -Message "$safe" \
  -PetImageDir "$WIN_ASSETS_DIR" \
  -PetBaseName "$PET_BASE" \
  -LabelImagePath "$WIN_LABEL_IMAGE" \
  -DisplaySeconds "$DISPLAY_SECS" \
  >/dev/null 2>&1 &
