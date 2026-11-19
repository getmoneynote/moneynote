#!/usr/bin/env bash
# 删除本地分支并基于 base 分支重建，用于「把某分支的历史也清零」。
# 危险操作：会丢弃该分支上所有未合入 base 的提交，脚本会先打备份引用。
set -uo pipefail

BRANCH="dev"
BASE="main"
PUSH=0
DRY_RUN=0

usage() {
  cat <<'EOF'
用法: reset_branch.sh [分支名] [base分支] [选项]

  分支名       要重建的本地分支，默认 dev
  base分支     重建的起点，默认 main

选项:
      --push    重建后强推以同步远程（git push -u --force-with-lease）
      --dry-run 只打印计划
  -h, --help    显示帮助

示例:
  reset_branch.sh                    # 用 main 重建 dev
  reset_branch.sh dev main --push
EOF
}

POS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知选项: $1" >&2; usage; exit 2 ;;
    *)
      POS=$((POS + 1))
      if [ $POS -eq 1 ]; then BRANCH="$1"; elif [ $POS -eq 2 ]; then BASE="$1"; else
        echo "多余参数: $1" >&2; usage; exit 2
      fi
      shift ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 git 仓库"
cd "$(git rev-parse --show-toplevel)" || die "无法进入仓库根目录"

[ "$BRANCH" != "$BASE" ] || die "分支名与 base 不能相同"

echo "计划: 删除本地 $BRANCH 并从 $BASE 重建$([ $DRY_RUN -eq 1 ] && echo ' [dry-run]')"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "✗ 工作区有未提交的改动，请先提交或 stash：" >&2
  git status --short --untracked-files=no >&2
  exit 1
fi

UNTRACKED="$(git status --porcelain --untracked-files=normal | grep '^??' || true)"
if [ -n "$UNTRACKED" ]; then
  echo "  ⚠ 有未跟踪文件，它们会原样保留在磁盘上（不影响重建）："
  echo "$UNTRACKED" | head -3 | sed 's/^/    /'
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  LOST="$(git rev-list --count "$BASE..$BRANCH" 2>/dev/null || echo '?')"
  echo "  $BRANCH 上有 $LOST 个 $BASE 没有的提交将被丢弃："
  git log --oneline "$BASE..$BRANCH" 2>/dev/null | head -20 | sed 's/^/    /'
  if [ "$LOST" != "0" ] && [ "$LOST" != "?" ]; then
    # 内容层面校验：若与 base 完全一致，丢弃历史是安全的
    if git diff --quiet "$BASE" "$BRANCH"; then
      echo "  （内容与 $BASE 完全一致，仅历史不同，可安全重建）"
    else
      echo "  ⚠ 内容与 $BASE 不一致！重建会丢失这些代码改动，请先确认已合并。"
    fi
  fi
else
  echo "  本地没有 $BRANCH，将直接创建"
fi

[ $DRY_RUN -eq 1 ] && { echo "🔍 dry-run 结束"; exit 0; }

STAMP="$(date +%Y%m%d-%H%M%S)"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  BACKUP_REF="refs/squash-backup/${BRANCH}-${STAMP}"
  git update-ref "$BACKUP_REF" "$(git rev-parse "$BRANCH")"
  echo "  备份: $BACKUP_REF（git branch <新名> $BACKUP_REF 可找回）"
  # 当前就在被删分支上时先切到 base
  if [ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ]; then
    git checkout "$BASE" || die "切换到 $BASE 失败"
  fi
  git branch -D "$BRANCH" || die "删除 $BRANCH 失败"
fi

git checkout -b "$BRANCH" "$BASE" || die "创建 $BRANCH 失败"

echo
echo "✓ 已重建 $BRANCH（起点 $BASE @ $(git rev-parse --short "$BASE")），当前分支: $(git rev-parse --abbrev-ref HEAD)"

if [ $PUSH -eq 1 ]; then
  echo "强推同步远程..."
  git push -u --force-with-lease origin "$BRANCH" || die "推送失败（远程 $BRANCH 若不存在会新建）"
  echo "✓ 已同步 origin/$BRANCH"
else
  echo "  $BRANCH 暂无 upstream。首次推送: git push -u origin $BRANCH"
fi
