# ilqeyte-Mobile — Engineering Plan

| Field | Value |
| :-- | :-- |
| **Document** | Engineering & execution plan for ilqeyte-Mobile |
| **Version** | 0.1.0 |
| **Date** | 2026-09-18 |
| **Owner** | ilqeyte |
| **Implements** | `PRD.md` v0.1.0 |
| **Build policy** | **All builds run in GitHub Actions. No local build is required or expected.** |

This document defines *how* the product in `PRD.md` is built: stack, architecture, data model, work breakdown, CI/CD, testing, security, and conventions.

---

## 1. Technology Stack

| Concern | Choice | Rationale |
| :-- | :-- | :-- |
| UI + core logic | **Flutter / Dart 3** (stable channel) | single codebase → native APK; also iOS-ready later |
| State management | **Riverpod 2** | reactive, injectable, excellent testability |
| HTTP / SSE | **dio** + custom SSE transformer | streaming for both provider protocols |
| Relational DB | **Drift** | runs, tasks, automations, checkpoints |
| Document store | **Isar** | messages, large tool outputs |
| Secrets | **flutter_secure_storage** | Android Keystore-backed |
| Background work | **workmanager** + **flutter_background_service** | reliable automation + foreground service |
| Notifications | **flutter_local_notifications** | automation alerts, approvals |
| Markdown | **flutter_markdown** / **gpt_markdown** + highlighter | chat rendering |
| Git | **platform channel → Kotlin + JGit** | pure-Java Git on Android; pure-Dart git is too immature |
| Python | **platform channel → Chaquopy** | on-device interpreter for real code execution |
| CI / CD | **GitHub Actions** | analyze, test, build, sign, release |
| Signing | keystore as a CI secret (base64) | keeps keys out of machines and repo |
| Distribution | signed APK from CI releases | sideload initially; store later |

## 2. Repository Layout

```
ilqeyte-Mobile/
├─ .github/workflows/     ci.yml · build-apk.yml
├─ android/app/           native modules: GitModule (JGit), PythonModule (Chaquopy)
├─ lib/
│  ├─ main.dart
│  ├─ app/                routing, Liquid Glass theme, i18n
│  ├─ core/
│  │  ├─ agents/          AgentRunner · plan/act · checkpoints · compaction
│  │  ├─ providers/       ProviderAdapter · OpenAICompatibleAdapter · AnthropicAdapter · SSE
│  │  ├─ tools/           Tool contract · Registry · sandbox · permissions
│  │  ├─ coworker/        Blackboard · LeadAgent · sub-agent orchestration
│  │  ├─ automation/      triggers · scheduler · foreground-service bridge
│  │  ├─ storage/         Drift · Isar · secure storage · workspace FS
│  │  └─ util/            retry/backoff · token accounting · logging/redaction
│  ├─ features/
│  │  ├─ chat/            conversation UI · tool cards · artifacts · reasoning view
│  │  ├─ onboarding/
│  │  ├─ settings/        providers · keys · feature flags
│  │  ├─ coworker_ui/     task board
│  │  └─ automation_ui/   dashboard
│  └─ plugins/            built-in tool plugins
├─ test/  integration/     unit · widget · golden
├─ docs/                  architecture diagrams, ADRs
├─ PRD.md  PLAN.md  README.md  LICENSE  CHANGELOG.md  .gitignore
```

## 3. Architecture

Clean-ish layering: **presentation → domain ← data**. The engine is deliberately **provider-agnostic** and **UI-agnostic** — it is exercised by tests without a UI, and by the UI without caring which provider is attached.

### 3.1 The agent loop (`AgentRunner`)

State machine: `IDLE → PLANNING → AWAITING_APPROVAL → ACTING → OBSERVING → (loop) → DONE | FAILED | CANCELLED`.

