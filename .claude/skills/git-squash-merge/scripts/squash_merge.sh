#!/usr/bin/env bash
# 把 source 分支的代码压缩成【单个提交】合入 target 分支，并推送。
# 用法见 usage()。依赖 git，可在 Git Bash / macOS / Linux 下运行。
set -uo pipefail

SOURCE="dev"
TARGET="main"
MESSAGE=""
PUSH=1
DRY_RUN=0
NO_COMMIT_CHECK=0

usage() {
  cat <<'EOF'
用法: squash_merge.sh [source分支] [target分支] [选项]

  source分支   默认 dev
  target分支   默认 main

选项:
  -m, --message <msg>   压缩提交的 commit message（不给则交互式提示输入）
      --no-push         只提交不推送
      --dry-run         只打印将要做什么，不改动仓库
      --allow-hooks-fail 允许 commit 钩子返回非零（会二次校验 HEAD 是否真的前进）
  -h, --help            显示本帮助

示例:
  squash_merge.sh                                   # dev -> main
  squash_merge.sh dev main -m "feat: xxx"
  squash_merge.sh feature/x main --no-push
EOF
}

POS=0
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) MESSAGE="${2:-}"; shift 2 ;;
    --no-push) PUSH=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --allow-hooks-fail) NO_COMMIT_CHECK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知选项: $1" >&2; usage; exit 2 ;;
    *)
      POS=$((POS + 1))
      if [ $POS -eq 1 ]; then SOURCE="$1"; elif [ $POS -eq 2 ]; then TARGET="$1"; else
        echo "多余参数: $1" >&2; usage; exit 2
      fi
      shift ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }
info() { echo "  $*"; }

# ---------- 0. 定位仓库 ----------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 git 仓库"
cd "$(git rev-parse --show-toplevel)" || die "无法进入仓库根目录"
REPO="$(pwd)"

echo "仓库: $REPO"
echo "计划: $SOURCE -> $TARGET（压缩为单个提交）$([ $DRY_RUN -eq 1 ] && echo ' [dry-run]')"
echo

# ---------- 1. 分支存在性 ----------
git show-ref --verify --quiet "refs/heads/$SOURCE" || die "本地没有分支 $SOURCE"
git show-ref --verify --quiet "refs/heads/$TARGET" || die "本地没有分支 $TARGET"
[ "$SOURCE" != "$TARGET" ] || die "source 与 target 不能是同一个分支"

# ---------- 2. 工作区必须干净（只看已跟踪文件的改动） ----------
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "✗ 工作区有未提交的改动：" >&2
  git status --short --untracked-files=no >&2
  cat >&2 <<EOF

处理方式（二选一）：
  1) 想把这些改动一起并入本次提交：先 git add -A && git commit -m "..."（提交在 $SOURCE 上）
  2) 不想带上：git stash push -u            （合并完成后 git stash pop 恢复）

注意：不能只 checkout 了事。若某个文件只存在于 $SOURCE、$TARGET 里没有，
git 会因为「本地修改会被覆盖」拒绝切换分支。
EOF
  exit 1
fi

# 未跟踪文件不影响压缩合并，但不会进入提交；同名文件可能阻止切换分支
UNTRACKED="$(git status --porcelain --untracked-files=normal | grep '^??' || true)"
if [ -n "$UNTRACKED" ]; then
  echo "⚠ 存在未跟踪文件（不会进入本次提交，忽略即可）："
  echo "$UNTRACKED" | head -5 | sed 's/^/    /'
  echo
fi

# ---------- 3. 统计待压缩的提交 ----------
AHEAD="$(git rev-list --count "$TARGET..$SOURCE")"
BEHIND="$(git rev-list --count "$SOURCE..$TARGET")"

if [ "$AHEAD" -eq 0 ]; then
  echo "✓ $SOURCE 没有 $TARGET 之外的新提交，无需合并。"
  exit 0
fi

# 提交图上有差异、但内容可能已一致（典型的「上次已经 squash 过一次」）
if git diff --quiet "$TARGET" "$SOURCE"; then
  echo "✓ $SOURCE 与 $TARGET 内容完全一致（提交图不同，代码无差异），无需合并。"
  echo "  若想让两分支历史也一致: git branch -D $SOURCE && git checkout -b $SOURCE $TARGET"
  exit 0
fi

