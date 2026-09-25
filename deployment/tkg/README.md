# TKG / VKS workload-cluster alternative

The repository's primary target is now
[direct Supervisor pods](../supervisor/README.md). A separate VKS workload
cluster is not part of that deployment.

This directory preserves the earlier workload-cluster direction as an
alternative. It is not a validated TKG/VKS installation procedure. If that
alternative is pursued, it needs its own admission, storage, networking,
registry and recovery validation; native Supervisor lab results do not prove it.
