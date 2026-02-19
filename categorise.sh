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
        # General Information
        id="$(jq -r '.id' <<<"$line")"
        type="$(jq -r '.type' <<<"$line")"

        # Actor Information
        actor_id="$(jq -r '.actor.id' <<<"$line")"
        actor_name="$(jq -r '.actor.display_login' <<<"$line")"

        # Repository Information
        repo_id="$(jq -r '.repo.id' <<<"$line")"
        repo_name="$(jq -r '.repo.name' <<<"$line")"

        echo "---"
        echo "ID: $id"
        echo "Type: $type"
        echo "Actor ID: $actor_id"
        echo "Actor Name: $actor_name"
        echo "Repo ID: $repo_id"
        echo "Repo Name: $repo_name"
    fi
done < "$DATAFILE"