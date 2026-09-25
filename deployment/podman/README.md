# Podman Deployment Guide

This directory is reserved for the Podman runtime path.

## Intent

The expected Podman-focused work here is:

- running the built images on a Linux desktop or host with Podman
- validating the same service split used elsewhere in the repo
- documenting any runtime differences that matter outside Docker-specific
  workflows

## Current Status

This guide is not yet a validated runtime procedure.

Podman remains a target environment for follow-up testing, but the active
validated runtime paths today are:

- the Docker-host compose workflow
- the macOS Minikube workflow

Use those guides for the current tested paths:

- [Docker Host Runtime](../dockerhost/README.md)
- [Minikube on macOS](../minikube-macos/README.md)
