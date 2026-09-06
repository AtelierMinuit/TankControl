#!/bin/bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
ppd="${project_root}/research/builds/hp-smart_tank_500_series.ppd"
hpcups="${project_root}/research/builds/hpcups_arm64"
pdf_dir="${project_root}/research/corpus/pdf"
raster_dir="${project_root}/research/corpus/raster"
stream_dir="${project_root}/research/corpus/streams"
log_dir="${project_root}/research/corpus/logs"

for required in /usr/sbin/cupsfilter "${ppd}" "${hpcups}"; do
    if [[ ! -e "${required}" ]]; then
        echo "missing required path: ${required}" >&2
        exit 1
    fi
done

mkdir -p "${raster_dir}" "${stream_dir}" "${log_dir}"

run_case() {
    local job_id="$1"
    local source_name="$2"
    local output_name="$3"
    shift 3
    local -a options=("$@")
    local -a cups_options=()
    local option
    local option_string=""
    local input_pdf="${pdf_dir}/${source_name}.pdf"
    local raster="${raster_dir}/${output_name}.raster"
    local stream="${stream_dir}/${output_name}.pcl3gui"
    local raster_tmp
    local stream_tmp

    if [[ ! -f "${input_pdf}" ]]; then
        echo "missing input PDF: ${input_pdf}" >&2
        return 1
    fi

    for option in "${options[@]}"; do
        cups_options+=( -o "${option}" )
        if [[ -n "${option_string}" ]]; then
            option_string+=" "
        fi
        option_string+="${option}"
    done

    raster_tmp="$(mktemp "${raster}.tmp.XXXXXX")"
    stream_tmp="$(mktemp "${stream}.tmp.XXXXXX")"
    trap 'rm -f "${raster_tmp:-}" "${stream_tmp:-}"' RETURN

    /usr/sbin/cupsfilter \
        -p "${ppd}" \
        -m application/vnd.cups-raster \
        "${cups_options[@]}" \
        "${input_pdf}" \
        > "${raster_tmp}" \
        2> "${log_dir}/${output_name}.cupsfilter.log"

    /usr/bin/env "PPD=${ppd}" \
        "${hpcups}" \
        "${job_id}" jorge "${output_name}" 1 "${option_string}" "${raster_tmp}" \
        > "${stream_tmp}" \
        2> "${log_dir}/${output_name}.hpcups.log"

    mv "${raster_tmp}" "${raster}"
    mv "${stream_tmp}" "${stream}"
    trap - RETURN

    echo "generated ${output_name}: raster=$(wc -c < "${raster}") stream=$(wc -c < "${stream}")"
}

if [[ "$#" -eq 0 ]]; then
    set -- 11-a4 11-a4-borderless 12-normal600 12-photo1200 13-normal 13-best
fi

for requested_case in "$@"; do
    case "${requested_case}" in
        11-a4)
            run_case 1101 11-a4-full 11-a4-full ColorModel=RGB PageSize=A4 OutputMode=Normal
            ;;
        11-a4-borderless)
            run_case 1102 11-a4-full 11-a4-borderless ColorModel=RGB PageSize=A4.FB OutputMode=Normal
            ;;
        12-normal600)
            run_case 1201 12-resolution-source 12-normal600 ColorModel=RGB PageSize=Letter OutputMode=Normal
            ;;
        12-photo1200)
            run_case 1202 12-resolution-source 12-photo1200 ColorModel=RGB PageSize=Letter OutputMode=Photo
            ;;
        13-normal)
            run_case 1301 13-quality-source 13-normal ColorModel=RGB PageSize=Letter OutputMode=Normal
            ;;
        13-best)
            run_case 1302 13-quality-source 13-best ColorModel=RGB PageSize=Letter OutputMode=Best
            ;;
        *)
            echo "unknown case: ${requested_case}" >&2
            exit 2
            ;;
    esac
done
