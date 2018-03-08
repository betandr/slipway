#!/usr/bin/env bash

# This script is based on https://www.spinnaker.io/setup/quickstart/halyard-gke/
# author: Beth Anderson (github.com/betandr)

if test "$#" -ne 4; then
    echo "Usage: sh 01_kube_up.sh $INDEX $CLUSTER_NAME $IP_REGION $CLUSTER_ZONE"
    exit 1
fi

echo "\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" \
":: Warning: This script will provision infrastructure in the cloud and   ::\n" \
":: could therefore cost money. Please be sure that you do want to        ::\n" \
":: proceed and you understand the implications!                          ::\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"

GCP_PROJECT=$(gcloud info --format='value(config.project)')

while true; do
    read -p "Create \`spinnaker-cluster-$1\` in zone \`$4\` in the \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )
          # TODO remove this when Kubernetes v1.10 released
          gcloud config set container/new_scopes_behavior true

      		echo "---> creating spinnaker-cluster-$1 in the $GCP_PROJECT project in zone $4..."
          gcloud container clusters create "spinnaker-cluster-$1" \
            --project $GCP_PROJECT \
            --zone $4 \
            --username "admin" \
            --machine-type "n1-standard-1" \
            --image-type "COS" \
            --disk-size "100" \
            --num-nodes "3" \
            --network "default" \
            --enable-cloud-logging \
            --enable-cloud-monitoring \
            --subnetwork "default" \
            --labels env=production$1,owner=$USER
      		echo "---> complete..."

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Reserve 2 external IPs for Spinnaker in \`$3\` region and \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )
          echo "---> reserving static address for spin deck"
          gcloud compute addresses create spinnaker-$1 \
            --project=$GCP_PROJECT \
            --region=$3
          gcloud compute addresses list --filter="name=('spinnaker-$1')"
          read -n 1 -s -r -p "---> note the address then press any key to continue"
          echo ""

          echo "---> reserving static address for spin gate"
          gcloud compute addresses create spinnaker-api-$1 \
            --project=$GCP_PROJECT \
            --region=$3
          gcloud compute addresses list --filter="name=('spinnaker-api-$1')"
          read -n 1 -s -r -p "---> note the address then press any key to continue"
          echo ""

      		echo "---> complete..."

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Create \`$2-cluster-$1\` in zone \`$4\` in the \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )
          # TODO remove this when Kubernetes v1.10 released
          gcloud config set container/new_scopes_behavior true

      		echo "---> creating $2-cluster-$1..."
          gcloud container clusters create "$2-cluster-$1" \
            --project $GCP_PROJECT \
            --zone $4 \
            --username "admin" \
            --machine-type "n1-standard-2" \
            --image-type "COS" \
            --disk-size "100" \
            --num-nodes "6" \
            --network "default" \
            --enable-cloud-logging \
            --enable-cloud-monitoring \
            --subnetwork "default" \
            --labels env=production$1,owner=$USER
          echo "---> complete..."

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
