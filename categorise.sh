#!/bin/bash

# Data file to sort through
DATAFILE="GitHubJanuary.json"

# Ensure dependencies are present
require() {
  if ! command -v jq &> /dev/null; then
    echo "jq command is not present. Please install command or run in Colab"
    exit 1
  fi
}
require

while IFS= read -r line; do
    if [ -n "$line" ]; then
        id="$(jq -r '.id' <<<"$line")"
        type="$(jq -r '.type' <<<"$line")"

        echo "id: $id"
        echo "type: $type"

        echo "---"
    fi
done < "$DATAFILE"