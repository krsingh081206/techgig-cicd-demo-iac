#!/bin/bash
dbimage=`jq -r '.staging | .db' /workspace/cloudbuild/$release/release.json`
backendimage=`jq -r '.staging | .backend' /workspace/cloudbuild/$release/release.json`
frontendimage=`jq -r '.staging | .frontend' /workspace/cloudbuild/$release/release.json`


echo $dbimage
echo $backendimage
echo $frontendimage


# updating k8 yaml for staging
# Yaml update for stg
sed -i "s/image: backendvm/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$backendimage/g" /workspace/cloudbuild/techgig-cicd-demo-backend/k8s/staging/api-deployment.yaml
sed -i "s/image: frontendvm/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$frontendimage/g" /workspace/cloudbuild/techgig-cicd-demo-frontend/k8s/staging/fe-deployment.yaml
sed -i "s/image: IMAGE/image: us-east4-docker.pkg.dev\/$projectid\/techgig-cicd\/$dbimage/g" /workspace/cloudbuild/techgig-cicd-demo-db/k8s/staging/db-deployment.yaml

#Displaying yaml value for stg yaml
cat /workspace/cloudbuild/techgig-cicd-demo-backend/k8s/staging/api-deployment.yaml
cat /workspace/cloudbuild/techgig-cicd-demo-frontend/k8s/staging/fe-deployment.yaml
cat /workspace/cloudbuild/techgig-cicd-demo-db/k8s/staging/db-deployment.yaml