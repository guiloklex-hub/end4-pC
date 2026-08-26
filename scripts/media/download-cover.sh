#!/usr/bin/env bash
set -euo pipefail

url="${1:?missing cover URL}"
output="${2:?missing cover output path}"

if [[ -s "$output" ]]; then
    exit 0
fi

output_dir=$(dirname -- "$output")
install -d -m 700 "$output_dir"
temporary_file=$(mktemp --tmpdir="$output_dir" '.cover.XXXXXX')
trap 'rm -f -- "$temporary_file"' EXIT

curl --silent --show-error --fail --location --output "$temporary_file" -- "$url"
chmod 600 "$temporary_file"
mv -f -- "$temporary_file" "$output"
trap - EXIT
