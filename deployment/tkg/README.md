# TKG Deployment Guide

This directory is reserved for the TKG deployment path.

## Intent

TKG is the primary target Kubernetes platform direction for this repository.

The aim is to document:

- image sourcing from a registry rather than local node image loads
- storage expectations for PostgreSQL, Redis, RaaS, and Salt master
- service exposure and ingress decisions appropriate to TKG
- security context adjustments needed to align with the target cluster profile
- future scale-out considerations such as shared minion trust state

## Current Status

This guide is not yet a validated deployment procedure.

At the moment, the most complete validated Kubernetes path is:

- [Minikube on macOS](../minikube-macos/README.md)

Use that guide for the currently exercised Kubernetes workflow, and treat this
directory as the placeholder for the next platform-specific documentation pass.
