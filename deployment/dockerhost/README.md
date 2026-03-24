# Docker Host Runtime Guide

This guide covers the Docker-host runtime path for the container images in this
repository.

The image-build workflow is documented separately in:

- [images/README.md](../../images/README.md)

## Scope

Use this path when you want to:

- run PostgreSQL, Redis, RaaS, and salt-master directly on a Docker host
- validate container behavior before moving the images into a registry
- troubleshoot service startup without introducing Kubernetes variables

## Runtime Files

The active runtime workflow is driven by the compose files under:

- [lab/compose/](../../lab/compose/)

Those files support:

- split service bring-up for troubleshooting
- full stack bring-up for convenience
- host-side RaaS port override when `443` is already in use

## Current Source Of Truth

For the current Docker-host workflow, use:

- [images/README.md](../../images/README.md)

That document already covers:

- image build prerequisites
- compose-based runtime bring-up
- RaaS port override
- first-login behavior for accepting the pending Salt master key
- registry retag/push flow

This file exists mainly to give the Docker-host runtime a stable place in the
platform guide layout alongside the Kubernetes targets.
