# SaltStack Config (Aria Config) on Kubernetes — Proof of Concept

This repository contains an experimental deployment of VMware/Broadcom SaltStack Config (SSC / Aria Config) components as containers on Kubernetes.  
The target platform is a Tanzu Kubernetes Grid (TKG) cluster running under vSphere with Tanzu (VKS).

Status: Proof of Concept / Work in Progress  
This configuration is not tested, not supported by VMware or Broadcom, and should only be used for lab or evaluation purposes.

---

## Overview

SaltStack Config is normally deployed as a monolithic appliance.  
This proof of concept separates it into individual containers that can be managed by Kubernetes.  
Each container uses a PersistentVolume for configuration or data to preserve state across restarts.

| Component | Description | Persistent Storage | Folder |
|------------|--------------|--------------------|---------|
| RaaS | Core SSC API service built from SSC RPMs | /etc/raas, /var/log/raas | raas/ |
| Salt Master | Handles external Salt minions | /etc/salt, /srv/salt | salt-master/ |
| Redis | Message bus and job queue | /data | redis/ |
| PostgreSQL | Database backend | /var/lib/postgresql/data | postgres/ |

All containers are configured to run as non-root with a read-only root filesystem and no privilege escalation, following the default security policies applied in TKG and VKS clusters.

Minions are external to the cluster. The Salt Master service exposes TCP ports 4505 and 4506 through a LoadBalancer or NodePort service.

---

## Features

- Runs in its own namespace (`aria-config`)
- Uses PersistentVolumeClaims for data and configuration
- Built from official SSC RPMs on a RHEL9/UBI9 base image
- Compatible with air-gapped environments (Harbor-hosted images)
- Includes NetworkPolicies for least-privilege access between components
- Optional Kustomize file for single-command deployment
- Compatible with default PodSecurity policies in TKG and VKS

---

## Folder Structure

```
ssc-on-k8s/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── storage/
│   ├── pvc-postgres.yaml
│   ├── pvc-redis.yaml
│   ├── pvc-raas.yaml
│   └── pvc-salt-master.yaml
├── config/
│   └── raas-configmap.yaml
├── postgres/
│   ├── deployment.yaml
│   └── service.yaml
├── redis/
│   ├── deployment.yaml
│   └── service.yaml
├── raas/
│   ├── deployment.yaml
│   └── service.yaml
├── salt-master/
│   ├── deployment.yaml
│   └── service.yaml
├── networkpolicy/
│   ├── 00-default-deny.yaml
│   ├── 01-allow-dns-egress.yaml
│   ├── 10-raas.yaml
│   ├── 11-postgres.yaml
│   ├── 12-redis.yaml
│   └── 20-salt-master.yaml
├── secrets/
│   └── README.md
└── Dockerfiles/
    └── Dockerfile.raas
```

---

## Deployment Steps

1. Build and push the RaaS container image to your internal registry:
   ```bash
   docker build -f Dockerfiles/Dockerfile.raas -t harbor.local/ssc/raas:9.x .
   docker push harbor.local/ssc/raas:9.x
   ```

2. Create the namespace, PVCs, and configuration map:
   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -f storage/
   kubectl apply -f config/
   ```

3. Create the required secrets (see `secrets/README.md` for examples):
   ```bash
   kubectl -n aria-config create secret generic ssc-db      --from-literal=host=postgres      --from-literal=name=raas      --from-literal=user=raas      --from-literal=password='S3cr3tP@ss'
   ```

4. Deploy the components:
   ```bash
   kubectl apply -f postgres/
   kubectl apply -f redis/
   kubectl apply -f raas/
   kubectl apply -f salt-master/
   kubectl apply -f networkpolicy/
   ```

5. Verify that the pods are running:
   ```bash
   kubectl get pods -n aria-config
   ```

---

## Security Notes

- All pods run with the following restrictions:
  - runAsNonRoot: true
  - allowPrivilegeEscalation: false
  - readOnlyRootFilesystem: true
  - seccompProfile: RuntimeDefault
  - capabilities: drop: ["ALL"]
- NetworkPolicies are configured to enforce a deny-all baseline and allow only the required traffic between RaaS, Postgres, and Redis.
- The Salt Master ingress policy allows external minions to connect on TCP 4505–4506.  
  Restrict this CIDR range in `networkpolicy/20-salt-master.yaml` to match your environment.
- Secrets are not included in this repository and must be created manually.

---

## Limitations and Next Steps

- This configuration is single-pod per component and not highly available.
- Postgres and Redis are provided for convenience and should be replaced with operator-managed or external equivalents in production.
- RaaS replication and HA are not yet tested.
- TLS configuration can be added by mounting certificates as Kubernetes secrets and referencing them in `raas.conf`.

---

## Disclaimer

This project is experimental and intended for testing or demonstration only.  
It is not endorsed, maintained, or supported by VMware or Broadcom.  
There is no guarantee of functionality, compatibility, or security.  
Use at your own risk.

---

## License

This repository is released under the MIT License.  
Any VMware or Broadcom proprietary binaries required for building the RaaS container image are excluded from this license and must be obtained separately.
