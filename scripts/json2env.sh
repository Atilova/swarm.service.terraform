#!/bin/bash
set -euo pipefail

tf_query=$(cat || echo '{}')

prefix=$(echo "$tf_query" | jq -r '.prefix')
json_env=$(echo "$tf_query" | jq -r '.json')

output=$(json2env --key-separator "__" <<< "$json_env" | \
  sed 's/=null$/=/' | \
  sed 's/,null"$/"/' | \
  sed 's/,null,/,/g' | \
  sed 's/^null,//g' | \
  sed "s/^/${prefix}/")

jq -n --arg env "$output" '{"env": $env}'