```
            ┌───────────────────────────────────────────────┐
            │                    UI / Event bus              │
            └───▲───────────────────▲───────────────────────┘
                │ events            │ approvals / cancel
   ┌────────────┴───────────────────┴──────────────┐
   │                 AgentRunner                   │
   │  plan ─► provider ─► parse tool calls ─► gate │──┐
   │   ▲                                    │      │  │ step budget,
   │   └────────── observe ◄─ execute ◄──────┘      │  │ compaction,
   │                          (ToolRegistry +       │  │ checkpoints
   │                           sandbox, per-perm)   │  │
   └───────────────────────────────────────────────┘  │
        │ checkpoints (Drift, every step) ────────────┘
```

- Implemented as an async generator yielding `RunEvent`s to a `Stream`; the UI and the persistence layer are just subscribers.
- **Every state transition is snapshotted to Drift** — a checkpoint is exactly the serialized runner state plus the message log so far. Resume = rehydrate + replay from the last checkpoint.
- **Plan/Act**: side-effecting tools are wrapped in an approval gate. In *plan* mode the model may only propose; in *act* mode approved tools execute. Approvals can be per-run or remembered per workspace+tool.

### 3.2 Provider adapters

A single `ProviderAdapter` interface (`chatStream(request) → Stream<Delta>`), with two implementations:

- `OpenAICompatibleAdapter` — `POST {base}/chat/completions`, SSE `data:` frames, `choices[].delta`, `tool_calls`, `reasoning_content`, `usage`.
- `AnthropicAdapter` — `POST {base}/v1/messages`, SSE events (`content_block_delta`, `message_delta`), `tool_use`/`tool_result`, top-level `system`, `thinking` blocks.

Both normalize to internal `ChatRequest`, `Delta`, `ToolCall`, `ToolResult`, `Usage`. The agent core never sees a wire format.

### 3.3 Tool registry & sandbox

`Tool` is a contract (id, name, description, JSON-Schema, permissions, `run(ExecutionContext)`). The registry resolves tool calls; a **permission gate** prompts the user on first side-effecting use per workspace. `ExecutionContext` scopes filesystem access to workspace roots and enforces network policy.

### 3.4 Coworker blackboard

A shared key/value store + append-only message log. Sub-agents are ordinary `AgentRunner` instances with a scoped tool set and a lead-defined goal; the lead merges and a reviewer gates the merge. The task board is a live projection of blackboard state.

## 4. Data Model (core entities)

| Entity | Key fields |
| :-- | :-- |
| `ProviderConfig` | id · name · baseUrl · protocol · keyRef · defaultModel |
| `Conversation` | id · providerId · model · title · createdAt |
| `Message` | id · conversationId · role · parts[] · toolCalls[] · toolResults[] · reasoning · usage |
| `AgentRun` | id · conversationId · state · checkpoint · stepCount · budget |
| `Task` / `SubTask` | id · runId · title · status · assignee (agent role) |
| `Automation` | id · trigger · enabled · runConfig · lastRun |
| `AutomationRun` | id · automationId · startedAt · result · logs |
| `Plugin` | id · version · permissions · enabled |
| `Workspace` | id · roots[] (app-scoped / SAF URIs) |

## 5. Provider Adapter Specification

| Concern | OpenAI-compatible | Anthropic-compatible |
| :-- | :-- | :-- |
| Endpoint | `POST {base}/chat/completions` | `POST {base}/v1/messages` |
| Stream framing | SSE `data: {…}` until `[DONE]` | SSE typed events |
| Tool calls | `choices[].delta.tool_calls[]` | `content_block_delta` → `tool_use` |
| Tool results | `role: "tool"` messages | `tool_result` content blocks |
| Reasoning | `delta.reasoning_content` (DeepSeek-R1) | `thinking` content blocks |
| System prompt | a `system` message | top-level `system` field |
| Models list | `GET {base}/models` | manual entry |

Engineering rules for both adapters:

