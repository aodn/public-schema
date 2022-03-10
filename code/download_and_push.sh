#!/bin/bash
# Download the resources for a given product group and push to incoming directory


if [ $# -lt 2 ]; then
  echo "usage: $(basename $0) product_group incoming_dir"
  exit 1
fi
product=$1; shift
incoming_dir=$1; shift

SCRIPT_PATH=$(dirname $(realpath $0))
SCHEMA_PATH=$(dirname "${SCRIPT_PATH}")
echo "Script path: ${SCRIPT_PATH}"
echo "Schema path: ${SCHEMA_PATH}"

# Create temp directory to download into
tmpdir=$(mktemp -p "${DATA_SERVICES_TMP_DIR:-/tmp}" -d imos_bgc_db.XXXXXX)
echo "Temp dir: ${tmpdir}"

# Select required resource files and download
resources=$(grep ${product} ${SCHEMA_PATH}/product_index.csv | cut -d, -f2)
for f in ${resources}; do
  ${SCRIPT_PATH}/download_resource.sh "$tmpdir" "${SCHEMA_PATH}/${f}"
done

# Zip them up
echo
echo "Creating ${product}.zip"
zip -jTm "${tmpdir}/${product}.zip" "${tmpdir}"/*.csv

# Push to incoming directory
echo
cp -v "${tmpdir}/${product}.zip" $incoming_dir

# Clean up temp directory
rm -r $tmpdir
