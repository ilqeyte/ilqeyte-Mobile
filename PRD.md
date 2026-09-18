# ilqeyte-Mobile — Product Requirements Document

| Field | Value |
| :-- | :-- |
| **Product** | ilqeyte-Mobile |
| **Version** | 0.1.0 — Draft (baseline approved for Milestone 1) |
| **Date** | 2026-09-18 |
| **Owner** | ilqeyte |
| **Repository** | https://github.com/ilqeyte/ilqeyte-Mobile |
| **License** | MIT |
| **Companion docs** | `PLAN.md` (engineering), `README.md` |

> **Status:** Pre-alpha. Milestone 1 (foundation) is the active scope. Requirements marked **M1** are in flight.

---

## 1. Vision

**ilqeyte-Mobile** is a native, self-contained **agentic coding assistant for Android** — a complete *harness* that fits in your pocket, in the lineage of **Claude Code**, **OpenAI Codex CLI**, and **DeepSeek Harness (dsh)**.

Everything that makes it a *harness* — the agentic loop, the tool/plugin system, long-horizon orchestration, multi-agent collaboration ("Coworker"), and automation — **runs natively on-device in Flutter/Dart**. There is **no embedded Node.js, no local server, and no WebView wrapping a desktop product**. The app reaches out for exactly one thing: **inference**, supplied by cloud models the user connects directly — any **OpenAI-compatible** endpoint (DeepSeek, OpenAI, OpenRouter, Groq, Together, vLLM, llama.cpp, LM Studio, Ollama…) and any **Anthropic-compatible** (Messages) endpoint.

The experience is a **chat assistant that acts**: it plans, requests approval, calls tools, reads and edits real files, commits to Git, runs Python on-device, coordinates sub-agents, and resumes long tasks where it left off — behind a **"Liquid Glass"** interface that fuses Kimi's calm clarity, ChatGPT's familiar chat flow, Claude's artifact-focused calm, and Apple's translucent, depth-first aesthetic.

**One-line pitch:** *Claude Code / DeepSeek Harness in your pocket — native, plugin-based, cloud-brained, glass-designed.*

## 2. Problem & Opportunity

1. **Harnesses are desktop-first.** Claude Code, Codex, and dsh assume a full filesystem, a shell, and build toolchains — none of which exist on a stock phone.
2. **Mobile AI apps are chatbots, not agents.** They answer questions but cannot plan, use tools, edit files, version-control, or run multi-step work unattended.
3. **Attention is on phones.** Kicking off a long-horizon coding or automation task from a phone — one that survives backgrounding, battery constraints, and flaky networks — is currently unserved.
4. **Plugin architecture wins on mobile.** dsh's *"everything is a plugin"* is the right model: capability grows without forking the core, which matters when the platform restricts what an app may do.

## 3. Goals & Non-Goals

### 3.1 Goals
- **G1** Ship a native Flutter Android app (single APK) implementing a *full* agentic harness — not a chat shell.
- **G2** Cloud-brained and **provider-agnostic**: connect any OpenAI-compatible **or** Anthropic-compatible endpoint with base URL + key. **No backend required.**
- **G3** *"Everything is a plugin"* tool framework with a typed SDK and permission gating.
- **G4** **Long-horizon, resumable** tasks: checkpoints, context compaction, plan/act approvals, human-in-the-loop.
- **G5** **Coworker**: a lead agent decomposes work and coordinates parallel sub-agents over a shared blackboard.
- **G6** **Automation**: event/schedule triggers run agents reliably in the background (foreground service).
- **G7** **Liquid Glass** design system executed in Flutter (blur, translucency, dynamic color, spring physics, haptics).
- **G8** **Builds happen in GitHub Actions** — producing an installable APK requires no local toolchain.

### 3.2 Non-Goals (this version)
- On-device LLM inference (future plugin; architecture must permit it).
- iOS release (codebase cross-platform-ready; Android APK is the target).
- Hosted backend / user accounts / billing (BYO-key only).
- Executing native build toolchains (gradle/npm/cargo) on-device — heavy execution routes through an optional remote-execution tool.
- Play Store distribution initially — distribution is a signed APK artifact from CI.

## 4. Personas

- **P1 — The tinkerer / indie dev.** Wants Claude Code-class capability while away from a laptop; values real file edits, git, and resumable tasks.
- **P2 — The automator.** Wants scheduled/triggered agent work (summarize shared links, triage, periodic reports) that runs reliably in the background.
- **P3 — The learner.** Wants to *watch* an agent reason and act step-by-step, with approvals before anything risky.

## 5. Key Differentiators

1. **Harness, not chatbot** — real loop, tools, approvals, durable state.
2. **Everything is a plugin** — capabilities are composable and installable (dsh philosophy).
3. **Coworker** — multi-agent collaboration on a shared blackboard with a visible task board.
4. **On-device Git (JGit) + Python (Chaquopy)** — real coding operations without a shell.
5. **Cloud-model agnostic** — OpenAI-compatible **and** Anthropic-compatible, switchable per conversation.
6. **Offline-resumable agent state** — long tasks survive app kill and network disruption.
7. **Liquid Glass** — a premium, distinct visual identity, not another Material clone.

