#!/usr/bin/env bash
# ======================================================
# Script: docker/cleanup.sh
# Goal: Report and cleanup reclaimable Docker resources
# ======================================================

set -euo pipefail

SORT_BY="size"      # size|age|name|category
ONLY_CATEGORY=""    # optional
MIN_SIZE_BYTES=0
TOP_N=0
LOG_FILE="$HOME/docker_cleanup.log"
ERROR_LOG="$HOME/docker_cleanup_errors.log"

declare -a report_categories=()
declare -a report_actions=()
declare -a report_reasons=()
declare -a report_sizes_bytes=()
declare -a report_sizes_human=()
declare -a report_percentages=()
declare -a report_age_days=()
declare -a report_last_used=()
declare -a report_names=()
declare -a report_ids=()

show_usage() {
    cat <<EOF
Usage: cleanup.sh [options]

Options:
  --sort <size|age|name|category>   Sort report rows (default: size)
  --only <CATEGORY>                 Filter rows by category
  --min-size <SIZE>                 Filter rows below size (examples: 500MB, 2GB, 100KB)
  --top <N>                         Show only top N rows after sorting/filtering
  --help                            Show this help

Categories:
  CONTAINER_STOPPED IMAGE_UNUSED IMAGE_DANGLING NETWORK_UNUSED VOLUME_UNUSED BUILD_CACHE
EOF
}

parse_size_to_bytes() {
    local raw="${1:-0B}"
    local clean upper
    clean="$(printf '%s' "$raw" | tr -d ' ' | sed 's/iB/B/g' | sed 's/^+//')"
    upper="$(printf '%s' "$clean" | tr '[:lower:]' '[:upper:]')"

    if [[ "$upper" =~ ^([0-9]+([.][0-9]+)?)(B|KB|MB|GB|TB)?$ ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[3]:-B}"
        awk -v v="$value" -v u="$unit" 'BEGIN {
            m=1;
            if (u=="KB") m=1024;
            else if (u=="MB") m=1024*1024;
            else if (u=="GB") m=1024*1024*1024;
            else if (u=="TB") m=1024*1024*1024*1024;
            printf "%.0f\n", v*m;
        }'
        return 0
    fi

    echo 0
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

category_color() {
    local category="$1"
    case "$category" in
        VOLUME_UNUSED|IMAGE_UNUSED|IMAGE_DANGLING|BUILD_CACHE) printf "%s" "$C_YELLOW" ;;
        CONTAINER_STOPPED) printf "%s" "$C_BLUE" ;;
        NETWORK_UNUSED) printf "%s" "$C_CYAN" ;;
        *) printf "%s" "$C_GREEN" ;;
    esac
}

while (($# > 0)); do
    case "$1" in
        --sort) SORT_BY="${2:-}"; shift 2 ;;
        --only) ONLY_CATEGORY="${2:-}"; shift 2 ;;
        --min-size)
            MIN_SIZE_BYTES="$(parse_size_to_bytes "${2:-}")"
            shift 2
            ;;
        --top) TOP_N="${2:-0}"; shift 2 ;;
        --help|-h) show_usage; exit 0 ;;
        --*)
            echo "Error: unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            echo "Error: unexpected positional argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [[ ! "$SORT_BY" =~ ^(size|age|name|category)$ ]]; then
    echo "Error: invalid --sort value: $SORT_BY"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed or not in PATH."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is unavailable. Start Docker and retry."
    exit 1
fi

echo "========== Docker Cleanup ==========" | tee "$LOG_FILE"
echo "Logs: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Errors: $ERROR_LOG" | tee -a "$LOG_FILE"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Options: sort=$SORT_BY only=${ONLY_CATEGORY:-ALL} min_size=$(numfmt --to=iec --suffix=B "$MIN_SIZE_BYTES") top=${TOP_N:-ALL}" | tee -a "$LOG_FILE"
echo "------------------------------------" | tee -a "$LOG_FILE"
: >"$ERROR_LOG"

rows_file="$(mktemp)"

append_row() {
    local category="$1"
    local action="$2"
    local reason="$3"
    local size_bytes="$4"
    local last_used_epoch="$5"
    local resource_id="$6"
    local name="$7"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$category" "$action" "$reason" "$size_bytes" "$last_used_epoch" "$resource_id" "$name" >>"$rows_file"
}

