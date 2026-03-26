# Salt Master CLI Usage For Traditional Salt Admins

This note is aimed at an administrator who is used to logging in to a Salt
master host and running commands such as `salt`, `salt-run`, and
`salt-call --local` from an interactive session such as SSH or console.

In this repo, the Salt master is still a normal Salt master process, but it
runs inside a container. The operational model is slightly different:

- you do not ssh to a long-lived appliance VM
- you exec into the running `salt-master` container when you need an
  interactive shell
- for one-off tasks, you usually run the Salt command through `kubectl exec`
  or `docker exec` instead of opening a shell first

## The Main Shift

The Salt CLI commands still exist inside the container:

- `salt`
- `salt-run`
- `salt-call`
- `salt-master`

What changes is how you reach them.

Inside the container, you are already in the Salt runtime environment. On the
current image, the main binaries are available on `PATH` under `/usr/bin/`.

## Obtain A TTY Session

For Kubernetes-backed deployments, open an interactive shell on the running
master with:

```bash
kubectl -n aria-config exec -it deploy/salt-master -- sh
```

For the local Docker Compose lab:

```bash
docker exec -it ssc-salt-master sh
```

The trailing `sh` is what starts the shell. Once you are in that shell, you
can use the Salt CLI much like you would on a traditional master host:

```bash
salt '*' test.ping
salt-run jobs.list_jobs
salt-call --local state.show_top
```

## Run One-Off Commands

If you do not need an interactive session, replace the trailing `sh` with the
Salt command you want to run and let it return directly to your workstation.

Kubernetes examples:

```bash
kubectl -n aria-config exec deploy/salt-master -- salt '*' test.ping
kubectl -n aria-config exec deploy/salt-master -- salt-run jobs.list_jobs
kubectl -n aria-config exec deploy/salt-master -- salt-call --local state.show_top
```

Docker lab examples:

```bash
docker exec ssc-salt-master salt '*' test.ping
docker exec ssc-salt-master salt-run jobs.list_jobs
docker exec ssc-salt-master salt-call --local state.show_top
```

If you expect to run several Kubernetes commands in a row from the workstation,
a simple shell alias can save some typing:

```bash
alias ksalt='kubectl -n aria-config exec deploy/salt-master --'
```

Example usage:

```bash
ksalt salt '*' test.ping
ksalt salt-run jobs.list_jobs
ksalt salt-call --local state.show_top
```

Because the master container runs with a read-only root filesystem and is not
being used as a normal managed minion, some `salt-call --local` commands may
warn about caching `/etc/salt/minion_id`. In the current lab image, the
command still runs, but that warning is expected.

## What Persists And What Does Not

Treat the running container filesystem as disposable unless the path is backed
by a persistent volume or a host bind mount.

In the current Kubernetes deployment:

- the master PKI and master-local generated state persist across pod
  replacement
- minion key state persists across pod replacement
- day-2 Salt master config should be supplied through the supported config
  inputs, not edited directly in the live container

That means the safe mental model is:

- use the container for command execution
- use manifests, ConfigMaps, or mounted config directories for configuration
- use persistent volumes for state that must survive a restart

## Where To Make Config Changes

Do not treat `kubectl exec` as a permanent configuration workflow.

For example, editing files directly under `/etc/salt/master.d/` in a running
pod may appear to work for the moment, but those changes are not the source of
truth for the deployment.

Use the supported operator-managed config input instead:

- Kubernetes: mount Salt master drop-ins through the optional
  `salt-master-extra-config` ConfigMap at `/etc/salt/extra-master.d`
- Docker Compose: place extra Salt master fragments in
  `lab/config/salt/master.d.extra/`

On startup, the entrypoint copies those operator-managed drop-ins into
`/etc/salt/master.d/` alongside the generated SSE fragments.

This is the intended day-2 path for changes such as:

- `fileserver_backend`
- `gitfs`
- `git_pillar`
- `winrepo_ng`
- other normal Salt master tuning that a Salt administrator would own

## Logs And Troubleshooting

For Kubernetes, start with the pod logs:

```bash
kubectl -n aria-config logs deployment/salt-master --tail=200
```

If you need an interactive troubleshooting session:

```bash
kubectl -n aria-config exec -it deploy/salt-master -- sh
```

For the local Docker lab:

```bash
docker logs --tail=200 ssc-salt-master
docker exec -it ssc-salt-master sh
```

## Practical Rule

If you would normally say "I need to log in to the Salt master and run a
command", translate that to one of these two patterns:

- Kubernetes: `kubectl exec` into `deploy/salt-master`
- Docker lab: `docker exec` into `ssc-salt-master`

If you would normally say "I need to change the Salt master configuration",
translate that to:

- update the mounted operator config
- restart or roll out the Salt master so the container starts from the desired
  configuration state
