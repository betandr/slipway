#!/usr/bin/env bash

# This script is based on https://www.spinnaker.io/setup/quickstart/halyard-gke/
# author: Beth Anderson (github.com/betandr)

if test "$#" -ne 2; then
    echo "Usage: sh 02_spin_up.sh $INDEX $CLUSTER_NAME\n\n" \
      "Also requires the following environment variables to be set (examples) :\n" \
      " - DOMAIN=example.com\n" \
      " - CLIENT_ID=00000000000-a0a0a0a0a0a0a0a0a0a0a00a0a0.apps.googleusercontent.com\n" \
      " - CLIENT_SECRET=A0A0A0A0A0A0A0A0A0A0-A0\n" \
      " - BOTNAME=slackbot\n" \
      " - REDIRECT_URL=http://spinnaker-api.example.com/login"
    exit 1
fi

echo "\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n" \
":: Warning: This script will provision infrastructure in the cloud and   ::\n" \
":: could therefore cost money. Please be sure that you do want to        ::\n" \
":: proceed and you understand the implications!                          ::\n" \
":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"

echo "PLEASE CHECK THESE SETTINGS BEFORE CONTINUING!"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"
echo "Spinnaker Cluster: spinnaker-cluster-$1"
echo "Production Cluster: $2-cluster-$1"
echo "Cluster Zone: $CLUSTER_ZONE"
echo "Oauth2 Domain: $OAUTH2_DOMAIN"
echo "Oauth 2 Client ID: $OAUTH2_CLIENT_ID"
echo "Oauth 2 Client Secret: $OAUTH2_CLIENT_SECRET"
echo "Oauth 2 Redirect URL: $OAUTH2_REDIRECT_URL"
echo "Slackbot Name: $BOTNAME"
echo "\n............. container registry repos in repos.txt ............."
if [ -f repos.txt ]
then
  cat repos.txt
else
	echo "repos.txt does not exist\n"
fi
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\n"

GCP_PROJECT=$(gcloud info --format='value(config.project)')

while true; do
    read -p "Provision Spinnaker in \`$GCP_PROJECT\` project (y/n)? " yn
    case $yn in
        [Yy]* )

          echo "---> install kubectl..."
          KUBECTL_LATEST=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
          curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_LATEST/bin/linux/amd64/kubectl
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/kubectl

          echo "---> install halyard..."
          curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh
          sudo bash InstallHalyard.sh
          . ~/.bashrc

          echo "---> get credentials..."
          gcloud config set container/use_client_certificate true

          gcloud container clusters get-credentials spinnaker-cluster-$1 \
              --zone=$CLUSTER_ZONE

          gcloud container clusters get-credentials $CLUSTER_NAME-cluster-$1 \
              --zone=$CLUSTER_ZONE

          echo "---> create service accounts..."
          GCS_SPIN_SA=gcs-spin-service-account-$1
          GCS_PROD_SA=gcs-prod-service-account-$1

          GCS_SPIN_SA_DEST=~/.gcp/gcp-spin.json
          GCS_PROD_SA_DEST=~/.gcp/gcp-prod.json

          mkdir -p $(dirname $GCS_SPIN_SA_DEST)
          mkdir -p $(dirname $GCS_PROD_SA_DEST)

          GCS_SPIN_SA_EMAIL=$(gcloud iam service-accounts list \
              --filter="displayName:$GCS_SPIN_SA" \
              --format='value(email)')

          GCS_PROD_SA_EMAIL=$(gcloud iam service-accounts list \
            --filter="displayName:$GCS_PROD_SA" \
              --format='value(email)')

          gcloud iam service-accounts keys create $GCS_SPIN_SA_DEST \
            --iam-account $GCS_SPIN_SA_EMAIL

          gcloud iam service-accounts keys create $GCS_PROD_SA_DEST \
            --iam-account $GCS_PROD_SA_EMAIL

          echo "---> set Halyard version..."
          hal config version edit --version $(hal version latest -q)

          echo "---> configure GCS persistence..."
          hal config storage gcs edit \
              --project $GCP_PROJECT \
              --json-path ~/.gcp/gcp-spin.json

          hal config storage edit --type gcs

          echo "---> configure pulling from GCR..."
          hal config provider docker-registry enable

          hal config provider docker-registry account add spinnaker-gcr-account-$1 \
              --address gcr.io \
              --password-file ~/.gcp/gcp-spin.json \
              --username _json_key

          hal config provider docker-registry account add production-gcr-account-$1 \
              --address gcr.io \
              --password-file ~/.gcp/gcp-spin.json \
              --username _json_key

          hal config provider kubernetes enable

          hal config provider kubernetes account add spinnaker-k8s-account-$1 \
              --docker-registries spinnaker-gcr-account-$1 \
              --context $(kubectl config current-context)

          hal config provider kubernetes account add production-k8s-account-$1 \
              --docker-registries production-gcr-account-$1 \
              --context $(kubectl config current-context)

          echo "---> adding repos..."
          if [ -f repos.txt ]
          then
            while read repo; do
              if [ ! -z "$repo" ]
              then
                echo "Adding "$repo" container repository to Spinnaker account".

                hal config provider docker-registry account edit spinnaker-gcr-account-$INDEX \
                  --add-repository $repo
              fi

            done <repos.txt
          else
            echo "No repos found.".
          fi

          if [ ! -z "$BOTNAME" ]
          then
            echo "---> configuring slack...obtain a slackbot token from https://$YOUR_WORKSPACE.slack.com/apps/manage/custom-integrations"
            hal config notification slack enable
            hal config notification slack edit --bot-name $BOTNAME --token
          else
            echo "---> no slack botname found..."
          fi

          hal config deploy edit \
            --account-name spinnaker-k8s-account-$1 \
            --type distributed

          hal config deploy edit \
            --account-name production-k8s-account-$1 \
            --type distributed

          if [ ! -z "$OAUTH2_CLIENT_ID" ]
          then
            echo "---> configuring oauth2..."

            hal config security ui edit \
              --override-base-url $OVERRIDE_UI_URL
            hal config security api edit \
              --override-base-url $OVERRIDE_API_URL

            hal config security authn oauth2 edit \
              --provider google \
              --client-id $OAUTH2_CLIENT_ID \
              --client-secret $OAUTH2_CLIENT_SECRET \
              --user-info-requirements hd=$OAUTH2_DOMAIN \
              --pre-established-redirect-uri $OAUTH2_REDIRECT_URL

            hal config security authn oauth2 enable
          else
            echo "---> no oauth client id found..."
          fi

          echo "---> deploying spinnaker..."
          hal deploy apply

          if [ ! -z "$OVERRIDE_UI_URL" ]
          then
            echo "---> 3 changes to be made to spin deck:"
            echo "- change \`port:\` to \`80\`"
            echo "- change \`type:\` to \`LoadBalancer\`"
            echo "- add \`loadBalancerIP:\`"
            read -n 1 -s -r -p "---> press any key to continue"
            kubectl edit svc spin-deck -n spinnaker

            echo ""

            echo "---> 3 changes to be made to spin gate:"
            echo "- change \`port:\` to \`80\`"
            echo "- change \`type:\` to \`LoadBalancer\`"
            echo "- add \`loadBalancerIP:\` to be the following address:"
            read -n 1 -s -r -p "---> press any key to continue"
            kubectl edit svc spin-gate -n spinnaker

            echo "---> action:"
            echo "---> update domain record target for $OVERRIDE_UI_URL and $OVERRIDE_API_URL with new addresses..."
          else
            echo "---> no override ui url found..."
          fi

      		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done