## 6. Functional Requirements

Requirement IDs are stable and referenced by the plan (`PLAN.md`) and tests. **M1** = required for Milestone 1.

### F1 — Model Providers *(M1)*
- **F1.1** Create/edit/delete provider connections: name, base URL, API key, protocol (`openai-compatible` | `anthropic-compatible`), default model.
- **F1.2** Model discovery via `/models` where supported; manual entry otherwise.
- **F1.3** Streaming responses (SSE) with cancel and partial-error recovery.
- **F1.4** Tool/function calling in **both** wire formats, normalized to an internal `ToolCall`.
- **F1.5** Reasoning display: surface OpenAI-style `reasoning_content` (DeepSeek-R1) and Anthropic `thinking` blocks.
- **F1.6** Usage accounting (tokens) per request and cumulatively per provider.
- **F1.7** Resilience: timeouts, exponential-backoff retries, rate-limit handling, user-visible errors.
- **F1.8 — Acceptance:** a user connects DeepSeek **and** Anthropic, completes a tool-using task on each, and can switch provider per conversation.

### F2 — Agent Engine *(M1 core)*
- **F2.1** Core loop: plan → tool-call → observe → reflect → repeat, until a terminal condition or the step budget is exhausted.
- **F2.2** **Plan / Act modes** with explicit user approval gates before any side-effecting tool runs.
- **F2.3** Checkpointing: full run state persisted on every step; resume seamlessly after kill/backgrounding.
- **F2.4** Context management: compaction, sliding window, selective retention of large tool outputs.
- **F2.5** Error recovery: tool failures are fed back into the loop; configurable retry/fallback.
- **F2.6** Concurrency: multiple runs; background automation runs isolated from interactive runs.
- **F2.7 — Acceptance:** a 25+ step task survives an app kill and resumes exactly where it stopped, with zero lost work.

### F3 — Tool & Plugin Framework *(M1 minimal, M5 full)*
- **F3.1** `Tool` contract: id, name, description, JSON-Schema params, declared side-effects, permissions.
- **F3.2** Registry with per-workspace enable/disable; permission prompt on first use of any side-effecting tool.
- **F3.3** Plugin packaging convention + local registry (remote index is a future concern).
- **F3.4** Sandboxed execution context: scoped filesystem root, network policy, clock, logger.
- **F3.5 — Acceptance:** a new tool is added by implementing one interface + schema with **zero** changes to the core engine.

### F4 — Agentic Coding Tools *(M2)*
- **F4.1** File: read (with line ranges), write, edit (string replace), unified-diff/patch apply.
- **F4.2** Search: regex content search and glob file listing.
- **F4.3** **Git via native bridge (JGit)**: init, status, add, commit, log, branch, diff.
- **F4.4** **Python execution via Chaquopy bridge** — on-device interpreter, output streamed back.
- **F4.5** Web fetch (permission-gated, opt-in).
- **F4.6 — Acceptance:** the agent reads, edits, and commits a change to a real repository inside its workspace, end-to-end.

### F5 — Chat & Assistant UX *(M1)*
- **F5.1** Streaming markdown chat with syntax highlighting.
- **F5.2** Collapsible tool-call cards showing input, output, diffs, and inline approvals.
- **F5.3** Reasoning / chain-of-thought view (toggle).
- **F5.4** **Artifacts / Canvas**: interactive previews for code, markdown, images, and data.
- **F5.5** Attachments (images, files) injected into context.
- **F5.6** Conversation history with search, rename, delete, and **fork**.
- **F5.7 — Acceptance:** a non-expert completes a full agentic task using only the chat UI.

### F6 — Coworker / Multi-Agent *(M3)*
- **F6.1** A lead agent decomposes a task into subtasks and assigns them to specialist agents.
- **F6.2** Shared **blackboard** (shared state + message bus) for coordination.
- **F6.3** Parallel execution with live progress on a **task board**.
- **F6.4** Cross-review: a reviewer agent audits sub-agent output before the merge gate.
- **F6.5 — Acceptance:** a task requiring three distinct roles completes with a merged, reviewed result.

### F7 — Automation *(M4)*
- **F7.1** Triggers: share-intent, schedule (cron/interval), notification and file watchers.
- **F7.2** Reliable background execution via **foreground service + WorkManager**.
- **F7.3** Automation dashboard: list, enable/disable, run history, logs.
- **F7.4 — Acceptance:** a scheduled automation fires while the app is backgrounded and records its result.

### F8 — Workspace & Persistence *(M1 fs, M2 SAF)*
- **F8.1** App-scoped workspace + user-granted folders (SAF) mounted as roots.
- **F8.2** Persistence: Drift (relational: runs, tasks, automations) + Isar (messages/documents) + keystore for secrets.
- **F8.3** Export/import of workspace and conversations.
- **F8.4 — Acceptance:** an export/import round-trip restores all data on a new install.

