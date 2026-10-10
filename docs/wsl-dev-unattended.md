# WSL DEV unattended deployment prototype

**Scope: DEV only, on the installing user's own WSL.** No EC2, STAGE, or PROD provisioning in this prototype.

## Prerequisites

- Windows with WSL2 Ubuntu; Git, curl, Python 3, Maven, Java 17 JDK, sudo, and systemd.
- Enable systemd in WSL: add `[boot]` and `systemd=true` to `/etc/wsl.conf`, then run `wsl --shutdown` in Windows and reopen Ubuntu.
- A local `.env.dev` in your source clone, never committed.
- Git authentication that allows cloning the private repository.
- GitHub repository Settings > Actions > Runners > New self-hosted runner: generate a **short-lived registration token**. Do not commit or print it.
- Runner registration requires repository admin permission. The developer must be trusted to run repository Actions code on their PC.

## First-time setup (in your WSL source checkout)

```bash
export GITHUB_RUNNER_TOKEN='PASTE_SHORT_LIVED_TOKEN_HERE'
bash scripts/bootstrap-wsl-dev.sh
unset GITHUB_RUNNER_TOKEN
```

This prepares `~/deploy-checkouts/dev`, installs `main-api-dev.service`, grants narrowly scoped restart permissions, registers `~/actions-runner-dev` with label `deploy-dev`, and enables its systemd service with restart-on-failure. The app service itself starts on deployment, not on installation.

Check the runner in GitHub Settings > Actions > Runners and locally:

```bash
cat ~/actions-runner-dev/.service
sudo systemctl status "$(cat ~/actions-runner-dev/.service")"
```

After a `dev` push, view GitHub Actions. On the same WSL, call `curl http://localhost:7002/api/v1/health`; for commit `d208287` the expected `data.status` is `result_ok_deploy_v2`.

**Do not run `./run.sh` manually.** The runner is a systemd service. WSL must be running; systemd cannot wake a fully stopped WSL or powered-off Windows machine. Configure Windows startup to launch WSL if that is required for your test.

## Important multi-user limitation

The GitHub Actions job with label `deploy-dev` executes on **one eligible online runner**, not on every developer's WSL. Installing this on multiple PCs does **not** implement fan-out deployment to every PC. Each checkout and service remains local to the selected runner, but another developer's `dev` push may trigger deployment on any matching registered machine. For multiple-user broadcast deployments, implement a trusted runner inventory and one job per installation (with unique runner labels), or a separate local pull-based deployment agent, before claiming A-mode fan-out is supported.

The workflow intentionally limits push-triggered deployment to `dev`. Stage/prod and future EC2 scaling are separate follow-up work. The administrator checklist is in `docs/admin-cicd-todo.md`.
