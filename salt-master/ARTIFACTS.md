Air-gapped minion artifacts
===========================

RaaS/Salt may need pre-staged installers and bootstrap assets for air gapped eployments.

Expected in the salt-master container:
- /etc/salt/deployment.d/      (minion binaries/installers)
- /etc/salt/cloud.deploy.d/    (bootstrap scripts/templates)
- /etc/salt/cloud.profiles.d/  (cloud profiles)

This repo uses a content image + initContainer to copy files into a PVC at startup.
Update the image reference in kustomization.yaml to point to your internal registry.