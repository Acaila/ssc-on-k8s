-- Run once against the dedicated SSC PostgreSQL instance as its administrator.
-- Detect disappeared native pod clients and release their advisory locks.
-- ALTER SYSTEM persists on the PostgreSQL PVC; no server restart is required.
ALTER SYSTEM SET tcp_keepalives_idle = '60';
ALTER SYSTEM SET tcp_keepalives_interval = '10';
ALTER SYSTEM SET tcp_keepalives_count = '3';
SELECT pg_reload_conf();
