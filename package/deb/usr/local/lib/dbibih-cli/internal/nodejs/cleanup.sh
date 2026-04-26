#!/usr/bin/env bash
# ======================================================
# Script: nodejs.sh
# Goal: Scan node_modules, report size, optionally delete
# ======================================================

set -euo pipefail

START_DIR="$HOME" # Default: scan all home unless path provided
LOG_FILE="$HOME/clean_node_modules.log"
ERROR_LOG="$HOME/clean_node_modules_errors.log"
IGNORE_FILE=""
SORT_BY="size"      # size|age|path|category
ONLY_TYPE=""        # optional category filter
MIN_SIZE_BYTES=0    # optional minimum size filter
TOP_N=0             # optional top N rows (0 = all)

found_count=0
deleted_count=0
failed_count=0
permission_denied_count=0
total_size_bytes=0
freed_size_bytes=0

declare -a node_dirs=()
declare -a report_dirs=()
declare -a report_types=()
declare -a report_actions=()
declare -a report_reasons=()
declare -a report_mtimes=()
declare -a report_age_days=()
declare -a report_percentages=()
declare -a node_sizes_bytes=()
declare -a node_sizes_human=()
declare -a ignored_dirs=()
YARN_CACHE_ROOT="$HOME/.cache/yarn"
yarn_cache_added=0

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [start_dir] [ignore_file] [options]

Options:
  --sort <size|age|path|category>   Sort report rows (default: size)
  --only <CATEGORY>                 Filter rows by type (PROJECT, YARN_CACHE, NPM_CACHE, etc.)
  --min-size <SIZE>                 Filter rows below size (examples: 500MB, 2GB, 100KB)
  --top <N>                         Show only top N rows after sorting/filtering
  --help                            Show this help
EOF
}

parse_size_to_bytes() {
    local raw="$1"
    local upper
    upper=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]')
    if [[ "$upper" =~ ^([0-9]+)(B|KB|MB|GB|TB)?$ ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]:-B}"
        case "$unit" in
            B)  echo "$value" ;;
            KB) echo $((value * 1024)) ;;
            MB) echo $((value * 1024 * 1024)) ;;
            GB) echo $((value * 1024 * 1024 * 1024)) ;;
            TB) echo $((value * 1024 * 1024 * 1024 * 1024)) ;;
            *) return 1 ;;
        esac
        return 0
    fi
    return 1
}

while (($# > 0)); do
    case "$1" in
        --sort)
            SORT_BY="${2:-}"
            shift 2
            ;;
        --only)
            ONLY_TYPE="${2:-}"
            shift 2
            ;;
        --min-size)
            MIN_SIZE_BYTES=$(parse_size_to_bytes "${2:-}") || {
                echo "Error: invalid --min-size value: ${2:-}"
                exit 1
            }
            shift 2
            ;;
        --top)
            TOP_N="${2:-0}"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --*)
            echo "Error: unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ "$START_DIR" == "$HOME" ]]; then
                START_DIR="$1"
            elif [[ -z "$IGNORE_FILE" ]]; then
                IGNORE_FILE="$1"
            else
                echo "Error: too many positional arguments."
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ ! "$SORT_BY" =~ ^(size|age|path|category)$ ]]; then
    echo "Error: invalid --sort value: $SORT_BY"
    exit 1
fi

# Default protected paths to avoid breaking tools/runtime installs.
DEFAULT_IGNORE_PATTERNS=(
    "$HOME/.nvm/versions/*/lib/node_modules"
    "$HOME/.vscode/extensions/*/node_modules"
    "$HOME/.cursor/extensions/*/node_modules"
    "$HOME/.antigravity/extensions/*/node_modules"
    "$HOME/.azuredatastudio/extensions/*/node_modules"
    "$HOME/.cache/aws/*"
    "$HOME/.cache/copilot/*"
    "$HOME/.cache/typescript/*"
    "$HOME/.nvm/test/*"
    "$HOME/snap/code/*/.local/share/Trash/*"
    "$HOME/*/.next/standalone/node_modules"
)

