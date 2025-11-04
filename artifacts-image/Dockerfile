# artifacts-image/Dockerfile
FROM alpine:3.20
# Expect local folders next to this Dockerfile when building
#   deployment.d/
#   cloud.deploy.d/
#   cloud.profiles.d/
RUN adduser -S -D -H -h /nonexistent nonroot
USER nonroot
WORKDIR /payload
COPY deployment.d/ ./deployment.d/
COPY cloud.deploy.d/ ./cloud.deploy.d/
COPY cloud.profiles.d/ ./cloud.profiles.d/
