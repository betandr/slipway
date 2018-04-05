#!/usr/bin/env bash

# This script is based on https://www.spinnaker.io/setup/quickstart/halyard-gke/
# author: Beth Anderson (github.com/betandr)

if test "$#" -ne 1; then
    echo "Usage: sh 01_hal_up.sh $INDEX"
    exit 1
fi

echo "\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" \
":: Warning: This script will provision infrastructure in the cloud and   ::\n" \
":: could therefore cost money. Please be sure that you do want to        ::\n" \
":: proceed and you understand the implications!                          ::\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"

while true; do
    read -p "Create \`halyard-host-$1\` and service accounts (y/n)? " yn
    case $yn in
        [Yy]* )
      		GCP_PROJECT=$(gcloud info --format='value(config.project)')
      		HALYARD_SA=halyard-service-account-$1

      		echo "---> creating Halyard host VM service account..."
      		gcloud iam service-accounts create $HALYARD_SA \
      		    --project=$GCP_PROJECT \
      		    --display-name $HALYARD_SA

      		HALYARD_SA_EMAIL=$(gcloud iam service-accounts list \
      		    --project=$GCP_PROJECT \
      		    --filter="displayName:$HALYARD_SA" \
      		    --format='value(email)')

      		gcloud projects add-iam-policy-binding $GCP_PROJECT \
      		    --role roles/iam.serviceAccountKeyAdmin \
      		    --member serviceAccount:$HALYARD_SA_EMAIL

      		gcloud projects add-iam-policy-binding $GCP_PROJECT \
      		    --role roles/container.admin \
      		    --member serviceAccount:$HALYARD_SA_EMAIL

          echo "---> creating Spinnaker and cluster service account..."
          GCS_SPIN_SA=gcs-spin-service-account-$1

          echo "---> creating GCS and GCR service accounts..."
          gcloud iam service-accounts create $GCS_SPIN_SA \
              --project=$GCP_PROJECT \
              --display-name $GCS_SPIN_SA

          GCS_SA_SPIN_EMAIL=$(gcloud iam service-accounts list \
              --project=$GCP_PROJECT \
              --filter="displayName:$GCS_SPIN_SA" \
              --format='value(email)')

          gcloud projects add-iam-policy-binding $GCP_PROJECT \
              --role roles/storage.admin \
              --member serviceAccount:$GCS_SA_SPIN_EMAIL

          HALYARD_HOST=$(echo halyard-host-$1 | tr '_.' '-')

          echo "---> creating VM instance for halyard-host-$1..."
          gcloud compute instances create $HALYARD_HOST \
              --custom-cpu 1 \
              --custom-memory 2304MB \
              --project=$GCP_PROJECT \
              --zone=europe-west2-c \
              --scopes=cloud-platform \
              --service-account=$HALYARD_SA_EMAIL \
              --image-project=ubuntu-os-cloud \
              --image-family=ubuntu-1404-lts \
              --labels env=production$1,owner=$USER

          echo "gcloud compute ssh $HALYARD_HOST" \
            "--project=$GCP_PROJECT" \
            "--zone=europe-west2-c" \
            "--ssh-flag=\"-L 9000:localhost:9000\"" \
            "--ssh-flag=\"-L 8084:localhost:8084\"" > connect-to-halyard-host-$1.sh

          echo "---> complete"

          while true; do
              read -p "---> SSH to instance now (y/n)? " yn
              case $yn in
                  [Yy]* )
                    gcloud compute ssh $HALYARD_HOST \
                      --project=$GCP_PROJECT \
                      --zone=europe-west2-c \
                      --ssh-flag="-L 9000:localhost:9000" \
                      --ssh-flag="-L 8084:localhost:8084"
                    echo "---> you can connect later by running:\n" \
                      "sh connect-to-halyard-host-$1.sh"
          		      break;;
                  [Nn]* )
                    echo "---> you can connect later by running:\n" \
                      "sh connect-to-halyard-host-$1.sh"
                    exit;;
                  * ) echo "Please answer yes or no.";;
              esac
          done

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