# Extra patterns can be provided in a file (one glob pattern per line).
USER_IGNORE_PATTERNS=()
if [[ -n "$IGNORE_FILE" ]]; then
    if [[ ! -f "$IGNORE_FILE" ]]; then
        echo "Error: ignore file not found: $IGNORE_FILE"
        exit 1
    fi

    while IFS= read -r raw_line; do
        # Skip empty lines and comments.
        [[ -z "${raw_line// }" || "$raw_line" =~ ^[[:space:]]*# ]] && continue
        USER_IGNORE_PATTERNS+=("$raw_line")
    done <"$IGNORE_FILE"
fi

all_ignore_patterns=("${DEFAULT_IGNORE_PATTERNS[@]}" "${USER_IGNORE_PATTERNS[@]}")

is_ignored_dir() {
    local path="$1"
    local pattern
    for pattern in "${all_ignore_patterns[@]}"; do
        # shellcheck disable=SC2254
        case "$path" in
            $pattern) return 0 ;;
        esac
    done
    return 1
}

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_RED=$'\033[31m'
else
    C_RESET=""
    C_BOLD=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
    C_RED=""
fi

classify_dir_type() {
    local path="$1"
    if [[ "$path" == "$YARN_CACHE_ROOT" ]]; then
        printf "YARN_CACHE"
    elif [[ "$path" == "$HOME/.npm/"* ]]; then
        printf "NPM_CACHE"
    elif [[ "$path" == "$HOME/workspace/"* ]]; then
        printf "PROJECT"
    elif [[ "$path" == "$HOME/Downloads/"* ]]; then
        printf "DOWNLOADS"
    elif [[ "$path" == "$HOME/Desktop/"* ]]; then
        printf "BACKUP_DESKTOP"
    else
        printf "OTHER"
    fi
}

classify_action_reason() {
    local type="$1"
    case "$type" in
        PROJECT|YARN_CACHE|NPM_CACHE|BACKUP_DESKTOP|DOWNLOADS)
            printf "DELETE|reclaimable"
            ;;
        *)
            printf "DELETE|manual_review"
            ;;
    esac
}

type_color() {
    local type="$1"
    case "$type" in
        PROJECT) printf "%s" "$C_GREEN" ;;
        YARN_CACHE|NPM_CACHE) printf "%s" "$C_YELLOW" ;;
        BACKUP_DESKTOP|DOWNLOADS) printf "%s" "$C_BLUE" ;;
        *) printf "%s" "$C_CYAN" ;;
    esac
}

if [[ ! -d "$START_DIR" ]]; then
    echo "Error: path does not exist or is not a directory: $START_DIR"
    exit 1
fi

echo "========== Node Modules Cleanup ==========" | tee "$LOG_FILE"
echo "Scanning in: $START_DIR" | tee -a "$LOG_FILE"
echo "Logs: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Errors: $ERROR_LOG" | tee -a "$LOG_FILE"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Options: sort=$SORT_BY only=${ONLY_TYPE:-ALL} min_size=$(numfmt --to=iec --suffix=B "$MIN_SIZE_BYTES") top=${TOP_N:-ALL}" | tee -a "$LOG_FILE"
echo "------------------------------------------" | tee -a "$LOG_FILE"

# Ensure error file exists and starts fresh for this run.
: >"$ERROR_LOG"

# Discover only root node_modules directories (do not descend once matched).
while IFS= read -r node_dir; do
    if is_ignored_dir "$node_dir"; then
        ignored_dirs+=("$node_dir")
        continue
    fi
    node_dirs+=("$node_dir")
done < <(find "$START_DIR" -type d -name "node_modules" -prune -print 2>>"$ERROR_LOG" | sort)

if [[ -s "$ERROR_LOG" ]]; then
    permission_denied_count=$(awk '/Permission denied/ {count++} END {print count+0}' "$ERROR_LOG")
fi

