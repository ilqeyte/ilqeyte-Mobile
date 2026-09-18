# ilqeyte-Mobile

[![CI](https://github.com/ilqeyte/ilqeyte-Mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/ilqeyte/ilqeyte-Mobile/actions/workflows/ci.yml)
[![Build APK](https://github.com/ilqeyte/ilqeyte-Mobile/actions/workflows/build-apk.yml/badge.svg)](https://github.com/ilqeyte/ilqeyte-Mobile/actions/workflows/build-apk.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **A native agentic coding harness for Android — Claude Code / DeepSeek Harness in your pocket.**
> Status: **pre-alpha · Milestone 1 in progress.** Everything is subject to change.

**ilqeyte-Mobile** is a Flutter app that turns a cloud LLM into a *harness*: it plans, asks for approval, calls tools, reads and edits real files, commits to Git, runs Python on-device, coordinates sub-agents ("Coworker"), and automates work in the background — all natively, with **no embedded server, no Node.js, and no WebView**.

You bring the brain: any **OpenAI-compatible** endpoint (DeepSeek, OpenAI, OpenRouter, Groq, vLLM, llama.cpp, LM Studio, Ollama…) **or** any **Anthropic-compatible** endpoint. Just a base URL + key.

## ✨ Highlights
- **Harness, not chatbot** — agentic loop, plan/act modes, human-in-the-loop approvals.
- **Everything is a plugin** — typed tool SDK with permission gating (inspired by dsh).
- **Real coding on-device** — Git via JGit, Python via Chaquopy, no shell required.
- **Coworker** — a lead agent decomposes and coordinates parallel sub-agents on a shared blackboard.
- **Automation** — scheduled/triggered background runs backed by a foreground service.
- **Liquid Glass** — frosted blur, translucency, dynamic color, spring physics, haptics.
- **Resumable long-horizon tasks** — checkpoints survive app kills and flaky networks.

## 📦 Get the APK
Builds happen in **GitHub Actions** — no local toolchain needed.
1. Go to **Actions → Build APK** → pick a run → download the artifact. Or
2. Grab a release from **Releases** (published automatically on `v*` tags).

> Enable release signing by setting repo variable `ENABLE_SIGNING=true` plus the keystore secrets listed in [`PLAN.md`](PLAN.md) §8.

## 📚 Documentation
- [`PRD.md`](PRD.md) — product requirements (the *what*).
- [`PLAN.md`](PLAN.md) — engineering plan, architecture, CI/CD (the *how*).

## 🏗️ Build locally (optional)
```bash
flutter pub get
flutter run            # or: flutter build apk --release
```
Requires Flutter (stable) and JDK 17. **CI is the canonical build path** — you never need a local toolchain.

## 🧩 Roadmap
**M1** Foundation · **M2** Coding tools · **M3** Coworker · **M4** Automation · **M5** Polish + Plugin SDK — see `PLAN.md §7`.

## 📄 License
MIT — see [LICENSE](LICENSE). Inspirations: Claude Code, OpenAI Codex CLI, and DeepSeek Harness (dsh).

*Star ⭐ the repo if you'd carry a coding harness in your pocket.*
