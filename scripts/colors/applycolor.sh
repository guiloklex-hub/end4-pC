#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

apply_terminal_templates() {
  if [ ! -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
    return
  fi
  mkdir -p "$STATE_DIR/user/generated/terminal"

  python3 -c "
import sys, os, json

scss_file = '$STATE_DIR/user/generated/material_colors.scss'
json_file = '$STATE_DIR/user/generated/colors.json'
kitty_template = '$SCRIPT_DIR/terminal/kitty-theme.conf'
kitty_target = '$STATE_DIR/user/generated/terminal/kitty-theme.conf'
seq_template = '$SCRIPT_DIR/terminal/sequences.txt'
seq_target = '$STATE_DIR/user/generated/terminal/sequences.txt'

colors = {}
if os.path.exists(scss_file):
    with open(scss_file, 'r') as f:
        for line in f:
            if ':' in line:
                k, v = line.split(':', 1)
                k = k.strip().lstrip('$')
                v = v.strip().rstrip(';').lstrip('#')
                if v and len(v) == 6:
                    colors[k] = v

if not colors:
    sys.exit(0)

# QuickShell consumes the same palette as JSON. Keeping this generated from
# the SCSS output avoids a hard dependency on a separate Matugen template.
with open(json_file, 'w') as f:
    json.dump({key: f'#{value}' for key, value in colors.items()}, f, indent=2)
    f.write('\n')

# Replace in Kitty theme
if os.path.exists(kitty_template):
    with open(kitty_template, 'r') as f:
        text = f.read()
    for k in sorted(colors.keys(), key=len, reverse=True):
        v = colors[k]
        text = text.replace(f'#\${k} #', f'#{v}')
        text = text.replace(f'#\${k}', f'#{v}')
    with open(kitty_target, 'w') as f:
        f.write(text)

# Replace in sequences
if os.path.exists(seq_template):
    with open(seq_template, 'r') as f:
        text = f.read()
    for k in sorted(colors.keys(), key=len, reverse=True):
        v = colors[k]
        text = text.replace(f'\${k} #', f'{v}')
        text = text.replace(f'\${k}', f'{v}')
    text = text.replace('\$alpha', '$term_alpha')
    with open(seq_target, 'w') as f:
        f.write(text)
"
}

apply_kitty() {
  apply_terminal_templates
  # Reload kitty safely
  killall -SIGUSR1 kitty 2>/dev/null || true
}

apply_anyterm() {
  apply_terminal_templates
}

apply_term() {
  apply_kitty
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
