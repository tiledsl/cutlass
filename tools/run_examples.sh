#!/usr/bin/env bash

set -u

DEFAULT_CUTLASS_ROOT="/data/apps/project/cu2tri/cudev/cutlass"
CUTLASS_ROOT="${CUTLASS_ROOT:-$DEFAULT_CUTLASS_ROOT}"
START_ID=""
SKIP_IDS=""

usage() {
  cat <<'EOF'
Usage: run_examples.sh [--root PATH] [--start-id N] [--skip-id ID[,ID...]]
  --root PATH    CUTLASS repo root (default: /data/apps/project/cu2tri/cudev/cutlass or $CUTLASS_ROOT)
  --start-id N    Begin running executables from example directory N (default: run all)
  --skip-id LIST  Comma-separated list of example directory IDs to skip (e.g., 42,45,47)
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 ]]; then
        echo "--root requires a value." >&2
        exit 1
      fi
      CUTLASS_ROOT="$2"
      shift 2
      ;;
    --start-id)
      if [[ $# -lt 2 ]]; then
        echo "--start-id requires a value." >&2
        exit 1
      fi
      START_ID="$2"
      shift 2
      ;;
    --skip-id)
      if [[ $# -lt 2 ]]; then
        echo "--skip-id requires a value." >&2
        exit 1
      fi
      SKIP_IDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$CUTLASS_ROOT" ]]; then
  echo "CUTLASS root does not exist: $CUTLASS_ROOT" >&2
  exit 1
fi

EXAMPLES_DIR="${CUTLASS_ROOT}/build/Release/examples"
LOG_DIR="${CUTLASS_ROOT}/logs"

if [[ -n "$START_ID" && ! "$START_ID" =~ ^[0-9]+$ ]]; then
  echo "Start ID must be a non-negative integer." >&2
  exit 1
fi

declare -A SKIP_MAP=()
if [[ -n "$SKIP_IDS" ]]; then
  IFS=',' read -ra skip_array <<< "$SKIP_IDS"
  for raw_id in "${skip_array[@]}"; do
    id="${raw_id//[[:space:]]/}"
    [[ -z "$id" ]] && continue
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
      echo "Skip IDs must be non-negative integers (got '$id')." >&2
      exit 1
    fi
    normalized_id=$((10#$id))
    SKIP_MAP["$normalized_id"]=1
  done
fi

timestamp="$(date -u +"%Y%m%d-%H%M%SZ")"
LOG_SUFFIX=""
if [[ -n "$START_ID" ]]; then
  LOG_SUFFIX="_${START_ID}"
fi

LOG_FILE="${LOG_DIR}/run_examples${LOG_SUFFIX}_${timestamp}.log"

mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

mapfile -t executables < <(find "$EXAMPLES_DIR" -type f -executable | sort)

if [[ ${#executables[@]} -eq 0 ]]; then
  echo "No executable files found in $EXAMPLES_DIR" | tee -a "$LOG_FILE"
  exit 1
fi

for exe in "${executables[@]}"; do
  rel_path="${exe#"$EXAMPLES_DIR/"}"
  example_dir="${rel_path%%/*}"
  dir_numeric=""

  if [[ -n "$START_ID" ]]; then
    dir_id="${example_dir%%_*}"
    if [[ "$dir_id" =~ ^[0-9]+$ ]]; then
      dir_numeric=$((10#$dir_id))
      if ((dir_numeric < 10#$START_ID)); then
        continue
      fi
    fi
  fi

  if [[ -n "$SKIP_IDS" ]]; then
    if [[ -z "$dir_numeric" ]]; then
      dir_id="${example_dir%%_*}"
      if [[ "$dir_id" =~ ^[0-9]+$ ]]; then
        dir_numeric=$((10#$dir_id))
      fi
    fi
    if [[ -n "$dir_numeric" && -n "${SKIP_MAP[$dir_numeric]:-}" ]]; then
      continue
    fi
  fi

  {
    echo "===== BEGIN $(basename "$exe") : $(date -u +"%Y-%m-%dT%H:%M:%SZ") ====="
    "$exe"
    status=$?
    echo "----- EXIT CODE: $status -----"
    echo
  } >> "$LOG_FILE" 2>&1
done

echo "Execution complete. Logs available at $LOG_FILE"

# bash tools/run_examples.sh --root `pwd` --start-id 0 --skip-id 41