#!/usr/bin/env bash

# This script is based on https://github.com/appleboy/drone-on-kubernetes/tree/master/gke
# by: Bo-Yi Wu (github.com/appleboy)
# author: Beth Anderson (github.com/betandr)

if test "$#" -ne 1; then
    echo "Usage: sh 04_drone_up.sh \$ZONE"
    exit 1
fi

if ! [ -x "$(command -v kubectl)" ]; then
  echo 'Error: kubectl not found, to install see https://kubernetes.io/docs/tasks/tools/install-kubectl/' >&2
  exit 1
fi

if ! [ -x "$(command -v gcloud)" ]; then
  echo 'Error: gcloud not found, to install see https://cloud.google.com/sdk/downloads' >&2
  exit 1
fi

echo "\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" \
":: This script can create a NEW persistent disk for the Drone server   ::\n" \
":: database although you may wish to use an existing disk to maintain  ::\n" \
":: state between deployments.                                          ::\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"

GCP_PROJECT=$(gcloud info --format='value(config.project)')

while true; do
    read -p "Create a NEW persistent disk \`drone-server-db\` in zone \`$1\` in the \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )
          gcloud compute disks create --size 10GB drone-server-db --zone=$1
          break;;
        [Nn]* ) break;;
        * ) echo "Please answer 'y' for yes or 'n' for no.";;
    esac
done

while true; do
    read -p "Install Drone on the current cluster in the \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )
          KERNEL_NAME=$(uname -s)
          kubectl cluster-info > /dev/null 2>&1
          if [ $? -eq 1 ]
          then
            echo "---> kubectl was unable to reach your Kubernetes cluster. Make sure that" \
                 "you have selected one."
            exit 1
          fi

          echo "---> clearing out any existing configmap..."
          kubectl delete namespace drone 2> /dev/null

          echo "---> create drone namespace..."
          kubectl create -f resources/drone/namespace.yaml 2> /dev/null

          echo "---> generating secrets..."
          if [ "$KERNEL_NAME" == "Darwin" ]; then
            DRONE_TOKEN=`openssl rand -base64 8 | md5 | head -c8; echo`
          else
            DRONE_TOKEN=`cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
          fi
          B64_DRONE_TOKEN=`echo $DRONE_TOKEN | base64`
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s/X_BASE64_ENCODED_SECRET/${B64_DRONE_TOKEN}/g" -i "" resources/drone/secret.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s/X_BASE64_ENCODED_SECRET/${B64_DRONE_TOKEN}/g" -i resources/drone/secret.yaml

          echo "---> creating secrets..."
          kubectl create -f resources/drone/secret.yaml 2> /dev/null

          echo "---> setting server admin username to $USER..."
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s/X_SERVER_ADMIN/${USER}/g" -i "" resources/drone/configmap.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s/X_SERVER_ADMIN/${USER}/g" -i resources/drone/configmap.yaml

          echo "---> ACTION: enter hostname with scheme, such as http://drone.example.com:"
          read GCI_HON
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_HOSTNAME#${GCI_HON}#g" -i "" resources/drone/configmap.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_HOSTNAME#${GCI_HON}#g" -i resources/drone/configmap.yaml

          echo "---> ACTION: enter Github Oauth2 Client ID:"
          read GCI_VAL
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s/X_GITHUB_CLIENT/${GCI_VAL}/g" -i "" resources/drone/configmap.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s/X_GITHUB_CLIENT/${GCI_VAL}/g" -i resources/drone/configmap.yaml

          echo "---> ACTION: enter Github Oauth2 secret:"
          read GOS_VAL
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s/X_GITHUB_SECRET/${GOS_VAL}/g" -i "" resources/drone/configmap.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s/X_GITHUB_SECRET/${GOS_VAL}/g" -i resources/drone/configmap.yaml

          echo "---> creating configmap..."
          kubectl create -f resources/drone/configmap.yaml 2> /dev/null

          echo "---> creating server deployment..."
          kubectl create -f resources/drone/server-deployment.yaml 2> /dev/null

          echo "---> creating service..."
          kubectl create -f resources/drone/server-service.yaml 2> /dev/null

          echo "---> creating agent deployment..."
          kubectl create -f resources/drone/agent-deployment.yaml 2> /dev/null

          echo "---> creating ingress controller..."
          kubectl create -f resources/drone/ingress.yaml 2> /dev/null


          while true; do
              read -p "Watch pod creation? (Ctrl+C to Quit) (y/n)? " yn
              case $yn in
                  [Yy]* )
                    watch kubectl --namespace=drone get pods
                    break;;
                  [Nn]* ) break;;
                  * ) echo "Please answer 'y' for yes or 'n' for no.";;
              esac
          done

          echo "\n" \
          ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" \
          "::  Drone Agent installation                                             ::\n" \
          ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
          kubectl get services --namespace=drone
          echo "  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
          kubectl --namespace=drone get deployments
          echo "  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
          kubectl --namespace=drone get pods
          echo "  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

          break;;
        [Nn]* ) exit;;
        * ) echo "Please answer 'y' for yes or 'n' for no.";;
    esac
done
