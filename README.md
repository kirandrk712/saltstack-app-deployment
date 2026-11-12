# saltstack-app-deployment

A SaltStack state that deploys a versioned application release with **atomic switch-over, config templating, a systemd service and a rollback path**. It's the Salt half of the pipeline in [`azure-pipelines-templates`](../azure-pipelines-templates).

## Layout

```
salt/
  top.sls                      # targets minions with grain role:app
  app/init.sls                 # user, dirs, release, symlink, config, service
  app/rollback.sls             # switch `current` to the previous release and restart
  app/files/                   # Jinja templates for config and unit file
pillar/
  top.sls
  app.sls                      # default app settings (name, version, port)
```

## How a deploy works

1. Create the service user and directories.
2. Extract `app-<version>.tar.gz` into `releases/<version>`.
3. Atomically repoint the `current` symlink.
4. Render config and systemd unit from Jinja templates.
5. Restart the service **only if** config, unit or release changed (`watch`).
6. Prune all but the 5 newest releases.

## Usage

```bash
# Dry run - always do this first
sudo salt -C 'G@role:app' state.apply app test=True pillar='{"app":{"version":"1.4.2"}}'

# Deploy to 25% of minions at a time
sudo salt -b 25% -C 'G@role:app' state.apply app pillar='{"app":{"version":"1.4.2"}}'

# Rollback (fast): flip `current` back to the previous release and restart
sudo salt -C 'G@role:app' state.apply app.rollback

# Rollback (explicit): re-apply a specific older version (its release dir is still on disk)
sudo salt -C 'G@role:app' state.apply app pillar='{"app":{"version":"1.4.1"}}'
```

## Scenario: a bad release at 2 a.m.

1. The pipeline's release gate fails (service returns 500s) and calls `app.rollback` automatically.
2. `app.rollback` points `current` at the previous release directory and restarts the service - no re-download, no rebuild.
3. Because releases are versioned directories and the symlink swap is atomic, the previous version is serving again in seconds.
4. Investigate in daylight: the failed release is still on disk for inspection until it is pruned.

Set the grain on a minion: `salt-call grains.setval role app`.

## Why it's written this way

- **Idempotent** - re-running changes nothing if nothing changed.
- **Versioned releases + symlink** - near-instant rollback, no in-place overwrite.
- **Pillar-driven** - same state for every environment; only data differs.
- **Least privilege** - nologin system user, `NoNewPrivileges`, `0640` config.
