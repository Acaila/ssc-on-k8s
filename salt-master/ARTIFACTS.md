# Salt Master Artifacts Placeholder

This file is a placeholder for a later phase of the project.

The original intent was to support pre-staged salt-minion installers and other
bootstrap assets for air-gapped or Aria Automation-integrated deployments.
That path is not part of the current validated workflow.

Current status:

- the top-level `bundle/` directory may contain the separate minion bundle
- the active image build flow does not consume that bundle yet
- the public test focus for this repo is the RaaS and salt-master image build process

When this area is resumed, document:

- the expected artifact layout
- how the artifacts image is built
- how those assets are presented to the salt-master in Kubernetes
