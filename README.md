# SaltStack Config On Kubernetes

This repository is a lab project for breaking Broadcom SaltStack Config (SSC, formerly Aria Config) into containerized components that can eventually be deployed on Kubernetes.

The long-term intent is to prove a practical path from the appliance-style Broadcom deployment model to:

- repeatable container image builds
- local desktop validation with Docker
- image promotion into a registry
- later Kubernetes deployment work

This is still a proof-of-concept repository. It is not a supported Broadcom or VMware deployment method.

## Current Status

What we have working today:

- repeatable builds for the Broadcom-based `ssc-raas` and `ssc-salt-master` container images
- helper scripts to stage the official Broadcom bundle and preflight the build environment
- local Docker Compose validation for PostgreSQL, Redis, RaaS, and salt-master
- RaaS running on HTTPS `443` in-container, with self-signed certificate generation when no certificate is provided
- support for overriding the host-side published RaaS port during local Docker testing

What is not yet claimed as complete:

- a finished or fully validated Kubernetes deployment
- a complete replacement for the full Broadcom appliance behavior

## Build Workflow

The current source of truth for building the container images is:

- [images/README.md](images/README.md)

That guide covers:

- obtaining the official Broadcom installer bundle
- extracting and staging the required artifacts
- running the preflight checks
- building the RaaS and salt-master images
- optionally starting the local Docker lab
- tagging and pushing the resulting images to a registry

If you are starting from a fresh clone, begin there.

## Repository Intent

The repository is organized around a staged workflow:

- `images/` contains the Dockerfiles, image assets, and the image build guide
- `scripts/` contains the bundle staging, preflight, and image build helpers
- `lab/compose/` contains the local Docker Compose files used to validate the containerized stack on a desktop or laptop
- Kubernetes manifests in the repo represent ongoing work and design direction, but should not be read as a finished deployment story yet

## Known Gaps

- The Broadcom payloads used here are `x86_64`, so non-`x86_64` desktop hosts build the Broadcom-based images as `linux/amd64`
- The appliance-style VIP localization endpoint expected by RaaS on `127.0.0.1:8091` is not included in the current containerized lab
- The separate air-gapped minion bundle may be staged in `bundle/`, but it is not part of the current image build workflow

These gaps do not block the current image build and local lab validation workflow.

## Disclaimer

This project is experimental and intended for lab, evaluation, and design work only.

It is not endorsed, maintained, or supported by VMware or Broadcom. There is no guarantee of functionality, compatibility, or security. Use it at your own risk.

## License

This repository is released under the MIT License.

Broadcom or VMware proprietary binaries are not included in git and must be obtained separately under their own licensing terms.
