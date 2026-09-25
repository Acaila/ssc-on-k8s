echo "Containers"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo 
echo "Network statck"
podman network inspect ssc-net | jq -r '.[0].containers[] | "\(.name) -> \(.interfaces.eth0.subnets[0].ipnet)"'