1. **One normalization layer** — wire DTOs are mapped to internal types at the boundary; nothing leaks inward.
2. **Cancel is a first-class operation** — disposing the stream subscription aborts the request and discards partial state cleanly.
3. **Retry policy** — idempotent reads retry with exponential backoff + jitter; streamed generations are never auto-retried (would duplicate tokens).
4. **Rate limits** — honor `Retry-After`; surface remaining quota in the UI.
5. **Usage accounting** — prompt/completion/cache tokens recorded per request and aggregated per provider.
6. **Contract tests** — every adapter is tested against recorded fixtures (no live network in CI).

## 6. Tool & Plugin SDK

```dart
abstract class Tool {
  String get id;
  String get name;
  String get description;
  Map<String, Object?> get schema;     // JSON-Schema for params
  Set<ToolPermission> get permissions; // e.g. {writeFs, exec, net}
  Future<ToolResult> run(ExecutionContext ctx, Map<String, Object?> args);
}
```

- **ExecutionContext** exposes a sandboxed FS (rooted at the workspace), a scoped logger, a clock, and a network client — never the raw platform.
- **M1 ships built-ins** (`read`, `write`, `edit`, `list`, `grep`), **M2** adds Git/Python bridges, **M5** opens the plugin packaging format + local registry.
- **Safety**: side-effecting tools require approval; tools declare permissions; a misbehaving plugin can be disabled from settings.

## 7. Work Breakdown & Definition of Done

### M1 — Foundation *(target: ~2–3 weeks)*
1. Repo, CI (`ci.yml`), and `build-apk.yml` producing an APK artifact. ✅ scaffolded in the initial commit
2. Liquid Glass theme base (blur, translucency, dynamic color, dark/light).
3. dio + SSE layer; `OpenAICompatibleAdapter`; `AnthropicAdapter`; contract fixtures.
4. Provider settings UI + `flutter_secure_storage`; onboarding flow (<60 s to first message).
5. `AgentRunner`: loop, plan/act, approvals, step budget, **checkpoint/resume**.
6. Chat UI: streaming markdown, syntax highlight, tool-call cards, reasoning toggle.
7. Tool registry + `read`/`write`/`edit` built-ins.
8. Unit + widget tests; golden tests for theme surfaces.

**M1 DoD:** connect DeepSeek *and* Anthropic; run a multi-step tool task; kill the app and resume; CI green and shipping an APK on every merge.

### M2 — Coding tools *(~2 weeks)*
File read/write/edit/patch, grep/glob; JGit bridge (init/status/add/commit/log/branch/diff); Chaquopy bridge (run Python, stream output); SAF folder roots; workspace export/import.

### M3 — Coworker *(~3 weeks)*
Blackboard; lead decomposition; parallel sub-agents; task board UI; review/merge gate.

### M4 — Automation *(~2 weeks)*
Trigger framework (share-intent, schedule, watchers); foreground service + WorkManager; automation dashboard + run history; notifications.

### M5 — Polish & Plugin SDK *(~2–3 weeks)*
Full Liquid Glass pass (springs, speculars, haptics); plugin packaging + local registry; performance pass (startup, memory); hardening + beta APK.

## 8. GitHub Actions CI/CD

**Policy: all builds happen in CI.** Contributors never need a local Flutter install — the APK is downloaded from the Actions artifact or Releases.

