# Model Benchmarks & Delegation Reference

Edictum's model-performance reference, linked from SKILL.md. Sources are listed at
the end. Numbers are public benchmarks, including vendor-published figures, current
as of 2026-06; use them for relative comparison, not as universal truth. The
measured calibration at the end is the author's example only (n=7, TS+Rust), not a
general value. After several runs on your own project, replace it with your own
observations and label anything unverified as hypothesis / inference / unverified.

## Performance Matrix

| Model | SWE-bench Verified | SWE-bench Pro | Terminal-Bench | API price (in/out per MTok) |
|---|---|---|---|---|
| Claude Fable 5 | **95%** | **80.3%** | — | $10 / $50 |
| Claude Opus 4.8 | 88.6% | 69.2% | 74.6% (TB2.1) | $5 / $25 |
| Claude Opus 4.7 | 87.6% | 64.3% | 66.1% (TB2.1) | $5 / $25 |
| Claude Opus 4.6 | ~80.8% (unverified) | 53.4% | — | $5 / $25 |
| Claude Sonnet 4.6 | 79.6% | — (unverified) | — | $3 / $15 |
| GPT-5.5 | 88.7% | 58.6% | **82.7%** (TB2.0, SOTA) | $5 / $30 * |
| GPT-5.4 | — (unverified) | 57.7% | competitive | ~$1.25 / $10 (unverified) |
| GPT-5.4-mini | — (unverified) | 54.4% | competitive | $0.75 / $4.50 (some claims say $0.40/$1.60; unverified) |

* Codex runs through the ChatGPT subscription, so in this environment Codex-side
tokens do not consume Claude-side quota. That is the main reason delegation matters.

Supplemental data:
- Fable 5 scores 29.3% on FrontierCode Diamond (Opus 4.8 scores 13.4%). The gap is
  largest on the hardest tasks.
- Fable 5 falls back to Opus 4.8 for cybersecurity, biology, chemistry, and
  distillation-related requests.
- GPT-5.5 scores 73.1% on Expert-SWE, a long-horizon benchmark with median
  20-hour tasks (GPT-5.4 scores 68.5%). It is strong at long autonomous runs.
- GPT-5.5 has GPT-5.4-class latency with lower token consumption, per published
  claims.
- GPT-5.4-mini provides about 94% of GPT-5.4's coding performance (SWE-bench Pro
  54.4% vs. 57.7%) at much lower cost. It is also strong on computer-use tasks,
  including OSWorld-Verified 72.1%.
- Opus 4.7/4.6 have reported answer-leak concerns on SWE-bench Pro (DeepSWE,
  more than 12%). Do not over-trust Pro scores without verification.

## How To Read This For Delegation

- **SWE-bench Verified** = standard bug-fix and implementation ability on known
  repositories. GPT-5.5 (88.7%) is effectively tied with Opus 4.8 (88.6%).
  Everyday implementation is fine for Codex.
- **SWE-bench Pro** = harder implementation with contamination controls. Claude is
  clearly ahead (Fable 5: 80.3% vs. GPT-5.5: 58.6%). This is the reason to keep
  genuinely hard implementation with Claude-side models when the task cannot be
  neutralized by a strong spec.
- **Terminal-Bench** = CLI operation, environment setup, and tool integration.
  GPT-5.5 is SOTA (82.7%). Build repair and environment investigation are good
  Codex tasks.
- Design and review judgment quality probably correlates with SWE-bench Pro /
  FrontierCode. The value of sending review to Codex is less raw score and more an
  independent second-provider view that reduces anchoring bias.

## Selecting Codex Settings

Use `/codex:rescue` or the companion script with `--model <name>` and
`--effort <none|minimal|low|medium|high|xhigh>`.

Mapping to user-facing UI labels: low=low / medium=medium / high=high /
very high=xhigh. Default in `~/.codex/config.toml`: `gpt-5.5` / `medium`.

Known constraint: `--effort minimal` cannot be used with web_search or image_gen
tools and causes HTTP 400 errors. In practice, `low` is the floor.

## Selecting Claude Subagents

Agent tool `model` parameter: `fable` / `opus` / `sonnet` / `haiku`; omitted means
the subagent inherits the main session. There is no mechanism to set per-subagent
thinking effort (low/medium/high/extra-high/MAX/UltraCode). Thinking effort
inherits the session setting; only model selection is controlled.

## Measured Calibration (2026-06-11/12, seven runs, unverified)

Primary data from one TS+Rust/web repository, n=7. Generalization to other stacks
and domains is unverified. Two execution paths matter because their implications
differ:

- **Five plugin-delegated runs** (gpt-5.5 / medium, with detailed specs: paths,
  line numbers, verbatim current code, and regression cases): each single-change
  task completed in 2.5-5 minutes, all first-try PASS. Tasks included a subtle
  React effect-identity infinite loop fix and a secret-boundary bug.
- **Two manual app runs** (GPT-5.4 / medium, goal-level only, no code quotes, but
  human-supervised manual Codex): a security audit followed by cross-cutting
  TS+Rust fixes, draft PR, and green CI completed in 17 minutes; a full UI redesign
  with WCAG AA verification and worktree/rebase completed in 23.5 minutes. The
  important point is that the hardest tasks passed with minimal spec detail.
- **Implications**: (1) Inference: hard but specifiable work is Codex territory; main
  should retain only tasks where acceptance criteria cannot be written. (2) Effort
  medium is the workhorse; moving 5.4 to 5.5 improves quality and token efficiency at
  the same setting. (3) The delegated path defaults to detailed specs because that is
  the empirically proven mode. "Goals-only is enough" is proven only in the manual
  path and remains a hypothesis, so do not thin delegated specs for that reason. (4)
  Autonomy limits such as >30 minutes or 15-25 minutes are estimates, not measured
  limits; the observed maximum is about 24 minutes, so boundaries remain unconfirmed.

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
