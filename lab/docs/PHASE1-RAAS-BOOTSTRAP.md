# Phase 1 – RaaS Bootstrap (Container Lab)

## Overview

This phase establishes a working VMware Aria Config (SaltStack Config) RaaS service running in a containerised environment.

The goal is to reach a functional UI backed by Postgres and Redis, without yet integrating the Salt master or importing initial data.

---

## Outcome

- RaaS container built from RPMs  
- PostgreSQL and Redis integrated  
- RaaS service starts cleanly  
- UI accessible on http://localhost:4507  
- All services healthy  
- Internal container networking functional  

---

## Architecture (Lab)

Service | Container Name | Ports  
---|---|---  
RaaS | ssc-raas | 4507  
PostgreSQL | ssc-postgres | 5432  
Redis | ssc-redis | 6379  
Salt Master | ssc-salt-master | 4505-4506  

Network:  
ssc-net (10.89.1.0/24)

---

## Key Implementation Details

### 1. RaaS Image Build

Base image:
- ubi9-minimal

Installed packages:
- python3.11  
- system utilities (openssl, tar, etc)

Installed RPMs:
- raas  
- libsodium  
- xmlsec stack  

GPG key imported before install.

Runtime directories created:

/etc/raas  
/var/log/raas  
/var/lib/raas  
/var/cache/raas  

---

### 2. User Model (Critical)

RaaS must not run as root, but setup tasks require root.

Working model:

1. Container starts as root  
2. Performs setup:
   - ldconfig  
   - config generation  
   - permissions  
3. Drops privileges to raas user  
4. RaaS runs as raas  

Failure modes observed:

Mode | Result  
---|---  
Non-root only | ldconfig + permission failures  
Root only | RaaS refuses to start  
Hybrid (correct) | Works  

---

### 3. Service Startup (No systemd)

Original (RPM/systemd):

ExecStart=/opt/saltstack/raas/scripts/raas  

Container equivalent:

/opt/saltstack/raas/bin/raas -c /etc/raas  

Systemd is not used — entrypoint handles startup.

---

### 4. Configuration

Config file:

/etc/raas/raas  

Generated from template (raas.example).

Credentials stored via:

raas save_creds  

Resulting file:

/etc/raas/raas.secconf  

---

### 5. Initialisation

Initial setup required:

raas setup  

This:
- creates database schema  
- initialises platform  
- enables login  

Without this step:
- UI loads  
- but system is not usable  

---

### 6. Container Stack

All services connected via:

ssc-net  

Example container IPs:

ssc-postgres     -> 10.89.1.31/24  
ssc-redis        -> 10.89.1.32/24  
ssc-salt-master  -> 10.89.1.33/24  
ssc-raas         -> 10.89.1.34/24  

---

## Validation

Container status:

podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"  

Network mapping:

podman network inspect ssc-net --format "{{range .Containers}}{{.Name}} -> {{range .Interfaces}}{{range .Subnets}}{{.IPNet}}{{end}}{{end}}{{println}}{{end}}"  

UI:

http://localhost:4507  

Expected:
- Login page renders  
- VMware branding visible  

---

## Known Behaviour / Quirks

### /version endpoint

- Returns 404  
- Service is still healthy  
- Not a reliable readiness check  

---

### ldconfig requirement

Must be executed after RPM install:

/usr/sbin/ldconfig  

---

### Locale warning

setlocale: cannot change locale (en_US.UTF-8)  

Safe to ignore.

---

### Podman network structure

IP address is not exposed as .IPv4Address.

Actual path:

interfaces.eth0.subnets[0].ipnet  

---

## Repository Constraints

### Do NOT commit:

- RaaS RPMs  
- dependency RPMs  
- extracted installer bundles  
- .raas import files  
- certificates / keys  
- license files  

### Safe to commit:

- Dockerfiles  
- compose files  
- entrypoint scripts  
- config templates  
- documentation  

---

## Phase Status

### Completed

- RaaS container build  
- Service startup  
- Database + Redis integration  
- UI accessible  

### Not Yet Implemented

- Salt master plugin integration  
- Initial object import  
- HA / multi-master support  

---

## Next Phase

### Phase 2

- Apply RaaS plugin to Salt master  
- Validate master appears in UI  

### Phase 3

- Import initial objects (sample-resource-types.raas)  
- Validate:
  - targets  
  - jobs  
  - dashboards populate  
