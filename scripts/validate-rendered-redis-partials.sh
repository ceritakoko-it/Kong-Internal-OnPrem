#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <rendered_state_dir>"
  exit 1
fi

STATE_DIR="$1"
test -d "$STATE_DIR" || { echo "Rendered state directory not found: $STATE_DIR"; exit 1; }

declare -A PARTIALS_BY_KEY=()
declare -a MISSING_REFS=()

while IFS=$'\t' read -r partial_id partial_name; do
  PARTIALS_BY_KEY["${partial_id}|${partial_name}"]=1
done < <(
  awk '
    /"id": "/ {
      match($0, /"id": "([^"]+)"/, m)
      current_id = m[1]
    }
    /"name": "/ {
      match($0, /"name": "([^"]+)"/, m)
      current_name = m[1]
    }
    /"type": "redis-ee"/ {
      if (current_id != "" && current_name != "") {
        printf "%s\t%s\n", current_id, current_name
      }
      current_id = ""
      current_name = ""
    }
  ' "$STATE_DIR"/partials/*.yaml
)

while IFS=$'\t' read -r ref_file ref_id ref_name; do
  if [ -z "${PARTIALS_BY_KEY["${ref_id}|${ref_name}"]+x}" ]; then
    MISSING_REFS+=("${ref_file}: missing partial id=${ref_id} name=${ref_name}")
  fi
done < <(
  find "$STATE_DIR" -type f -name "*.yaml" -print0 | xargs -0 awk '
    /"id": "/ {
      match($0, /"id": "([^"]+)"/, m)
      current_id = m[1]
    }
    /"name": "/ {
      match($0, /"name": "([^"]+)"/, m)
      current_name = m[1]
    }
    /"path": "config.redis"/ {
      if (current_id != "" && current_name != "") {
        printf "%s\t%s\t%s\n", FILENAME, current_id, current_name
      }
      current_id = ""
      current_name = ""
    }
  '
)

if [ "${#MISSING_REFS[@]}" -gt 0 ]; then
  echo "Rendered state has Redis-backed plugin references that do not match any rendered partial:"
  printf '%s\n' "${MISSING_REFS[@]}"
  exit 1
fi

echo "Validated rendered Redis partial references in: $STATE_DIR"