# 1) Stopped containers
while IFS=$'\t' read -r cid cname ccreated; do
    [[ -z "$cid" ]] && continue
    csize="$(docker inspect --size -f '{{.SizeRw}}' "$cid" 2>>"$ERROR_LOG" || echo 0)"
    csize="${csize:-0}"
    cepoch="$(date -d "$ccreated" +%s 2>/dev/null || echo 0)"
    append_row "CONTAINER_STOPPED" "DELETE" "stopped_container" "$csize" "$cepoch" "$cid" "$cname"
done < <(docker ps -a --filter status=exited --format '{{.ID}}\t{{.Names}}\t{{.CreatedAt}}' 2>>"$ERROR_LOG")

# 2) Dangling images
while IFS= read -r iid; do
    [[ -z "$iid" ]] && continue
    iname="$(docker image inspect -f '{{if .RepoTags}}{{index .RepoTags 0}}{{else}}<none>:<none>{{end}}' "$iid" 2>>"$ERROR_LOG" || echo "$iid")"
    isize="$(docker image inspect -f '{{.Size}}' "$iid" 2>>"$ERROR_LOG" || echo 0)"
    iepoch="$(docker image inspect -f '{{.Created}}' "$iid" 2>>"$ERROR_LOG" | xargs -I{} date -d "{}" +%s 2>/dev/null || echo 0)"
    append_row "IMAGE_DANGLING" "DELETE" "dangling_image" "$isize" "$iepoch" "$iid" "$iname"
done < <(docker image ls --filter dangling=true -q 2>>"$ERROR_LOG" | sort -u)

# 3) Unused non-dangling images (not referenced by any container)
while IFS= read -r iid; do
    [[ -z "$iid" ]] && continue
    iname="$(docker image inspect -f '{{if .RepoTags}}{{index .RepoTags 0}}{{else}}<none>:<none>{{end}}' "$iid" 2>>"$ERROR_LOG" || echo "$iid")"
    ref_count="$(docker ps -a --filter ancestor="$iid" -q 2>>"$ERROR_LOG" | awk 'NF{c++} END{print c+0}')"
    [[ "$ref_count" -gt 0 ]] && continue
    isize="$(docker image inspect -f '{{.Size}}' "$iid" 2>>"$ERROR_LOG" || echo 0)"
    iepoch="$(docker image inspect -f '{{.Created}}' "$iid" 2>>"$ERROR_LOG" | xargs -I{} date -d "{}" +%s 2>/dev/null || echo 0)"
    append_row "IMAGE_UNUSED" "DELETE" "unused_image" "$isize" "$iepoch" "$iid" "$iname"
done < <(docker image ls -q 2>>"$ERROR_LOG" | sort -u)

# 4) Unused networks (exclude defaults)
while IFS=$'\t' read -r nid nname ncreated ncontainers; do
    [[ -z "$nid" ]] && continue
    [[ "$nname" == "bridge" || "$nname" == "host" || "$nname" == "none" ]] && continue
    [[ "${ncontainers:-0}" -gt 0 ]] && continue
    nepoch="$(date -d "$ncreated" +%s 2>/dev/null || echo 0)"
    append_row "NETWORK_UNUSED" "DELETE" "unused_network" 0 "$nepoch" "$nid" "$nname"
done < <(docker network ls -q 2>>"$ERROR_LOG" | while read -r nid; do
    [[ -z "$nid" ]] && continue
    docker network inspect -f '{{.Id}}\t{{.Name}}\t{{.Created}}\t{{len .Containers}}' "$nid" 2>>"$ERROR_LOG"
done)

# 5) Unused volumes
while IFS= read -r vname; do
    [[ -z "$vname" ]] && continue
    attached="$(docker ps -a --filter volume="$vname" -q 2>>"$ERROR_LOG" | awk 'NF{c++} END{print c+0}')"
    [[ "$attached" -gt 0 ]] && continue
    vmount="$(docker volume inspect -f '{{.Mountpoint}}' "$vname" 2>>"$ERROR_LOG" || true)"
    vcreated="$(docker volume inspect -f '{{.CreatedAt}}' "$vname" 2>>"$ERROR_LOG" || true)"
    veepoch="$(date -d "$vcreated" +%s 2>/dev/null || echo 0)"
    vsize=0
    if [[ -n "$vmount" && -d "$vmount" ]]; then
        vsize="$(du -sb "$vmount" 2>>"$ERROR_LOG" | awk '{print $1}')"
        vsize="${vsize:-0}"
    fi
    append_row "VOLUME_UNUSED" "DELETE" "unused_volume" "$vsize" "$veepoch" "$vname" "$vname"
