Build:
  docker build -t registry.example.com/ssc/minion-artifacts:1.0 artifacts-image/
Push:
  docker push registry.example.com/ssc/minion-artifacts:1.0

Directory layout (next to Dockerfile):
  artifacts-image/
    Dockerfile
    deployment.d/
    cloud.deploy.d/
    cloud.profiles.d/
