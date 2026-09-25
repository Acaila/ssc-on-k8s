# Runtime secrets

The primary [Supervisor workflow](../deployment/supervisor/README.md) expects:

| Secret | Required content |
| --- | --- |
| `ssc-db` | `name`, `user`, `password` |
| `ssc-registry` | `.dockerconfigjson`, type `kubernetes.io/dockerconfigjson`, pull-only registry identity |
| `ssc-web-tls` | `tls.crt`, `tls.key`, type `kubernetes.io/tls`, certificate matching the Contour hostname |
| `ssc-bootstrap` (optional) | Stable `customer_id` and `cluster_id` UUID strings |

Create these in the workload namespace through an operator or secret manager
before workload deployment. The repo does not install a secret-management controller.
Follow the [file-based bootstrap examples](../deployment/supervisor/README.md#secret-contract)
and [registry pull-secret procedure](../deployment/supervisor/registry.md).
Do not commit rendered Secret objects: base64 encoding is not encryption.

Generated RaaS/master identities persist on their PVCs when explicit bootstrap
UUIDs are omitted. Preserve those identities across upgrades and restore them
with the corresponding database and key material. Never generate replacement
UUIDs merely because a deployment is being reapplied.

`POSTGRES_*` initialization values apply to a fresh database volume. Updating
`ssc-db` alone does not rotate the PostgreSQL role password; coordinate the DB
change, secret update and client restart. Likewise, renew Harbor credentials
before expiry and update the runtime pull secret. Registry authentication does not configure native-runtime CA trust.

The current Redis service has no configured password; it remains an internal
ClusterIP dependency. Complete the product's initial administrator setup and manage credential
changes and recovery through the operator's vault.

For optional local development, the root manifests use namespace `aria-config`
and local images, so registry/Contour secrets are not consumed there. The
[identity example](ssc-bootstrap.example.yaml) shows the optional Secret shape;
replace its sample values and select the correct namespace before use.

For `ssc-web-tls`, choose operator-supplied credentials or cert-manager issuance
using the [certificate guide](../deployment/supervisor/certificates.md). Do not
manually replace a secret managed by cert-manager.
