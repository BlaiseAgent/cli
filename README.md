# Blaise CLI

<p align="center">
  <img src="assets/blaise.svg" alt="Blaise" width="132" />
</p>

<p align="center">
  <strong>Assign it to Blaise. It runs on your machine.</strong>
</p>

<p align="center">
  <a href="https://github.com/BlaiseAgent/cli/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/BlaiseAgent/cli?label=release&color=542A18&labelColor=FFC27A" /></a>
  <a href="https://www.npmjs.com/package/@blaiseagent/cli"><img alt="npm" src="https://img.shields.io/npm/v/@blaiseagent/cli?label=npm&color=542A18&labelColor=FFC27A" /></a>
  <a href="https://askblaise.com/docs/cli"><img alt="Documentation" src="https://img.shields.io/badge/docs-askblaise.com-542A18?labelColor=FFC27A" /></a>
</p>

[Blaise](https://askblaise.com) is an AI teammate that runs
[Claude Code](https://www.anthropic.com/claude-code) agents on demand, started from your tools
(Linear is the first) or from the dashboard. Blaise coordinates the work. The agents run on
infrastructure you control.

The `blaise` CLI is the piece that lives on that infrastructure. It connects your laptop, server,
container or CI runner to your Blaise workspace, so sessions can be dispatched to it.

- **Outbound only.** The CLI opens HTTPS connections to Blaise and nothing else: no public address,
  open port, TLS certificate or tunnel.
- **One executable.** It carries its own runtime. Installing it needs no Bun or Node.js.
- **Yours to shape.** A `blaise.yml` and a handful of plugs decide how each session's environment is
  prepared: a git worktree, a Docker image, a sandbox, tools installed with mise, or your own plug.
- **Hard to lose.** If the connection drops, the CLI reconnects and picks up anything still waiting.

## Install

Pick the channel that fits the machine. All of them install the same release.

| Channel        | Command                                                                           |
| -------------- | --------------------------------------------------------------------------------- |
| Install script | `curl -fsSL https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.sh \| sh` |
| Windows        | `irm https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.ps1 \| iex`      |
| Homebrew       | `brew install BlaiseAgent/cli/blaise`                                                       |
| mise           | `mise use -g github:BlaiseAgent/cli`                                                 |
| npm            | `npx @blaiseagent/cli` or `bunx @blaiseagent/cli`                                 |

Check the result with `blaise --version`.

The install scripts check the download against the release's `checksums.txt` before installing it.
On macOS and Linux the binary goes into `~/.local/bin`, on Windows into
`%LOCALAPPDATA%\Programs\blaise\bin`; set `BLAISE_INSTALL_DIR` to choose another directory.

Binaries are built for macOS (Apple silicon and Intel), Linux (arm64 and x64, glibc and musl: the
`-musl` archives are for Alpine, which also needs `apk add libstdc++ libgcc`) and Windows (x64).
Claude Code must be installed and authenticated separately: `claude --version` should work.

### Pin a version

Releases are versioned by date, `YYYY.M.N`: `2026.10.2` is the second release of October 2026.

```sh
curl -fsSL https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.sh | sh -s -- 2026.10.2
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlaiseAgent/cli/main/install.ps1))) -Version 2026.10.2
```

```sh
mise use -g github:BlaiseAgent/cli@2026.10.2
npx @blaiseagent/cli@2026.10.2
```

### Update

| Installed with | Update with                              |
| -------------- | ---------------------------------------- |
| Install script | run the install command again            |
| Homebrew       | `brew upgrade blaise`                    |
| mise           | `mise upgrade blaise`                    |
| npm            | `npm install -g @blaiseagent/cli@latest` |

Blaise also tells you when an update is due: `blaise listen`, `status` and `login` print the command
for your channel.

## Quick start

You need a Blaise workspace and admin rights to register runners. Then:

1. In the dashboard, create a **Local** agent under **Settings → Agents**.
2. On the machine that should run sessions, sign in once. The browser opens, you approve, and the
   machine is registered as a runner:

   ```sh
   blaise login
   ```

3. In the directory the agent should work in, create the smallest possible `blaise.yml`:

   ```yaml
   version: 1
   ```

4. Start listening:

   ```sh
   blaise listen
   ```

That's it. Blaise will start dispatching sessions to the machine. To prepare a checkout, install
tools, or run the agent somewhere else, add plugs, starting with a git worktree:

```yaml
version: 1
setup:
  - use: blaise:git/worktree
```

`blaise login` works over SSH and on headless machines. For CI and containers, give the CLI a runner
token through `BLAISE_RUNNER_TOKEN` instead of signing in.

## Where to go next

| I want to                             | Read                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Get a runner working                  | [Getting started](https://askblaise.com/docs/cli)                                                      |
| See every install and update channel  | [Install and update](https://askblaise.com/docs/cli/install)                                           |
| Run the agent in a container          | [Docker](https://askblaise.com/docs/cli/docker)                                                        |
| Prepare each session's environment    | [Runner and plugs](https://askblaise.com/docs/runner)                                                  |
| Follow a tutorial                     | [Connect your first runner](https://askblaise.com/docs/runner/tutorials)                               |
| Understand how sessions find a runner | [How sessions find a runner](https://askblaise.com/docs/runner/explanation/how-sessions-find-a-runner) |
| Know what runs where                  | [Security model](https://askblaise.com/docs/runner/explanation/security-model)                         |

## Verify a download

Every release carries an archive per platform and a `checksums.txt`. To check one by hand, compare
the archive's SHA-256 (`shasum -a 256 <archive>` on macOS, `sha256sum <archive>` on Linux) with its
line in `checksums.txt`.

---

This repository only hosts releases: it is published by the release workflow of the Blaise project,
and nothing is built here. The CLI is documented at
[askblaise.com/docs](https://askblaise.com/docs).
