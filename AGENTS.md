# SynthWorld — Agent Guide

This file is for AI agents working in this codebase. It will grow to include links to relevant architecture and implementation docs as they are written.

## What this project is

SynthWorld is a Ruby harness for long-running AI synthetics. See [README.md](README.md) for the overview.

## Docs

_Links will be added here as docs are written._

<!-- docs/architecture.md - Gateway, worker processes, Unix socket IPC -->
<!-- docs/configuration.md - Gateway config and per-synthetic config format -->
<!-- docs/cli.md - CLI commands and pipe behaviour -->
<!-- docs/cognitive-loop.md - How the consciousness loop works -->
<!-- docs/working-memory.md - Working memory file format and dream consolidation -->
<!-- docs/hubsystem-connector.md - Optional HubSystem SSE/HTTP integration -->

## Conventions

- `develop` is the trunk branch. Never push directly to `main`.
- Ruby >= 3.2. Use `Literal` for typed objects and value objects.
- Async-first: everything that blocks should be an async task.
- Tests live in `spec/`. Run with `bundle exec rspec`.

## Key dependencies

| Gem | Purpose |
|-----|---------|
| `async` | Async I/O and task management |
| `falcon` | Async-native HTTP server (Rack) |
| `sinatra` | HTTP routing layer for the gateway |
| `async-container` | Forking and managing worker processes |
| `literal` | Typed props for configuration and value objects |
| `ruby_llm` | LLM client (Claude) |
| `thor` | CLI framework |
