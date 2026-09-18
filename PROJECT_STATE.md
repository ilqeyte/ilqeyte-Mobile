# ilqeyte Mobile — Project State

**Snapshot — 2026-09-18 · commit `56374da` · branch `main`**

| Gate | Status |
| --- | --- |
| `flutter analyze lib/ test/` | ✅ No issues |
| Test suite | ✅ 39 tests passing |
| Line coverage | 65.3% (581 / 890 instrumented lines) |
| CI workflow (`ci.yml`) | ✅ Green — analyze, tests, coverage artifact |
| Build APK workflow (`build-apk.yml`) | ✅ Green — release APK built and uploaded |
| Release signed APK | ⛔ Skipped — signing secrets not yet configured |

CI is green on `main` for the first time. Both pipelines now build and verify the **real** app.

---

## 1. What this is

A native Flutter **agentic coding harness** for Android. The device is a thin client: an agent
loop, a tool belt, a sqlite-backed memory, and a Liquid Glass UI, all driven by a cloud LLM that
the user supplies. Version `0.1.0+1`, Dart `>=3.4.0 <4.0.0`, Android only (`flutter create
--platforms android`).

## 2. Architecture

Strictly layered — `features` may never reach past `core`, and `core` never imports Flutter widgets.

```
lib/
├── main.dart                  # package entry point — delegates to app/main.dart
├── app/                       # composition root
│   ├── main.dart              # bootstrap: vault → database → stores → providers → runApp
│   ├── router.dart            # AppRouter (shell + settings routes)
│   └── theme/liquid_glass.dart
├── core/
│   ├── agents/                # agent_runner.dart (tool loop + approval gate), prompts.dart
│   ├── memory/memory_service.dart   # keyword-scored recall over a sqlite notes table
│   ├── models/                # chat_models.dart, provider_models.dart (freezed-style DTOs)
│   ├── providers/             # adapters, registry, provider_store, sse, builtin_catalog
│   ├── services/services.dart
│   ├── storage/               # database.dart (sqlite3 FFI), vault.dart (secure storage)
│   └── tools/                 # tool registry + file_tools, memory_tools
└── features/
    ├── chat/                  # chat_screen, chat_controller, 7 widgets
    ├── settings/              # provider pages, provider_form_page, provider_logo
    ├── shell/                 # app_shell, sidebar, shell_controller (AppRoutes lives here)
    ├── automations/  plugins/
```

49 source files, 8 test files (+1 shared `fake_http.dart` helper).

## 3. Provider layer

- **83-entry builtin catalog** (`builtin_catalog.dart`) — OpenAI-compatible endpoints with base
  URL, protocol and quirks baked in, grouped by capability kind (chat / image / video). Adding an
  entry to the list is the only step required to make it appear in the settings UI.
- **Key-only onboarding**: picking a catalog entry locks the endpoint shape and leaves just the API
  key. `ensureV1` normalises roots that expect `/v1`; `localServer` entries (Ollama, vLLM…) make the
  key optional and store a placeholder so the agent loop's key check still passes.
- **Live model discovery**: `listModels()` fetches the model list, the user multi-selects chips, and
  the first pick becomes the default — models are never typed by hand.

---

## 4. Quality gates

`.github/workflows/ci.yml` (on push + PR to `main`): installs `libsqlite3-dev` (the sqlite3 FFI
dlopens `libsqlite3.so`, which the base runner only ships as `.so.0`), regenerates the Android
shell, then `analyze lib/ test/` → `test --coverage` → uploads `coverage/`.

`.github/workflows/build-apk.yml` (on push to `main`, `v*` tags, manual): builds a release APK and
uploads it as a 30-day artifact; signing and GitHub Releases are wired but gated on repo
secrets/vars (`ENABLE_SIGNING`, `KEYSTORE_BASE64`, …) and are skipped until those are set.

## 5. Recent history

| Commit | Summary |
| --- | --- |
| `56374da` | Add a real package entry point (`lib/main.dart`) + `test/widget_test.dart` so CI stops analyzing `flutter create`'s regenerated template |
| `cd99134` | Builtin provider catalog: picker UI, `ProviderLogo`, `ProviderStore.modelsFor`, `ensureV1`, Anthropic `listModels` |
| `da50d13` | Clear the CI blockers: sqlite3 FFI, database row contract, SSE UTF-8 decoding, `file_tools` root resolution |
| `88ac9d9` | Seed the builtin provider catalog |
| `12453a7` | Repair broken relative imports and analyzer errors |
| `2d9e143` | Full presentation layer, chat controller wiring, core test suite |

Bugs fixed and covered by tests along the way: `database.dart` spread the payload into the row while
`MemoryService` read `row['data']` (null cast); the SSE decoder used `String.fromCharCodes` on raw
bytes and corrupted split multibyte UTF-8; `file_tools._resolve` rejected the workspace root itself
because `p.isWithin(root, root)` is false.

## 6. Local development

```bash
flutter pub get
flutter analyze lib/ test/
flutter test --coverage
```

Two machine-specific notes:

- **Toolchain**: this developer machine runs a preview Flutter from `~/flutter/bin/flutter`; CI uses
  `stable`. A syntax that the preview accepts but stable rejects (or vice versa) can pass locally
  and fail on CI — when in doubt, replicate the CI commands before pushing.
- **sqlite3 on Linux**: only `libsqlite3.so.0` is installed here, so storage-backed tests need a
  dev symlink on the loader path:
  ```bash
  mkdir -p /tmp/libs && ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/libs/libsqlite3.so
  LD_LIBRARY_PATH=/tmp/libs flutter test --coverage
  ```
  Without it the 11 storage/agent tests fail to load the FFI library; the other 28 still pass.

## 7. Known limitations and next up

- **Signing is not configured** — the uploaded APK is unsigned. Set the repo variables/secrets listed
  in §4 to enable the sign step and tag-driven Releases.
- **`pubspec.lock` is untracked.** It was resolved by the local preview SDK; committing it would pin
  CI to those exact versions (currently identical to `stable`'s resolution), which is desirable for
  reproducibility but couples CI to one SDK's resolution.
- **`docs/` is empty** and `PRD.md` / `PLAN.md` are the only design docs.
- **No integration tests** (`integration_test/`) and no widget tests beyond the smoke test; coverage
  is concentrated in `core/` (providers, memory, tools, sse).
- **Catalog verification is unit-level only** — the key-only onboarding → live model fetch →
  multi-select flow has been verified by hand and by unit tests, but never against a real endpoint
  from a device.

- **Logos without assets**: Google's favicon service at 128px, with a monogram fallback in
  `ProviderLogo` so a dead URL never breaks the UI.
- **Adapters**: OpenAI-compatible (streaming chat completions over SSE) and Anthropic, both behind
  the `ProviderAdapter` interface; `media_service` dispatches image/video generation.
