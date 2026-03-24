# Bundle Staging

Place downloaded Broadcom bundle files in this directory when preparing local
image builds.

Typical local contents:

- the official Broadcom RaaS installer tarball
- the separate salt-minion bundle tarball for later air-gapped work
- the extracted `sse-installer/` tree

This directory is local staging only. The bundle payloads themselves are not
committed to git.
