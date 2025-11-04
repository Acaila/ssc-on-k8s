# Secrets creation (do not commit real secrets)


kubectl -n aria-config create secret generic ssc-db \
--from-literal=host=postgres \
--from-literal=name=raas \
--from-literal=user=raas \
--from-literal=password='S3cr3tP@ss'

kubectl -n aria-config create secret generic ssc-redis \
--from-literal=host=redis \
--from-literal=port=6379

# Optional TLS for RaaS
kubectl -n aria-config create secret tls ssc-raas-tls \
--cert=server.crt --key=server.key