### F9 — Design System: Liquid Glass *(M1 base, M5 full)*
- **F9.1** Frosted translucent surfaces via `BackdropFilter` + `ImageFilter.blur`.
- **F9.2** Dynamic color (Material You) plus a hand-tuned palette; dark and light themes.
- **F9.3** Spring-physics transitions, specular borders, depth layering.
- **F9.4** Haptics on key interactions; full reduced-motion support.
- **F9.5 — Acceptance:** cohesive and distinctive, holding ≥60 fps on mid-range devices.

### F10 — Settings, Secrets, Onboarding *(M1)*
- **F10.1** Onboarding: first provider connected in under 60 seconds.
- **F10.2** Secrets in `flutter_secure_storage` (Android Keystore); never logged, never committed.
- **F10.3** Feature flags, diagnostics/log viewer, and a "reset workspace" danger zone.

## 7. Non-Functional Requirements

- **NFR1 Performance** — cold start < 2 s; first streaming token < 800 ms on a fast network; 60 fps UI.
- **NFR2 Battery / thermal** — inference is remote; minimize CPU work, batch DB writes.
- **NFR3 Reliability** — zero silent data loss on kill; checkpoint durability is a first-class concern.
- **NFR4 Security** — keys in the keystore; scoped storage; no telemetry without opt-in.
- **NFR5 Accessibility** — labels, contrast, dynamic type throughout.
- **NFR6 i18n** — English, Arabic, and Chinese string catalogs from day one.
- **NFR7 Testability** — engine and provider adapters fully unit-testable with recorded fixtures.
- **NFR8 CI** — every push is analyzed + tested; every merge to main produces a signed APK artifact.

## 8. Constraints & Platform Realities

1. **Android sandbox** — free rein in app storage and granted folders; all-files access needs `MANAGE_EXTERNAL_STORAGE`; system-wide access needs root (not assumed).
2. **No native toolchains on stock Android** — no `gradle`/`npm`/`git` binaries. Git via the JGit bridge, Python via Chaquopy, everything else via an optional remote-execution tool.
3. **Background limits** — reliable background work requires a foreground service; doze will defer plain alarms.
4. **Network is required** for inference — the app is cloud-brained by design.
5. **Platform levels** — `minSdk 24`, `targetSdk` current. Blur effects degrade gracefully on older devices (Flutter's `BackdropFilter` works broadly).

## 9. Success Metrics

- Percentage of user-initiated tasks that reach a terminal state without a manual rescue.
- Tool-call success rate; approvals-to-completion ratio.
- Session-resume success rate after a kill.
- CI health: main-branch green rate; an APK artifact produced on 100% of merges.
- Cold-start time, APK size, and crash/ANR-free session percentage.

## 10. Milestones / Release Plan

- **M1 — Foundation:** Flutter skeleton; provider layer (both protocols) with streaming + tool calls; agent loop with plan/act + approvals; basic Liquid Glass chat UI; secure provider settings; **CI builds an APK**. *(The "it talks and uses tools" milestone.)*
- **M2 — Coding tools:** file/edit/patch/search, Git bridge, Python bridge, workspace + SAF roots.
- **M3 — Coworker:** blackboard, sub-agents, task board, review/merge gate.
- **M4 — Automation:** triggers, foreground service, dashboard, run history.
- **M5 — Polish & Plugin SDK:** full Liquid Glass pass, plugin packaging + local registry, performance, hardening, beta APK.

## 11. Risks & Mitigations

| Risk | Mitigation |
| :-- | :-- |
| Provider format drift | Contract tests against recorded fixtures, re-run each release |
| Sandbox confusion | Explicit workspace model; tools return legible permission errors |
| Android kills background runs | Foreground service + durable checkpoints |
| Context exhaustion | Compaction strategy designed in M1, not bolted on later |
| Plugin safety | Permission gating + sandbox; explicit review before enabling |
| Secret leakage | Keystore storage; redaction filter in logs; no secrets in repo or CI |
| Flutter package churn | Pinned versions; vendor critical deps if necessary |

## 12. Open Questions

1. Distribution: sideload-only vs Google Play (Play policy on AI + filesystem permissions is stricter)?
2. Should a hosted "one-tap login" backend be offered later (would change the M1 auth surface)?
3. Timeline for an on-device model plugin (llama.cpp / MLC via FFI)?
4. Monetization (if any): pro automations? a plugin marketplace?
5. iOS shipping window.

## 13. Glossary

**Harness** · **Agent loop** · **Tool / Plugin** · **Blackboard** · **Plan/Act** · **BYO-key** · **OpenAI-compatible** · **Anthropic-compatible** · **SAF** · **Foreground service** · **Liquid Glass** · **Checkpoint** · **Compaction** · **Coworker**

---
*This document is the single source of truth for **what** ilqeyte-Mobile is. See `PLAN.md` for **how** it gets built.*



