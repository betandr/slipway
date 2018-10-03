#!/usr/bin/env bash

# author: Beth Anderson (github.com/betandr)

if test "$#" -ne 0; then
    echo "Usage: sh 04_drone_up.sh"
    exit 1
fi

if ! [ -x "$(command -v kubectl)" ]; then
  echo 'Error: `kubectl` not found, to install see https://kubernetes.io/docs/tasks/tools/install-kubectl/' >&2
  exit 1
fi

if ! [ -x "$(command -v helm)" ]; then
  echo 'Error: `helm` not found, to install see https://docs.helm.sh/using_helm/' >&2
  exit 1
fi

K8S_CLUSTER=$(kubectl config current-context)

while true; do
    read -p "Install Drone on the \`$K8S_CLUSTER\`? Are you sure?  (y/n)? " yn
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

          echo "---> ACTION: enter project name:"
          read X_PROJECT
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_PROJECT#${X_PROJECT}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_PROJECT#${X_PROJECT}#g" -i resources/drone/values.yaml

          echo "---> ACTION: enter hostname drone.example.com:"
          read X_SERVER_HOST
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_SERVER_HOST#${X_SERVER_HOST}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_SERVER_HOST#${X_SERVER_HOST}#g" -i resources/drone/values.yaml

          echo "---> ACTION: enter protocol, such as https:"
          read X_SERVER_PROTOCOL
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_SERVER_PROTOCOL#${X_SERVER_PROTOCOL}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_SERVER_PROTOCOL#${X_SERVER_PROTOCOL}#g" -i resources/drone/values.yaml

          echo "---> ACTION: enter the username of the drone admin:"
          read X_DRONE_ADMIN
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_DRONE_ADMIN#${X_DRONE_ADMIN}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_DRONE_ADMIN#${X_DRONE_ADMIN}#g" -i resources/drone/values.yaml

          echo "---> ACTION: enter Github Oauth Client ID:"
          read X_DRONE_GITHUB_CLIENT
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_DRONE_GITHUB_CLIENT#${X_DRONE_GITHUB_CLIENT}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_DRONE_GITHUB_CLIENT#${X_DRONE_GITHUB_CLIENT}#g" -i resources/drone/values.yaml

          echo "---> ACTION: enter Github Oauth Secret:"
          read X_DRONE_GITHUB_SECRET
          [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_DRONE_GITHUB_SECRET#${X_DRONE_GITHUB_SECRET}#g" -i "" resources/drone/values.yaml
          [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_DRONE_GITHUB_SECRET#${X_DRONE_GITHUB_SECRET}#g" -i resources/drone/values.yaml

          echo "---> Configuration saved to resources/drone/values.yaml"

          echo "---> Creating Tiller RBAC"
          kubectl apply -f resources/drone/tiller-rbac-config.yaml

          echo "---> Configuring Tiller and waiting for rollout"
          helm init --service-account tiller;kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system;

          echo "---> Installing Drone with Helm"
          helm install --name $X_PROJECT -f resources/drone/values.yaml stable/drone

          while true; do
              read -p "Install cert-manager to manage certs? (y/n)? " yn
              case $yn in
                  [Yy]* )
                    [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_PROJECT#${X_PROJECT}#g" -i "" resources/drone/drone-cert.yaml
                    [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_PROJECT#${X_PROJECT}#g" -i resources/drone/drone-cert.yaml

                    [ "$KERNEL_NAME" == "Darwin" ] && sed -e "s#X_SERVER_HOST#${X_SERVER_HOST}#g" -i "" resources/drone/drone-cert.yaml
                    [ "$KERNEL_NAME" == "Linux" ] && sed -e "s#X_SERVER_HOST#${X_SERVER_HOST}#g" -i resources/drone/drone-cert.yaml

                    helm install --name cert-manager --namespace kube-system stable/cert-manager

                    kubectl apply -f resources/drone/drone-cert.yaml

                    kubectl apply -f resources/drone/acme-issuer.yaml

                    break;;
                  [Nn]* )
                    echo "As you have not set up cert-manager you will need to set $X_PROJECT-drone-tls manually"
                    break;;
                  * ) echo "Please answer 'y' for yes or 'n' for no.";;
              esac
          done

          echo "To update Drone later you can edit the resources/drone/drone-cert.yaml file and run:"
          echo "`helm upgrade $X_PROJECT -f resources/drone/values.yaml stable/drone`"

          break;;
        [Nn]* ) exit;;
        * ) echo "Please answer 'y' for yes or 'n' for no.";;
    esac
done
