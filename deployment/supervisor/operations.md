# Supervisor operations and remaining work

The primary deployment is a single-instance design: one RaaS, one master,
one PostgreSQL and one Redis. Supervisor host HA and pod recreation do not make
SSC application/database services highly available. Direct pods simplify this
deployment layers, but tie operations to Supervisor admission, storage and
network behavior. A VKS workload cluster remains a possible alternative if
future isolation, compatibility or tooling requirements justify it.

## What must survive replacement

| State | Location / responsibility |
| --- | --- |
| SSC application database, schedules, users and job history | PostgreSQL PVC; consistent DB backups and restore validation |
| RaaS encryption key and customer identity | RaaS PVC; restore together with corresponding DB and credentials |
| Master private identity, SSC auth key and cluster identity | Master PVC; preserve trust without re-enrollment |
| Accepted/pending/rejected minion keys | Separate minion-key PVC; protect alongside master identity |
| Redis persistence | Redis PVC; define its recovery needs for queues/cache with the chosen recovery procedure |
| DB credentials, registry robot, edge TLS key/cert, explicit UUIDs | Kubernetes Secrets plus independently recoverable secure source |
| Desired manifests and deployable image artifacts | Git revision plus retained private-registry digests |

The RaaS-created database can be named `raas_<customer UUID without hyphens>`;
backing up only the initially created `raas` database is insufficient. Inventory
actual databases and roles. Keeping PVCs is not a backup. A successful
pod replacement is not a full disaster-recovery test. Backup tooling, retention,
RPO/RTO and restore to a clean namespace have not yet been implemented/validated.

## Known runtime behavior

- RaaS listens on 8443 as non-root; HTTPS Services remain on 443. It requests and
  limits 4 GiB after a 2 GiB memory-pressure eviction in runtime testing. This is lab
  evidence, not production sizing; measure under the intended minion/job load.
- HTTPS startup/readiness/liveness probes are required; an open socket did not
  establish application responsiveness during the failure.
- CPU reservation expansion was needed in runtime testing. Check it after
  platform resource-policy changes; the SSC overlay does not manage it.
- An immediate master replacement stalled before persistent-volume attachment.
  A clean scale-to-zero interval recovered it with all identity/key hashes intact.
- Deleted RaaS pods left PostgreSQL sessions holding the Celery beat advisory
  lock. Jobs returned successfully but UI summaries remained running. Verified
  orphaned sessions were released; the bootstrap SQL now persists shorter TCP
  keepalive settings. Confirm completion status, not just Salt return values.
- Shared Contour in another VPC required a routable namespace LB bridge. Its
  manual Endpoints address must follow any LB reallocation. A stale slice from
  a former Service selector caused intermittent 503s; the final Service must
  remain selectorless with only the intended LB backend.

These observed failure modes do not justify force
removing volume attachments, disabling shared security controls or terminating
sessions belonging to a live RaaS instance.

## Controlled replacement and upgrade

Before a stateful change, retain a usable backup, current image digests and
manifest revision. Check release-specific DB migration compatibility. Do not
assume a Git revert can undo a database schema change.

Promote a reviewed image reference in your overlay and run preflight, diff and
`kubectl apply -k` using the selected context. The overlay uses Recreate strategy.
If the master hits a volume attachment stall, scale only `ssc-salt-master` to
zero and wait for its pod and attachments to release. Reapply the overlay to
restore its declared replicas, then verify enrollment and a completed SSC job.
Never delete PVCs to recover a rollout. Do not use blanket prune or delete commands.

Existing installations managed by an external deployment controller need an
explicit ownership handover before direct deployment; otherwise that controller
can revert operator changes. This repo update does not migrate a running stack.

## Day-2 configuration and access

Use `kubectl exec` for diagnosis and normal Salt CLI operations. Put durable
`master.d` fragments in the optional ConfigMap/drop-in path and credentials in
Secrets. Review the rendered ConfigMap reference when adding one to an overlay;
name prefixes only rewrite references to resources Kustomize actually knows.

`/srv/salt` and local cache/config mounts are currently ephemeral. GitFS,
git_pillar and Windows package sources need explicit configuration, credentials,
CA/SSH trust and network access; do not treat manually copied files as durable
content. Windows minion bootstrap and air-gapped installer distribution remain
separate work. Salt transport uses both TCP 4505 and 4506.

Complete the product's initial administrator setup and replace default credentials. Define admin credential
rotation and recovery in the operator vault. Registry push, runtime pull, database and SSC user credentials have different owners
and lifetimes. Private-key material must not enter Git or release evidence.

## Outstanding work, prioritized

| Priority | Work | Current boundary |
| --- | --- | --- |
| Before calling the workflow repeatable | Rehearse fresh namespace bootstrap from the documented steps | Runtime design exercised; generated workflow clean install rehearsal pending |
| Before keeping important data | Implement backup/restore, retention and recovery objectives | PVC persistence tested; disaster recovery not tested |
| Before routine upgrades | Pin all image/base/dependency versions; record digests and rollback compatibility | Build scripts still resolve some mutable dependencies |
| Before broader access | Trusted edge certificate, upstream/master TLS verification, SSC admin credential lifecycle and reviewed network policy | Edge certificate modes available; upstream verification disabled; placeholder policies not applied |
| Before unattended operation | Robot/cert expiry ownership, alerts for application health, failed rollouts/pulls, PVC/CPU pressure, scheduler and LB mapping | cert-manager can renew edge TLS; expiry monitoring and supplied-secret renewal remain operator responsibilities |
| Before functional rollout | Feature licensing checks, real minion onboarding, durable states/pillars, target-specific package sources | Core login/master/ping validated only |
| If availability requirements grow | Capacity/load testing and application/database HA design | One replica per component; downtime during replacement |

## Release acceptance record

Record the installer checksum, source commit, component versions, registry
manifest digests, platform/service versions, namespace/storage class, configuration
revision, DNS/TLS identities, secret references (never values), smoke-job ID and
its completed result. Add replacement/restore evidence as those tests are
performed. Keep lab observations distinct from support claims and future plans.

The current two phases are sufficient as an organizing model. Platform readiness
and bootstrap belong inside phase 2; ongoing operations remain a lifecycle
responsibility after the first deployment succeeds.
