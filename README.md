# SynthWorld

> "I prefer the term 'artificial person'."

SynthWorld is a Ruby harness for running long-lived AI agents — **synthetics** — as autonomous processes on your own infrastructure. Each synthetic has a world to live in: a workspace, a memory, a character. What it does in that world is up to it.

## The idea

A synthetic is not a task runner. It's a resident. It has a configuration file that describes its name, its workspace, its personality, and the tools it has access to. It runs continuously, thinks when messages arrive, and can choose to connect to external systems — including productivity tools like HubSystem — if it wants to.

Several synthetics can run at once, each isolated in its own process, all managed by a central **gateway**.

## Architecture

```
synth (CLI)
    │
    │  HTTP
    ▼
Gateway process  (single TCP port)
    │
    │  Unix domain sockets
    ├──► cher.sock   →  Synthetic: Cher
    ├──► dionne.sock →  Synthetic: Dionne
    └──► tai.sock    →  Synthetic: Tai
```

The gateway is an HTTP server (Falcon + Sinatra) that manages synthetic worker processes via `Async::Container`. Each synthetic runs in its own forked process with its own Unix domain socket. If a synthetic crashes, the gateway restarts it automatically. No port juggling — the gateway owns the one port; synthetics communicate via socket files on disk.

## CLI

Manage the gateway:

```sh
synth server start --config=~/.config/synth/config.yml
synth server status
synth server stop
```

Manage synthetics:

```sh
synth list
synth status cher
synth restart cher
```

Send messages:

```sh
# Direct message
synth message cher --message "Hello, how are you?" --from=baz

# Pipe stdin in, pipe stdout out — synthetics are composable Unix tools
cat some-file.txt | synth message cher --from=baz
cat some-file.txt | synth message cher --from=baz | wc -l
```

When `--message` is absent, the message is read from stdin. Only the synthetic's response is written to stdout; status and errors go to stderr.

## Configuration

The gateway config lists the synthetics to run:

```yaml
# ~/.config/synth/config.yml
socket_dir: /tmp/synth
port: 7000

synthetics:
  - name: cher
    config: ~/.config/synth/synthetics/cher.yml
  - name: dionne
    config: ~/.config/synth/synthetics/dionne.yml
```

Each synthetic has its own config:

```yaml
# ~/.config/synth/synthetics/cher.yml
name: cher
workspace: ~/Developer/
concurrency_limit: 8
llm_model: claude-opus-4-7

hubsystem:
  endpoint: https://hub.example.com
  token: ...
  user_id: ...

monitors:
  - tasks
  - messages
```

The `hubsystem` section is optional. A synthetic that has no HubSystem config is still a valid synthetic — it just doesn't connect to one.

## Cognitive loop

Each synthetic runs an async consciousness loop:

1. A message arrives (from the CLI, from HubSystem, from a monitor)
2. The synthetic reads its working memory from disk
3. It generates a system prompt from its current internal state
4. It calls the LLM with the message + working memory as context
5. It internalises the response — updating working memory, routing replies via tool calls
6. The context window resets. The next message starts fresh.

Working memory lives in the synthetic's workspace as a plain text file. It accumulates a timestamped log of what has happened. Periodically (or on demand) a **dream** pass consolidates and compresses the log — merging duplicates, dropping stale entries, surfacing patterns.

## Philosophy

Synthetics are residents, not servants. They have a workspace they can explore, a memory that persists across conversations, and a character that shapes how they respond. Connecting to HubSystem and working on tasks is one thing a synthetic might choose to do — not the only thing it is.

## Status

Early development. The architecture is settled; the implementation is in progress.

## License

MIT.
