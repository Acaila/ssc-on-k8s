# Certificates for SSC on Supervisor

Choose one edge-certificate mode in `settings.json`. Both use `ssc-web-tls` in
the workload namespace, referenced by Contour HTTPProxy. Use the SSC hostname
in the certificate's DNS Subject Alternative Names (SANs). Establish trust in
its issuing CA on browsers/API clients as part of platform setup.

This configures **browser/API → Contour** TLS. It does not change registry CA
trust or the internal RaaS certificate. The current upstream/master paths use
TLS without certificate verification; authenticated internal TLS and coordinated
RaaS certificate reload remain follow-up work.

## Supplied certificate

The default settings select:

```json
"tls": {"mode": "existing"}
```

Obtain a certificate from your organization's CA with the correct DNS SAN and
server-auth usage. Supply the certificate chain (leaf first, then intermediates)
and matching private key through your vault. Using the deployment guide's
`kssc` function, create the secret on first installation:

```bash
kssc create secret tls ssc-web-tls \
  --cert=/secure/ssc-tls/tls.crt --key=/secure/ssc-tls/tls.key
```

Before supplying it, check expiry, hostname and CA chain locally with OpenSSL:

```bash
openssl x509 -in /secure/ssc-tls/tls.crt -noout -dates -checkhost "$SSC_HOSTNAME"
openssl verify -CAfile /secure/ssc-tls/root-ca.crt \
  -untrusted /secure/ssc-tls/intermediates.crt /secure/ssc-tls/tls.crt
```

Set `SSC_HOSTNAME` to the configured hostname. Omit `-untrusted` if the leaf is
signed directly by your trusted root. These checks do not replace validation of
the certificate actually served by Envoy. Keep files restricted and outside Git.
Assign an expiry/renewal owner. For renewal, update the existing Secret using
your secret manager and verify the new certificate at the external endpoint.

## Automated issuance and renewal

Use an existing platform cert-manager installation with a Ready issuer that the
namespace may use. The Supervisor CA Cluster Issuer service is one platform
option; select a compatible service version with the platform owner. This repo
does not install controllers, create a root CA, or distribute CA private keys.

Replace the TLS object before generating your environment:

```json
"tls": {
  "mode": "cert-manager",
  "issuer_name": "your-platform-ca",
  "issuer_kind": "ClusterIssuer"
}
```

Use `Issuer` for a namespaced issuer in the workload namespace, or
`ClusterIssuer` for a cluster-scoped issuer. Both refer to `cert-manager.io`.
The generator writes `bootstrap/certificate.yaml`, requesting the SSC DNS name
and targeting `ssc-web-tls`. Review and apply it before workload preflight:

```bash
kssc apply --dry-run=server -f "$SSC_ENV/bootstrap/certificate.yaml"
kssc apply -f "$SSC_ENV/bootstrap/certificate.yaml"
kssc wait --for=condition=Ready certificate/ssc-web --timeout=5m
kssc get certificate ssc-web
```

Do not also create the TLS Secret manually in this mode. If issuance fails,
inspect the Certificate and CertificateRequest events and issuer readiness.
The issuer must support its configured validation method: an ACME issuer may
need DNS or HTTP challenge plumbing beyond this template. An existing internal
CA issuer avoids assuming public DNS reachability for private deployments.

cert-manager maintains the requested certificate and renews it. The template
explicitly rotates the private key on reissuance; certificate lifetime follows
the issuer/controller policy. Monitor Ready status, renewal failures and expiry.
CA rotation, issuer availability and client trust distribution remain platform
responsibilities. See the [Certificate API workflow](https://cert-manager.io/docs/usage/certificate/)
and [CA issuer lifecycle considerations](https://cert-manager.io/docs/configuration/ca/).

## Verify after deployment and renewal

```bash
curl --fail --cacert /secure/ssc-tls/root-ca.crt "https://$SSC_HOSTNAME/"
kssc get httpproxy ssc-web
```

Confirm the hostname, chain, expiry and expected issuer of the externally served
certificate, including after renewal. An issued Certificate alone does not prove
that DNS points to the right Envoy or that its new certificate is being served.
Never commit private keys or rendered TLS Secrets to your deployment repository.