- **`ci.yml`** — on PR and push to `main`: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --coverage`, coverage artifact. **Required** via branch protection before merge.
- **`build-apk.yml`** — on push to `main`, on `v*` tags, and via `workflow_dispatch`: checkout → JDK 17 (Temurin) → Flutter (stable, cached) → `flutter pub get` → optional keystore decode → `flutter build apk --release --split-per-abi` → zipalign + apksigner → upload artifact (30-day retention) → on tags, publish a GitHub Release with the APKs.
- **Signing** is opt-in via a repository variable `ENABLE_SIGNING=true` plus secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Until then, CI ships a debug-signed release APK so the app is always installable.
- **Caching**: pub cache + Gradle cache.
- **Releases**: `git tag v0.1.0 && git push --tags` → draft release with generated notes.
- **Branch protection (recommended)**: require `ci.yml`, require 1 review, require linear history, dismiss stale reviews.

## 9. Testing Strategy

- **Unit** — adapters (fixture-driven), `AgentRunner` with a scripted mock provider that returns deterministic tool calls, tool sandbox behavior.
- **Widget** — chat UI, approval dialogs, settings flows.
- **Integration** — end-to-end loop with a fake provider and a temp workspace: plan → tool → observe → done.
- **Golden** — Liquid Glass surfaces across light/dark for visual regression.
- **Contract** — provider fixture suite (request/response/SSE captures) re-run each release to catch drift.
- **Manual smoke checklist** per milestone in `docs/`.

## 10. Security

- API keys live in `flutter_secure_storage` (Android Keystore); they are **never** written to logs, DB, or crash reports. A redaction filter scrubs `Authorization` headers and key-like strings from all logs.
- **No secrets in the repo or CI** — signing keys are GitHub Actions secrets; `ENABLE_SIGNING` gates their use.
- Filesystem access is scoped: app storage + user-granted SAF roots. All-files access (`MANAGE_EXTERNAL_STORAGE`) is requested only if a future feature needs it, with clear justification.
- Plugins declare permissions and require explicit user approval before side-effecting execution.
- R8/ProGuard rules are maintained for JGit and Chaquopy to prevent minification breakage.
- No telemetry without opt-in; diagnostics are local-first and exportable.

## 11. Conventions

- **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`), scoped where useful (`feat(chat): …`).
- **Branching**: trunk-based — short-lived feature branches off `main`, rebased before merge; squash merges.
- **Versioning**: Semantic Versioning; every milestone bumps the minor; `CHANGELOG.md` maintained.
- **Code style**: `dart format` (enforced in CI) + `flutter_lints`; public API documented with doc comments.
- **Reviews**: PR template + self-review checklist; UI changes require a golden/visual check.
- **Docs**: `PRD.md` and `PLAN.md` are living documents — update them in the same PR that ships the feature.

## 12. Timeline (estimates)

| Milestone | Scope | Est. |
| :-- | :-- | :-- |
| M1 | Foundation + provider layer + agent loop + chat UI + CI APK | 2–3 weeks |
| M2 | Coding tools: files, Git bridge, Python bridge, SAF | 2 weeks |
| M3 | Coworker: blackboard, sub-agents, task board | 3 weeks |
| M4 | Automation: triggers, foreground service, dashboard | 2 weeks |
| M5 | Polish, plugin SDK, performance, beta | 2–3 weeks |

M1 and M2 are sequential; M3/M4 UI work can overlap once their cores land.

## 13. Dependencies & Licensing

- **Our code**: MIT (see `LICENSE`).
- **Key third-party**: Flutter/Dart (BSD), Riverpod (MIT), dio (MIT), Drift (BSD), Isar (Apache-2.0), JGit (EDL/BSD-3), Chaquopy (Apache-2.0), flutter_secure_storage (Apache-2.0), workmanager (MIT).
- A `THIRD_PARTY_NOTICES.md` is generated at M5 from `pub` + Gradle license reports; no copyleft (GPL/AGPL) dependencies are permitted without an explicit exception.

---

## Immediate next steps (this repository)

1. ✅ Create repo + Desktop working folder; seed `PRD.md` / `PLAN.md` / CI workflows.
2. Scaffold the Flutter project (`lib/` layout above) and wire `ci.yml` + `build-apk.yml`.
3. Land the theme system and provider abstraction with fixture tests.
4. First runnable milestone: **connect a provider, send a message, watch it call `read`/`write`** — then enable resume via checkpoints.

---
*This document is the single source of truth for **how** ilqeyte-Mobile is built. See `PRD.md` for **what** it is.*