echo "待压缩提交数: $AHEAD"
git log --oneline "$TARGET..$SOURCE" | sed 's/^/    /'
if [ "$BEHIND" -gt 0 ]; then
  echo
  echo "⚠ $TARGET 上有 $BEHIND 个 $SOURCE 没有的提交（两分支已分叉），"
  echo "  压缩合并需要做三方合并，可能产生冲突，请人工确认。"
  git log --oneline "$SOURCE..$TARGET" | sed 's/^/    /'
fi
echo

# ---------- 4. 备份引用 ----------
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_REF="refs/squash-backup/${TARGET}-${STAMP}"
TARGET_SHA="$(git rev-parse "$TARGET")"
SOURCE_SHA="$(git rev-parse "$SOURCE")"
info "备份: $BACKUP_REF = $TARGET_SHA"
info "      (误操作后可用 git reset --hard $BACKUP_REF 回滚)"
echo

if [ $DRY_RUN -eq 1 ]; then
  echo "🔍 dry-run 结束，未做任何改动。"
  exit 0
fi

git update-ref "$BACKUP_REF" "$TARGET_SHA" || die "创建备份引用失败"

# ---------- 5. commit message ----------
if [ -z "$MESSAGE" ]; then
  if [ -t 0 ]; then
    echo "请输入压缩提交的 message（一行，回车确认）："
    read -r MESSAGE
  fi
fi
[ -n "$MESSAGE" ] || die "缺少 commit message，请用 -m \"...\" 指定"

# ---------- 6. 切到 target 并压缩合并 ----------
ORIG_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "切换分支: $ORIG_BRANCH -> $TARGET"
git checkout "$TARGET" || die "切换到 $TARGET 失败（可能有未跟踪文件会被覆盖）"

if ! git merge --squash "$SOURCE"; then
  echo
  echo "✗ 压缩合并出现冲突，仓库停在冲突状态。" >&2
  echo "  解决后: git add -A && git commit -m \"$MESSAGE\"" >&2
  echo "  放弃  : git reset --hard $BACKUP_REF && git checkout $ORIG_BRANCH" >&2
  exit 1
fi

if git diff --cached --quiet; then
  echo "✓ 两分支内容已一致（无实际差异），跳过提交。"
  git checkout "$ORIG_BRANCH" >/dev/null 2>&1 || true
  exit 0
fi

echo
echo "本次将提交的改动规模:"
git diff --cached --stat | tail -3

# ---------- 7. 提交 ----------
git commit -m "$MESSAGE" || {
  NEW_HEAD="$(git rev-parse HEAD)"
  if [ "$NO_COMMIT_CHECK" -eq 1 ] && [ "$NEW_HEAD" != "$TARGET_SHA" ]; then
    echo "⚠ commit 钩子返回非零，但 HEAD 已前进（$TARGET_SHA -> $NEW_HEAD），按成功处理。"
  else
    echo "✗ 提交失败，HEAD 仍是 $NEW_HEAD" >&2
    exit 1
  fi
}

NEW_SHA="$(git rev-parse --short HEAD)"
echo
echo "✓ 已生成单个提交: $NEW_SHA $(git log -1 --format=%s)"

# ---------- 8. 内容校验 ----------
if [ "$BEHIND" -eq 0 ]; then
  if git diff --quiet "$SOURCE" "$TARGET"; then
    info "校验通过：$TARGET 与 $SOURCE 内容完全一致"
  else
    echo "⚠ 警告：$TARGET 与 $SOURCE 内容仍有差异，请检查:" >&2
    git diff --stat "$SOURCE" "$TARGET" | tail -5 >&2
  fi
fi

# ---------- 9. 推送 ----------
if [ $PUSH -eq 1 ]; then
  echo
  echo "推送到远程..."
  if git push origin "$TARGET"; then
    echo "✓ 已推送 origin/$TARGET"
  else
    echo "✗ 推送失败。提交已生成在本地，修好凭证/网络后重试: git push origin $TARGET" >&2
    exit 1
  fi
else
  echo
  echo "（已跳过推送）如需推送: git push origin $TARGET"
fi

# ---------- 10. 收尾提示 ----------
echo
echo "完成。要点:"
echo "  - 压缩提交没有 merge commit，git 仍认为 $SOURCE「未合并」，"
echo "    所以删除该分支必须用 git branch -D（-d 会拒绝）。"
echo "  - 远程 $SOURCE 若已删除，运行 git fetch --prune 清掉过期追踪引用。"
echo "  - 当前所在分支: $(git rev-parse --abbrev-ref HEAD)（原分支 $ORIG_BRANCH）"
echo "  - 回滚本次操作: git reset --hard $BACKUP_REF && git push --force-with-lease origin $TARGET"
