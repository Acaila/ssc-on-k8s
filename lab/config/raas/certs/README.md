# RaaS TLS Certificate Mount

This directory is the local host-side mount point for RaaS TLS material during
Docker-based lab runs.

Behavior:

- if a certificate and key are placed here, the container uses them
- if the directory is empty, the RaaS entrypoint generates a self-signed pair

Generated certificate and key files are intentionally ignored by git.
