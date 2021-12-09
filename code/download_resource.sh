#!/bin/bash

# Download the resources specified on the command line


# download a resource from a URL (assumed to be geoserver) to a CSV file
# $1 - directory to save the CSV file into
# $2 - full path to resource file
function extract_resource {
  output_dir=$1; shift
  res_file=$1; shift

  echo
  echo "Extracting ${res_file} ..."

  url=$(grep '^path' "$res_file" | grep -oE '\S+\s*$')
  if [ -z "$url" ]; then
    echo "No resource URL found in ${res_file}!"
    return
  fi
  echo "  URL: $url"

  name=$(grep '^name:' "$t" | grep -oE '\w+\s*$')
  if [ -z "$name" ]; then
    echo "No resource name found in ${res_file}!"
    return
  fi
  output_file="${output_dir}/${name}.csv"
  echo "  output: ${output_file}"

  curl --silent --show-error "$url" | cut -d, -f2- >"$output_file"
  # frictionless extract "${res_file}" --skip-fields FID --csv >"${output_file}"
}


## MAIN
output_dir=$1; shift
if [ ! -d "$output_dir" ] || [ $# -lt 1 ]; then
  echo "usage: $(basename $0) output_dir resource_file ..."
  exit 1
fi

for t in "$@"; do
  extract_resource "$t" "$output_dir"
done
