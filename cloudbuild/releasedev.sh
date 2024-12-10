#!/bin/bash
dbimage=`jq -r '.dev | .db' /workspace/cloudbuild/$release/release.json`
backendimage=`jq -r '.dev | .backend' /workspace/cloudbuild/$release/release.json`
javabackendimage=`jq -r '.dev | .springbootsvc' /workspace/cloudbuild/$release/release.json`
frontendimage=`jq -r '.dev | .frontend' /workspace/cloudbuild/$release/release.json`


echo $dbimage
echo $backendimage
echo $javabackendimage
echo $frontendimage


# updating k8 yaml for dev
# Yaml update for stg
sed -i "s/image: backendvm/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$backendimage/g" /workspace/cloudbuild/techgig-cicd-demo-backend/k8s/dev/api-deployment.yaml
sed -i "s/image: springbootbackend/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$javabackendimage/g" /workspace/cloudbuild/cicd-demo-backend-java/k8s/dev/api-deployment.yaml
sed -i "s/image: frontendvm/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$frontendimage/g" /workspace/cloudbuild/techgig-cicd-demo-frontend/k8s/dev/fe-deployment.yaml
sed -i "s/image: IMAGE/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$dbimage/g" /workspace/cloudbuild/techgig-cicd-demo-db/k8s/dev/db-deployment.yaml

#Displaying yaml value for stg yaml
cat /workspace/cloudbuild/techgig-cicd-demo-backend/k8s/dev/api-deployment.yaml
cat /workspace/cloudbuild/cicd-demo-backend-java/k8s/dev/api-deployment.yaml
cat /workspace/cloudbuild/techgig-cicd-demo-frontend/k8s/dev/fe-deployment.yaml
cat /workspace/cloudbuild/techgig-cicd-demo-db/k8s/dev/db-deployment.yaml