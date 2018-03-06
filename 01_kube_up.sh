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
    read -p "Create \`spinnaker-cluster-$1\` in zone \`$3\` (y/n)? " yn
    case $yn in
        [Yy]* )
      		echo "---> creating spinnaker-cluster-$1 in the $GCP_PROJECT project in zone $4..."
          gcloud container clusters create "spinnaker-cluster-$1" \
            --project $GCP_PROJECT \
            --zone $4 \
            --machine-type "n1-standard-1" \
            --num-nodes "3" \
            --labels env=production,owner=$USER

          echo "---> reserving static address for spin deck"
          gcloud compute addresses create spinnaker-$1 \
            --project=$GCP_PROJECT \
            --region=$3
          gcloud compute addresses list --filter="name=('spinnaker-$1')"
          read -n 1 -s -r -p "---> note the address then press any key to continue\n"

          echo "---> reserving static address for spin gate"
          gcloud compute addresses create spinnaker-api-$1 \
            --project=$GCP_PROJECT \
            --region=$3
          gcloud compute addresses list --filter="name=('spinnaker-api-$1')"
          read -n 1 -s -r -p "---> note the address then press any key to continue\n"

      		echo "---> complete..."

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Create \`$2-cluster-$1\` in zone \`$3\` (y/n)? " yn
    case $yn in
        [Yy]* )
      		echo "---> creating $2-cluster-$1..."
          gcloud container clusters create "$2-cluster-$1" \
            --project $GCP_PROJECT \
            --zone $4 \
            --machine-type "n1-standard-2" \
            --num-nodes "6" \
            --labels env=production,owner=$USER

            echo "---> complete..."

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
