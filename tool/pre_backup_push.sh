#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

message="${*:-chore: pre-backup checkpoint $(date '+%Y-%m-%d %H:%M:%S')}"

bash tool/pre_change_push.sh "$message"

echo "备份前推送检查点已完成。"