raw_found_count=${#node_dirs[@]}
ignored_count=${#ignored_dirs[@]}

if [[ $raw_found_count -eq 0 ]]; then
    echo "No node_modules folders found in $START_DIR" | tee -a "$LOG_FILE"
    if [[ $ignored_count -gt 0 ]]; then
        echo "Ignored protected folders: $ignored_count" | tee -a "$LOG_FILE"
    fi
    echo "==========================================" | tee -a "$LOG_FILE"
    exit 0
fi

if [[ $ignored_count -gt 0 ]]; then
    echo "Ignored protected folders: $ignored_count" | tee -a "$LOG_FILE"
fi
tmp_rows_file="$(mktemp)"

for i in "${!node_dirs[@]}"; do
    node_dir="${node_dirs[$i]}"
    display_dir="$node_dir"

    # Collapse all Yarn cache node_modules into one single folder entry.
    if [[ "$node_dir" == "$YARN_CACHE_ROOT"/*"/node_modules" ]]; then
        if [[ $yarn_cache_added -eq 1 ]]; then
            continue
        fi
        display_dir="$YARN_CACHE_ROOT"
        yarn_cache_added=1
    fi

    size_bytes=$(du -sb "$display_dir" 2>>"$ERROR_LOG" | awk '{print $1}')
    size_bytes="${size_bytes:-0}"
    size_human=$(numfmt --to=iec --suffix=B "$size_bytes")
    dir_type=$(classify_dir_type "$display_dir")
    IFS='|' read -r action reason <<<"$(classify_action_reason "$dir_type")"
    mtime_epoch=$(stat -c %Y "$display_dir" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - mtime_epoch) / 86400 ))

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$size_bytes" \
        "$dir_type" \
        "$action" \
        "$reason" \
        "$mtime_epoch" \
        "$age_days" \
        "$display_dir" >>"$tmp_rows_file"
done

filtered_rows="$(mktemp)"
cp "$tmp_rows_file" "$filtered_rows"

if [[ -n "$ONLY_TYPE" ]]; then
    awk -F '\t' -v t="$ONLY_TYPE" '$2==t' "$filtered_rows" > "${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi
if [[ "$MIN_SIZE_BYTES" -gt 0 ]]; then
    awk -F '\t' -v m="$MIN_SIZE_BYTES" '$1>=m' "$filtered_rows" > "${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi

sort_spec="-k1,1nr"
case "$SORT_BY" in
    age) sort_spec="-k6,6nr" ;;
    path) sort_spec="-k7,7" ;;
    category) sort_spec="-k2,2 -k1,1nr" ;;
esac
sort $sort_spec "$filtered_rows" > "${filtered_rows}.sorted"
mv "${filtered_rows}.sorted" "$filtered_rows"

if [[ "$TOP_N" -gt 0 ]]; then
    awk -v n="$TOP_N" 'NR<=n' "$filtered_rows" > "${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi

total_size_bytes=$(awk -F '\t' '{sum+=$1} END {print sum+0}' "$filtered_rows")

while IFS=$'\t' read -r size_bytes dir_type action reason mtime_epoch age_days display_dir; do
    [[ -z "$display_dir" ]] && continue
    size_human=$(numfmt --to=iec --suffix=B "$size_bytes")
    if [[ "$total_size_bytes" -gt 0 ]]; then
        percent=$(awk -v s="$size_bytes" -v t="$total_size_bytes" 'BEGIN {printf "%.1f%%", (s/t)*100}')
    else
        percent="0.0%"
    fi
    modified_human=$(date -d "@$mtime_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "-")

    report_dirs+=("$display_dir")
    report_types+=("$dir_type")
    report_actions+=("$action")
    report_reasons+=("$reason")
    report_mtimes+=("$modified_human")
    report_age_days+=("$age_days")
    report_percentages+=("$percent")
    node_sizes_bytes+=("$size_bytes")
    node_sizes_human+=("$size_human")
done <"$filtered_rows"

found_count=${#report_dirs[@]}
reclaimable_count=$(printf '%s\n' "${report_actions[@]}" | awk '$1=="DELETE"{c++} END {print c+0}')
echo "Inventory report:" | tee -a "$LOG_FILE"
printf '%-4s %-14s %-8s %-13s %-8s %-13s %-16s %s\n' "ID" "CATEGORY" "ACTION" "REASON" "%TOTAL" "AGE_DAYS" "LAST_MODIFIED" "PATH" | tee -a "$LOG_FILE"
printf '%-4s %-14s %-8s %-13s %-8s %-13s %-16s %s\n' "----" "--------------" "------" "-------------" "------" "-------------" "----------------" "----" | tee -a "$LOG_FILE"

for i in "${!report_dirs[@]}"; do
    row_id="$((i + 1))"
    row_type_color=$(type_color "${report_types[$i]}")
    printf '%b%-4s %-14s %-8s %-13s %-8s %-13s %-16s %s%b\n' \
        "$row_type_color" \
        "$row_id" \
        "${report_types[$i]}" \
        "${report_actions[$i]}" \
        "${report_reasons[$i]}" \
        "${report_percentages[$i]}" \
        "${report_age_days[$i]}" \
        "${report_mtimes[$i]}" \
        "${report_dirs[$i]}" \
        "$C_RESET" | tee -a "$LOG_FILE"
done

echo "${C_BOLD}Found $found_count node_modules folder(s).${C_RESET}" | tee -a "$LOG_FILE"
echo "Reclaimable rows (DELETE action): $reclaimable_count" | tee -a "$LOG_FILE"

rm -f "$tmp_rows_file" "$filtered_rows"

echo "------------------------------------------" | tee -a "$LOG_FILE"
echo "Total estimated size: $(numfmt --to=iec --suffix=B "$total_size_bytes")" | tee -a "$LOG_FILE"

read -rp "Delete ALL listed node_modules folders? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Deletion skipped by user." | tee -a "$LOG_FILE"
    echo "==========================================" | tee -a "$LOG_FILE"
    exit 0
fi

for i in "${!node_sizes_bytes[@]}"; do
    node_dir="${report_dirs[$i]}"
    dir_type="${report_types[$i]}"
    action="${report_actions[$i]}"
    size_human="${node_sizes_human[$i]}"
    size_bytes="${node_sizes_bytes[$i]}"
    row_type_color=$(type_color "$dir_type")
    [[ "$action" != "DELETE" ]] && continue

    if rm -rf "$node_dir" 2>>"$ERROR_LOG"; then
        deleted_count=$((deleted_count + 1))
        freed_size_bytes=$((freed_size_bytes + size_bytes))
        printf '%b  ✔ Deleted %-16s %-12s %s%b\n' \
            "$row_type_color" \
            "$dir_type" \
            "$size_human" \
            "$node_dir" \
            "$C_RESET" | tee -a "$LOG_FILE"
    else
        failed_count=$((failed_count + 1))
        printf '%b  ✘ Failed  %-16s %-12s %s%b\n' \
            "$C_RED" \
            "$dir_type" \
            "$size_human" \
            "$node_dir" \
            "$C_RESET" | tee -a "$LOG_FILE"
    fi
done

# Summary
echo "------------------------------------------" | tee -a "$LOG_FILE"
echo "Cleanup Summary:" | tee -a "$LOG_FILE"
echo "  Start directory     : $START_DIR" | tee -a "$LOG_FILE"
echo "  Found folders       : $found_count" | tee -a "$LOG_FILE"
echo "  Ignored folders     : $ignored_count" | tee -a "$LOG_FILE"
echo "  Deleted folders     : $deleted_count" | tee -a "$LOG_FILE"
echo "  Failed deletions    : $failed_count" | tee -a "$LOG_FILE"
echo "  Permission denials  : $permission_denied_count" | tee -a "$LOG_FILE"
echo "  Total scanned size  : $(numfmt --to=iec --suffix=B "$total_size_bytes")" | tee -a "$LOG_FILE"
echo "  Space freed         : $(numfmt --to=iec --suffix=B "$freed_size_bytes")" | tee -a "$LOG_FILE"
if [[ ${#all_ignore_patterns[@]} -gt 0 ]]; then
    echo "  Active ignore rules :" | tee -a "$LOG_FILE"
    for pattern in "${all_ignore_patterns[@]}"; do
        echo "    - $pattern" | tee -a "$LOG_FILE"
    done
fi
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
