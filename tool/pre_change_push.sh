#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c git --version >/dev/null 2>&1; then
  GIT_CMD=(cmd.exe /c git)
  echo "检测到 Win 侧 Git，优先复用 Windows 已登录的 GitHub 凭据。"
else
  GIT_CMD=(git)
fi

git_run() {
  "${GIT_CMD[@]}" "$@"
}

git_capture() {
  git_run "$@" | tr -d '\r'
}

if ! git_run rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "当前目录不是 Git 仓库，无法执行修改前推送。"
  exit 1
fi

if ! git_run remote get-url origin >/dev/null 2>&1; then
  echo "未配置 origin 远端，请先配置 GitHub 仓库地址。"
  exit 1
fi

branch="$(git_capture symbolic-ref --short HEAD 2>/dev/null || echo main)"
message="${*:-chore: pre-change checkpoint $(date '+%Y-%m-%d %H:%M:%S')}"

has_uncommitted_changes=false
if ! git_run diff --quiet || ! git_run diff --cached --quiet; then
  has_uncommitted_changes=true
fi

if [ -n "$(git_capture ls-files --others --exclude-standard)" ]; then
  has_uncommitted_changes=true
fi

if [ "$has_uncommitted_changes" = true ]; then
  git_run add -A
  git_run commit -m "$message"
else
  echo "当前没有本地改动，直接执行推送。"
fi

git_run push origin "$branch"

echo "修改前推送完成：origin/$branch"
