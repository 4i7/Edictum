# Model Benchmarks & Delegation Reference

Edictum のモデル性能リファレンス（SKILL.md から参照）。出典は末尾。
数値は公開ベンチマーク（ベンダー公称含む、2026-06 時点）であり、相対比較の目安。
**末尾の「実測較正」は著者の例（n=7・TS+Rust）であって普遍値ではない** — 自分の
プロジェクトで数件回したら自分の観測で置き換え、未確認は 仮説/推定/要検証 と明記すること。

## 性能マトリクス

| モデル | SWE-bench Verified | SWE-bench Pro | Terminal-Bench | API価格 (in/out per MTok) |
|---|---|---|---|---|
| Claude Fable 5 | **95%** | **80.3%** | — | $10 / $50 |
| Claude Opus 4.8 | 88.6% | 69.2% | 74.6% (TB2.1) | $5 / $25 |
| Claude Opus 4.7 | 87.6% | 64.3% | 66.1% (TB2.1) | $5 / $25 |
| Claude Opus 4.6 | ~80.8%（要検証） | 53.4% | — | $5 / $25 |
| Claude Sonnet 4.6 | 79.6% | —（要検証） | — | $3 / $15 |
| GPT-5.5 | 88.7% | 58.6% | **82.7%** (TB2.0, SOTA) | $5 / $30 ※ |
| GPT-5.4 | —（要検証） | 57.7% | 競争力あり | ~$1.25 / $10（要検証） |
| GPT-5.4-mini | —（要検証） | 54.4% | 競争力あり | $0.75 / $4.50（$0.40/$1.60 説もあり・要検証） |

※ Codex は ChatGPT サブスクリプション経由で動作するため、本環境では Codex 側のトークンは Claude 側の利用枠を消費しない。これが委譲の最大の動機。

補足データ:
- Fable 5 は FrontierCode Diamond 29.3%（Opus 4.8 は 13.4%）。最難関タスクでの差が最も大きい。
- Fable 5 はサイバーセキュリティ・生物・化学・蒸留関連の要求では Opus 4.8 にフォールバックする。
- GPT-5.5 は Expert-SWE（中央値20時間級の長時間タスク）73.1%（GPT-5.4 は 68.5%）。長時間の自律実行に強い。
- GPT-5.5 は GPT-5.4 と同等レイテンシでトークン消費が少ない（公称）。
- GPT-5.4-mini は GPT-5.4 の約94%のコーディング性能（SWE-bench Pro 54.4% vs 57.7%）を大幅に低いコストで出す。OSWorld-Verified 72.1% と computer-use 系も強い。
- Opus 4.7/4.6 には SWE-bench Pro での解答リーク疑義の報告あり（DeepSWE、12%超）。Pro スコアの過信は禁物（要検証）。

## 読み方（タスク委譲の判断材料)

- **SWE-bench Verified** = 既知リポジトリでの標準的なバグ修正・実装能力。GPT-5.5 (88.7%) は Opus 4.8 (88.6%) と同格。日常実装は Codex で十分。
- **SWE-bench Pro** = 汚染対策済みの難関実装。Claude 系が明確に優位（Fable 5: 80.3% ≫ GPT-5.5: 58.6%）。難しい実装は Claude 側に残す根拠。
- **Terminal-Bench** = CLI 操作・環境構築・ツール連携。GPT-5.5 が SOTA (82.7%)。ビルド修復・環境系の調査タスクは Codex 向き。
- 設計・レビューの「目」の質はおおむね SWE-bench Pro / FrontierCode と相関すると考えてよい（推定）。レビューを Codex に出す価値は性能よりも「別プロバイダの独立視点（追従バイアス排除）」にある。

## Codex 側の指定方法

`/codex:rescue` / companion スクリプトで `--model <name>` と `--effort <none|minimal|low|medium|high|xhigh>` を指定。
ユーザーの UI 表記との対応: 低=low / 中=medium / 高=high / 非常に高い=xhigh。
デフォルト（~/.codex/config.toml）: `gpt-5.5` / `medium`。

既知の制約: `--effort minimal` は web_search / image_gen ツールと併用不可（400 エラーになる）。実質 `low` が下限。

## Claude 側サブエージェントの指定方法

Agent ツールの `model` パラメータ: `fable` / `opus` / `sonnet` / `haiku`（省略時はメインセッションを継承）。
注意: サブエージェントに thinking 強度（低/中/高/特大/MAX/UltraCode）を個別指定する仕組みはない。強度はセッション設定の継承。モデル選択のみが制御点。

## 実測較正（2026-06-11/12 の実走7件・要検証）

n=7・TS+Rust/web 単一リポジトリの一次データ。他スタック/ドメインへの一般化は要検証。
**実行経路が2系統あり、含意が異なる点に注意**:

- **プラグイン委譲5件**（gpt-5.5 / medium、**詳細スペック付き**＝パス+行番号+現コード
  逐語+回帰ケース）: 単一修正規模を各2.5〜5分で完走、全件一発PASS。サブトルな
  React effect-identity 無限ループ修正やシークレット越境バグ等を含む。
- **アプリ手動2件**（GPT-5.4 / medium、**ゴールレベルのみ・コード引用なし**、ただし
  人間監督下の手動 Codex）: ①セキュリティ監査→TS+Rust 横断修正→draft PR→CI green
  を17分、②UI全面改修+WCAG AA 検証+worktree/rebase を23.5分で完走。最難関タスクが
  最小のスペック詳細で通った点が重要。
- **含意**: (1) 推定:「困難だがスペック化可能」は Codex 領域 — メイン専任は「受け入れ
  基準が書けないタスク」のみ。(2) effort は medium が主力（5.4→5.5 で同設定の品質・
  トークン効率は向上）。(3) **委譲経路では詳細スペックが既定**（全件PASSの実証モード）。
  「ゴールのみで足りる」は手動経路でしか確認できておらず**仮説** — 委譲スペックを
  この理由で薄くしない。(4) 自律走行時間の上限値（>30分 / 15〜25分）は実測ではなく
  **推定**（観測最大は約24分）。境界に当たるまで確定しない。

## Sources

- https://openai.com/index/introducing-gpt-5-5/
- https://www.vellum.ai/blog/everything-you-need-to-know-about-gpt-5-5
- https://interestingengineering.com/ai-robotics/opanai-gpt-5-5-agentic-coding-gains
- https://www.vellum.ai/blog/claude-fable-5-and-mythos-5-benchmarks-explained
- https://www.morphllm.com/claude-benchmarks
- https://www.truefoundry.com/blog/claude-fable-5-vs-opus-4-8-benchmarks-pricing-when-to-use-each
- https://www.vellum.ai/blog/claude-opus-4-8-benchmarks-explained
- https://llm-stats.com/models/compare/claude-sonnet-4-6-vs-claude-opus-4-7
- https://www.datacamp.com/blog/gpt-5-4-mini-nano
- https://apidog.com/blog/gpt-5-5-pricing/
- https://agentnativedev.medium.com/deepswe-both-claude-opus-4-6-and-4-7-registered-cheated-on-more-than-12-of-reviewed-swe-bench-pro-b14e0982e127
