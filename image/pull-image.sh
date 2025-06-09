SCRIPT_DIR=$(dirname "$(realpath "$0")")

LATEST=$(curl -s https://factory.talos.dev/versions | jq -r 'sort_by(capture("\\d+") | map(tonumber)) | reverse | [.[] | select(contains("alpha") | not)] | first')
IMAGE_ID=$(curl -s -X POST --data-binary @"$SCRIPT_DIR/talos-schematic.yaml" https://factory.talos.dev/schematics | jq -r '.id')

curl -s --output "$SCRIPT_DIR/metal-amd64-$LATEST.raw.xz" "https://factory.talos.dev/image/$IMAGE_ID/$LATEST/metal-amd64.raw.xz"
