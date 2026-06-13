# Task Spec Template (commander → Codex / Claude subagent)

Copy into `docs/tasks/<executor>-p<priority>-<n>-<slug>.md` (executor: codex | sonnet | opus).
Specs must be executable cold — the implementer has no access to the planning conversation.
Reference examples of completed specs: your project's completed-specs archive (e.g. `.claude/tasks-archive/done/`).

---

# [Codex] P<priority>-<n>: <one-line title of the change>

## 前提コンテキスト
- 対象: <stack, e.g. Tauri 2 + React + plain CSS>. 作業ディレクトリ: `<repo-relative path>`.
- 関連する設計判断: <which library/function/module to build on — decided by the commander, not the implementer>
- 検証コマンド: `<build/test commands — include known sandbox workarounds verbatim,
  e.g. use npm.cmd not npm; see project CLAUDE.md 既知の問題>`. UI確認: `<how to launch>`.
- 依存: <other task specs that must land first, or "なし">

## 納品形態
- ブランチ: `<branch name>`（新規作成 or 既存）。並行タスクがある場合は専用の
  `git worktree` を作って作業すること。
- 既定: 実装完了後、コミット（メッセージは英語・変更単位ごと）→ push → draft PR 作成
  → CI green まで確認して PR URL を報告する。
- <リモートが無い/共有ワークツリーの場合のみ: "コミットせず作業ツリーに残す" と明記>

## 現状
<What is wrong / missing, and why (root cause if known).>

### 現状コード
<For every region the spec changes: exact file paths + line numbers + verbatim
current snippets (the delegated specs that passed first-try all did this — default
to it for bug-fix/refactor work). Use plain pointers only for surrounding context
the implementer navigates but does not modify.>

## 変更指示
<Numbered, concrete steps. For each step state file path and what to change.
Mark explicitly which decisions are FIXED (architecture, API shape, naming) and
which are the implementer's choice ("実装方法は任せるが、〜を維持すること").>

## 受け入れ基準
<Checkable list. Each item verifiable by command or quick manual check:>
- <behavioral criterion 1>
- <behavioral criterion 2>
- `<build command>` が通る。
- <if applicable> 既存テストが全て通る / 新規テスト `<path>` を追加し通る。
