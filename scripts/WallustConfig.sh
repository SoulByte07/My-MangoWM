#!/usr/bin/env bash
# ==================================================
#  MangoWM - Wallust Configuration Helper
# ==================================================

wallust_args=()
wallust_kitty_args=()

wallust_prepare_args() {
  wallust_args=()
  wallust_kitty_args=()

  command -v wallust >/dev/null 2>&1 || return 0

  local mango_wallust_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mango/wallust"
  local mango_cfg="$mango_wallust_dir/wallust.toml"
  local mango_templates="$mango_wallust_dir/templates"

  if [ -f "$mango_cfg" ] && [ -d "$mango_templates" ]; then
    wallust_args=(--templates-dir "$mango_templates" -C "$mango_cfg")
  elif [ -f "$mango_cfg" ]; then
    wallust_args=(-C "$mango_cfg")
  else
    # Fallback to ~/.config/wallust
    local fallback_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallust"
    if [ -f "$fallback_dir/wallust.toml" ]; then
      wallust_args=(-C "$fallback_dir/wallust.toml")
    fi
  fi
}

wallust_prepare_args