done < <(docker volume ls -q 2>>"$ERROR_LOG" | sort -u)

# 6) Build cache (single aggregate row)
build_cache_size=0
if docker builder du >/dev/null 2>&1; then
    build_cache_size="$(
        docker builder du 2>>"$ERROR_LOG" | awk '
            BEGIN {sum=0}
            /TOTAL|Total/ {next}
            NF>=4 {
                size=$3
                gsub(/ /,"",size)
                if (size ~ /^[0-9.]+[kKmMgGtT]?[iI]?[bB]?$/) print size
            }' | while read -r token; do
                parse_size_to_bytes "$token"
            done | awk '{s+=$1} END {print s+0}'
    )"
fi
append_row "BUILD_CACHE" "DELETE" "unused_build_cache" "${build_cache_size:-0}" 0 "builder-cache" "docker-builder-cache"

# Filtering and sorting
filtered_rows="$(mktemp)"
cp "$rows_file" "$filtered_rows"

if [[ -n "$ONLY_CATEGORY" ]]; then
    awk -F '\t' -v c="$ONLY_CATEGORY" '$1==c' "$filtered_rows" >"${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi
if [[ "$MIN_SIZE_BYTES" -gt 0 ]]; then
    awk -F '\t' -v m="$MIN_SIZE_BYTES" '$4>=m' "$filtered_rows" >"${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi

sort_spec="-k4,4nr"
case "$SORT_BY" in
    age) sort_spec="-k5,5nr" ;;
    name) sort_spec="-k7,7" ;;
    category) sort_spec="-k1,1 -k4,4nr" ;;
esac
sort $sort_spec "$filtered_rows" > "${filtered_rows}.sorted"
mv "${filtered_rows}.sorted" "$filtered_rows"

if [[ "$TOP_N" -gt 0 ]]; then
    awk -v n="$TOP_N" 'NR<=n' "$filtered_rows" >"${filtered_rows}.tmp" && mv "${filtered_rows}.tmp" "$filtered_rows"
fi

total_size_bytes="$(awk -F '\t' '{s+=$4} END {print s+0}' "$filtered_rows")"

while IFS=$'\t' read -r category action reason size_bytes last_epoch rid name; do
    [[ -z "$category" ]] && continue
    size_human="$(numfmt --to=iec --suffix=B "${size_bytes:-0}")"
    if [[ "$total_size_bytes" -gt 0 ]]; then
        pct="$(awk -v s="$size_bytes" -v t="$total_size_bytes" 'BEGIN {printf "%.1f%%", (s/t)*100}')"
    else
        pct="0.0%"
    fi
    if [[ "${last_epoch:-0}" -gt 0 ]]; then
        last_used="$(date -d "@$last_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "-")"
        now_epoch="$(date +%s)"
        age_days="$(( (now_epoch - last_epoch) / 86400 ))"
    else
        last_used="-"
        age_days="-"
    fi

    report_categories+=("$category")
    report_actions+=("$action")
    report_reasons+=("$reason")
    report_sizes_bytes+=("$size_bytes")
    report_sizes_human+=("$size_human")
    report_percentages+=("$pct")
    report_age_days+=("$age_days")
    report_last_used+=("$last_used")
    report_ids+=("$rid")
    report_names+=("$name")
done <"$filtered_rows"

found_count="${#report_categories[@]}"
if [[ "$found_count" -eq 0 ]]; then
    echo "No reclaimable Docker resources match the selected filters." | tee -a "$LOG_FILE"
    echo "====================================" | tee -a "$LOG_FILE"
    rm -f "$rows_file" "$filtered_rows"
    exit 0
fi

echo "Inventory report:" | tee -a "$LOG_FILE"
printf '%-4s %-19s %-8s %-20s %-9s %-9s %-16s %s\n' \
    "ID" "CATEGORY" "ACTION" "REASON" "%TOTAL" "AGE_DAYS" "LAST_USED" "NAME" | tee -a "$LOG_FILE"
printf '%-4s %-19s %-8s %-20s %-9s %-9s %-16s %s\n' \
    "----" "-------------------" "------" "--------------------" "-------" "--------" "----------------" "----" | tee -a "$LOG_FILE"

for i in "${!report_categories[@]}"; do
    row_color="$(category_color "${report_categories[$i]}")"
    printf '%b%-4s %-19s %-8s %-20s %-9s %-9s %-16s %s%b\n' \
        "$row_color" \
        "$((i + 1))" \
        "${report_categories[$i]}" \
        "${report_actions[$i]}" \
        "${report_reasons[$i]}" \
        "${report_percentages[$i]}" \
        "${report_age_days[$i]}" \
        "${report_last_used[$i]}" \
        "${report_names[$i]}" \
        "$C_RESET" | tee -a "$LOG_FILE"
