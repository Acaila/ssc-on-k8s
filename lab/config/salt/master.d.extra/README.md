# Extra Salt Master Fragments

This directory is the intended place for operator-managed Salt master config
fragments in the local Compose lab.

Files placed here with a `.conf` or `.yaml` extension are copied into
`/etc/salt/master.d/` by the salt-master entrypoint on each start.

Use this for deployment-specific settings such as:

- `winrepo_ng`
- `gitfs`
- `git_pillar`
- additional `fileserver_backend` values
- deployment-local auth or tuning that should not be baked into the image

Prefer additive drop-ins such as:

- `20-winrepo-ng.conf`
- `30-gitfs.conf`
- `40-git-pillar.conf`
- `90-local-overrides.conf`

The entrypoint still generates the Broadcom/SSE integration fragments itself.
Keep those generated files out of this directory unless you intentionally want
to replace part of that behavior.
