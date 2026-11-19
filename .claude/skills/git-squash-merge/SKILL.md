---
name: git-squash-merge
description: 把源分支（如 dev）的代码压缩成单个提交合入目标分支（如 main）并推送，或把某分支删除后基于 main 重建。当用户提出「把 dev 合并到 main 但不要那么多提交记录」「只要一条提交」「压缩合并 / squash merge」「推送但历史保持干净」「删掉 dev 重新拉一个 dev」「分支历史清零」时使用。适用于任何 git 仓库，本仓库默认 dev 合到 main。
agent_created: true
---

# Git 压缩合并（单提交）

## 概述

把一个分支几十上百条提交的**最终代码状态**，压成目标分支上的**一条提交**再推送，目标分支历史保持线性干净（`main` 上只有 `Initial release` + 本次那条）。附带把分支删除后从 `main` 重建的能力，用于连源分支历史一起丢掉。

核心命令只有两步：`git merge --squash <source>` + `git commit`。真正的风险都在前置检查上，不要跳过。

## 触发场景

- 「把 dev 的代码合并到 main 并推送，但我不要所有提交记录，只要一个」
- 「压缩合并」「squash 一下再推」
- 「删掉本地 dev，重新从 main 拉一个 dev」
- 需要把长期攒了一堆 `save` 提交的开发分支一键落到主干

不适用：需要保留逐个提交历史的正常合并（直接 `git merge --no-ff`）、需要 rebase 逐个改写提交。

## 使用方式

优先直接跑脚本，不要手敲命令序列 —— 脚本已内置备份、校验和失败回滚提示。

### 1. 压缩合并（主流程）

```bash
bash .claude/skills/git-squash-merge/scripts/squash_merge.sh [source] [target] -m "提交信息"
```

- 默认 `dev -> main`，不带 `-m` 时会提示输入。
- `--dry-run` 先看计划：待压缩提交列表、改动规模、是否会冲突，不动仓库。
- `--no-push` 只提交不推送。
- 脚本行为：校验工作区干净 → 列待压缩提交 → 打备份引用 `refs/squash-backup/main-<时间戳>` → 切到 target → `merge --squash` → 单次 `commit` → 校验 target 与 source 内容一致 → `push origin <target>`。

### 2. 重建分支（丢掉源分支历史）

```bash
bash .claude/skills/git-squash-merge/scripts/reset_branch.sh dev main
```

先备份旧分支、`git branch -D`、再 `git checkout -b dev main`。默认不动远程；确认要同步远程时加 `--push`（走 `--force-with-lease`）。若分支内容与 `main` 不一致，脚本会红字警告「重建会丢代码」，此时先确认已合并。

## 执行前必查

1. **工作区是否干净**（`git status --porcelain` 有输出就是脏）。
2. **待压缩提交清单**（`git log --oneline main..dev`）——顺手确认没有误提交/敏感文件。
3. **是否分叉**：`git rev-list --count main..dev`（要合的）与 `git rev-list --count dev..main`（main 独有的）。后者 > 0 说明两分支已分叉，压缩合并要做三方合并，可能冲突。
4. **commit message**：不要用脚本的默认占位。按实际内容概括，问用户或给 2-3 个候选让其选。

## 提交信息约定

- 中文描述、`type: 摘要` 形式（`feat:` / `fix:` / `chore:` / `release:`）。
- 例：`feat: 初版 Flutter 客户端与后端联调`。
- 因为是「一个提交装下整批改动」，摘要要写本批的**主题**，不要写 merge 字样。

## 已知坑（都踩过，务必照做）

**1. 脏工作区必须先提交，不能靠 checkout 绕过。**
若某文件只存在于源分支、目标分支没有，`git checkout main` 会直接拒绝（"local changes would be overwritten"）。用户要求「改动一起并进去」时，正确做法是先在**源分支**上 `git add -A && git commit`，让它进入压缩范围，而不是 stash。

**2. `--squash` 不产生 merge commit，两条分支在图上仍是「未合并」。**
所以：
- `git branch -d dev` 会报 "not fully merged" 而拒绝，必须 `-D`；
- 以后从 dev 再合 main，git 无法自动识别「上次已合过」，每次都得继续 squash（或改用 rebase），不能指望普通 merge 认清关系。
- 一旦重建 dev（从 main 拉新分支），这个「已合并」关系就恢复了，最干净。

**3. 远程分支删了，本地追踪引用还在。**
`git branch -a` 仍显示 `remotes/origin/dev`。跑一次 `git fetch --prune` 清掉，否则 `git status` 里的「ahead of origin/dev」会误导。

**4. commit 钩子可能返回非零但提交其实成功了。**
本仓库就出现过：`git commit` 输出正常、HEAD 已前进，退出码却是 1。脚本默认会二次校验 HEAD 是否变化；遇到时用 `--allow-hooks-fail`。手敲命令时用 `git log -1 --oneline` 核对，别急着重复提交。

**5. 大仓库 squash 要留意入库体积。**
本仓库曾把 5.7MB 的构建产物、920MB 的构建缓存混进提交。压缩合并前用 `git diff --cached --stat`（或 `--dry-run`）扫一眼文件数和体积，异常大就先把产物从索引里摘掉（`git rm -r --cached <dir>` + 写 `.gitignore`）。

## 完成后校验

```bash
git log --oneline -3                 # target 上应只多出 1 条
git diff main dev --stat             # 应为空（内容一致）
git log --oneline origin/main -2     # 远程已更新到那条压缩提交
git rev-list --count main            # 提交总数
```

四项都对再向用户报告；任何一项不符，先把输出贴给用户，不要宣布成功。

## 回滚

```bash
git reset --hard refs/squash-backup/main-<时间戳>
git push --force-with-lease origin main
```

脚本每次执行都会新建这个引用，误操作永远有退路。确认无误后可用 `git update-ref -d <ref>` 清掉旧备份。

## 本仓库速记

- 远程 `origin` = `https://github.com/getmoneynote/moneynote.git`，主干 `main`，开发 `dev`。
- 2026-11-18 已做过一次：11 个 `save`/`Flutter` 提交压成 `feat: 初版 Flutter 客户端与后端联调`（236 文件 / +11375 −9），`main` 与 `dev` 现均指向该提交。
- 本 skill 正文与脚本的正式位置是 `.claude/skills/git-squash-merge/`（随仓库提交、Claude Code 直接可用）；`.workbuddy/skills/git-squash-merge/SKILL.md` 只是给 WorkBuddy 的入口存根，改内容只改这里。