done

reclaimable_count="$(printf '%s\n' "${report_actions[@]}" | awk '$1=="DELETE"{c++} END{print c+0}')"
echo "------------------------------------" | tee -a "$LOG_FILE"
echo "${C_BOLD}Found rows: $found_count${C_RESET}" | tee -a "$LOG_FILE"
echo "Reclaimable rows: $reclaimable_count" | tee -a "$LOG_FILE"
echo "Total estimated reclaimable size: $(numfmt --to=iec --suffix=B "$total_size_bytes")" | tee -a "$LOG_FILE"
echo "Rows by category:" | tee -a "$LOG_FILE"
printf '%s\n' "${report_categories[@]}" | sort | uniq -c | awk '{printf "  - %s: %s\n", $2, $1}' | tee -a "$LOG_FILE"

echo "Top largest reclaimable entries:" | tee -a "$LOG_FILE"
for idx in $(seq 0 $((found_count - 1))); do
    printf '%s\t%s\t%s\n' "${report_sizes_bytes[$idx]}" "${report_categories[$idx]}" "${report_names[$idx]}"
done | sort -nr | awk 'NR<=5 {printf "  - %s (%s)\n", $3, $2}' | tee -a "$LOG_FILE"

read -rp "Delete ALL rows marked DELETE (aggressive includes unused volumes)? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Deletion skipped by user." | tee -a "$LOG_FILE"
    echo "====================================" | tee -a "$LOG_FILE"
    rm -f "$rows_file" "$filtered_rows"
    exit 0
fi

deleted_count=0
failed_count=0
freed_size_bytes=0

delete_category_rows() {
    local target_category="$1"
    for i in "${!report_categories[@]}"; do
        [[ "${report_categories[$i]}" != "$target_category" ]] && continue
        [[ "${report_actions[$i]}" != "DELETE" ]] && continue
        rid="${report_ids[$i]}"
        name="${report_names[$i]}"
        size_bytes="${report_sizes_bytes[$i]}"
        size_human="${report_sizes_human[$i]}"

        case "$target_category" in
            CONTAINER_STOPPED) cmd=(docker rm "$rid") ;;
            NETWORK_UNUSED) cmd=(docker network rm "$rid") ;;
            VOLUME_UNUSED) cmd=(docker volume rm "$rid") ;;
            IMAGE_UNUSED|IMAGE_DANGLING) cmd=(docker image rm "$rid") ;;
            BUILD_CACHE) cmd=(docker builder prune -af) ;;
            *) continue ;;
        esac

        if "${cmd[@]}" >/dev/null 2>>"$ERROR_LOG"; then
            deleted_count=$((deleted_count + 1))
            freed_size_bytes=$((freed_size_bytes + size_bytes))
            printf '%b  ✔ Deleted %-19s %-12s %s%b\n' \
                "$(category_color "$target_category")" \
                "$target_category" \
                "$size_human" \
                "$name" \
                "$C_RESET" | tee -a "$LOG_FILE"
        else
            failed_count=$((failed_count + 1))
            printf '%b  ✘ Failed  %-19s %-12s %s%b\n' \
                "$C_RED" \
                "$target_category" \
                "$size_human" \
                "$name" \
                "$C_RESET" | tee -a "$LOG_FILE"
        fi

        # Build cache prune is global; execute once.
        if [[ "$target_category" == "BUILD_CACHE" ]]; then
            break
        fi
    done
}

# Planned safe delete order.
delete_category_rows "CONTAINER_STOPPED"
delete_category_rows "NETWORK_UNUSED"
delete_category_rows "VOLUME_UNUSED"
delete_category_rows "IMAGE_DANGLING"
delete_category_rows "IMAGE_UNUSED"
delete_category_rows "BUILD_CACHE"

echo "------------------------------------" | tee -a "$LOG_FILE"
echo "Cleanup Summary:" | tee -a "$LOG_FILE"
echo "  Deleted rows     : $deleted_count" | tee -a "$LOG_FILE"
echo "  Failed rows      : $failed_count" | tee -a "$LOG_FILE"
echo "  Estimated freed  : $(numfmt --to=iec --suffix=B "$freed_size_bytes")" | tee -a "$LOG_FILE"
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"

rm -f "$rows_file" "$filtered_rows"
