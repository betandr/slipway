# Slipway: Automated Halyard and Spinnaker provisioning

Slipway automates _one use-case only_: provisioning
[Spinnaker](https://www.spinnaker.io/) on a Kubernetes cluster, controlled by
an Ubuntu host VM running
[Halyard](https://www.spinnaker.io/reference/halyard/) on Google Cloud Platform
based on
[Halyard on GKE Quickstart](https://www.spinnaker.io/setup/quickstart/halyard-gke/)
guide.

![Slipway](http://bet.andr.io/images/slipway.jpg)

Slipway also sets up Spinnaker to be publicly accessible with Oauth2
authentication and sets up some container registry repositories and a Slackbot.
If this exact configuration is not what you want then the
[Spinnaker Setup docs](https://www.spinnaker.io/setup/) might be a good starting
point.

These scripts make a lot of decisions which might not fit your use-case. YMMV.

## 0. Preamble
[Install the gcloud SDK](https://cloud.google.com/sdk/downloads) then configure:
```
gcloud auth login
```

```
gcloud projects list
```

```
gcloud config set project $PROJECT_NAME
```
...where `$PROJECT_NAME` is the project you wish to provision infrastructure in.

## 1. Provision Kubernetes cluster

### Get the Kubernetes provisioning script
```
curl -O  https://raw.githubusercontent.com/betandr/slipway/master/01_kube_up.sh
```

### Run Kubernetes provisioning script
```
sh 01_kube_up.sh $INDEX $CLUSTER_NAME $IP_REGION $CLUSTER_ZONE
```
...where `$INDEX` is your index, such as `001`, `$CLUSTER_NAME` is your cluster
name such as `foobarbaz`, `$IP_REGION` is the region in which the external IPs
for the Spinnaker external endpoints will be provisioned such as `europe-west2`,
and `$CLUSTER_ZONE` is the zone you wish to provision in, such as
`europe-west2-c`.

For these example values the following cluster will be provisioned:
- foobarbaz-cluster-001: 6 Nodes of 2 vCPUs in Zone europe-west2-c

The script will also reserve two IP addresses `spinnaker-$INDEX` and
`spinnaker-api-$INDEX` which you should note for the
[Run Spinnaker provisioning script](#run-spinnaker-provisioning-script) step later.

## 2. Provision Halyard Host VM

### Get the Halyard host provisioning script
```
curl -O  https://raw.githubusercontent.com/betandr/slipway/master/02_hal_up.sh
```

### Run Halyard host provisioning script
```
sh 02_hal_up.sh $INDEX
```

This script will ask you if you want to connect to the provisioned instance but
also creates a shell script which can be used to connect to that instance later
on.

To connect, run:
```
sh connect-to-halyard-host-$INDEX.sh
```
...where `$INDEX` matches your instance.

_IMPORTANT: ALL FURTHER SCRIPTS ARE RUN FROM THE HALYARD HOST VM!_

## 3. Provision Kubernetes Spinnaker and production clusters (from Halyard host VM):

### Set up gcloud on Halyard VM

```
gcloud auth login
```

```
gcloud projects list
```

```
gcloud config set project $PROJECT_NAME
```
...where `$PROJECT_NAME` is the project you wish to provision infrastructure in.

### Set up a DNS record for Spinnaker UI and Spinnaker API
Follow the [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/))
instructions to reserve two IP addresses then create DNS records for the
Spinnaker API and UI load-balancers. The DNS records become `OVERRIDE_API_URL`
and `OVERRIDE_UI_URL` and the IPs are used to configure Kubernetes in the
[Run Spinnaker provisioning script](#run-spinnaker-provisioning-script) step.

### Get the Spinnaker provisioning script
```
curl -O  https://raw.githubusercontent.com/betandr/slipway/master/03_spin_up.sh
```

### Set the environment variables:
| Name | Description | Example |
|------|--------|---------|
| `IP_REGION` | The region for the Spinnaker external IPs | `europe-west2` |
| `CLUSTER_ZONE` | Your cluster zone | `europe-west2-c` |
| `OAUTH2_DOMAIN` | Used to restrict Oauth2 logins to a domain | `example.com` |
| `OAUTH2_CLIENT_ID` | _(Optional — if not used; no Oauth2)_ Oauth2 Client ID (see [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/)) | `00000000000-a0a0a0a0a0a0a0a0a0a0a00a0a0.apps.googleusercontent.com` |
| `OAUTH2_CLIENT_SECRET` | Oauth2 Client Secret (see [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/)) | `A0A0A0A0A0A0A0A0A0A0-A0` |
| `OAUTH2_REDIRECT_URL` | Oauth2 redirect URL (see [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/)) | `http://spinnaker-api.example.com/login` |
| `BOTNAME` | _(Optional — if not used; no Slack)_ The Slackbot name (set up in Slackbot). You will be prompted for the token. (see [Slack: Bot Users](https://api.slack.com/bot-users#how_do_i_create_custom_bot_users_for_my_team)) | `slackbot` |
| `OVERRIDE_API_URL` | Public Spinnaker API endpoint (see [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/)) | `http://spinnaker-api.example.com` |
| `OVERRIDE_UI_URL` | Public Spinnaker UI endpoint (see [Public Spinnaker on GKE](https://www.spinnaker.io/setup/quickstart/halyard-gke-public/)) |`http://spinnaker.example.com` |
| `SPIN_GATE_IP` | The spin-gate reserved IP from the [Run Kubernetes provisioning script](#run-kubernetes-provisioning-script) step | `35.45.25.15` |
| `SPIN_DECK_IP` | The spin-deck reserved IP from the [Run Kubernetes provisioning script](#run-kubernetes-provisioning-script) step | `35.45.25.15` |

One method to do this is to have a local `secrets` file, containing something like:
```
export INDEX=000
export CLUSTER_NAME=hello-world
export IP_REGION=europe-west2
export CLUSTER_ZONE=europe-west2-c
export OAUTH2_DOMAIN=example.com
...etc...
```
...then load these using:
```
source secrets
```

### Add your repos:
To ensure Spinnaker is set up with all the repos it needs, you should create a
file called `repos.txt` and inside have repositories such as:
```
project1/container-a
project2/container-b
```

### Run Spinnaker provisioning script
```
sh 03_spin_up.sh $INDEX $CLUSTER_NAME
```
...where `$INDEX` and `$CLUSTER_NAME` match the values specified in
[Run Kubernetes provisioning script](#run-kubernetes-provisioning-script) in the
[1. Provision Kubernetes clusters](#1-provision-kubernetes-clusters) section.

#### Enter reserved external addresses

To enable external access to Spinnaker the Kubernetes service config will be
updated. You will be prompted for the `spinnaker-$INDEX` and the
`spinnaker-api-$INDEX` addresses from the
[1. Provision Kubernetes clusters](#1-provision-kubernetes-clusters) step.

## Decommissioning
This is not yet automated as it could potentially be dangerous, but things to
clear up for the clusters and VM host are:
- Compute Engine: Halyard Host VM: `halyard-host-$INDEX` + Persistent Disk
- Kubernetes Engine: `$CLUSTER_NAME-cluster-$INDEX`
- Service Account: `halyard-service-account-$INDEX@$PROJECT.iam.gserviceaccount.com`
- Service Account: `gcs-spin-service-account-$INDEX@$PROJECT.iam.gserviceaccount.com`
- IAM Permissions: `gcs-spin-service-account-$INDEX@$PROJECT.iam.gserviceaccount.com`
- IAM Permissions: `halyard-service-account-$INDEX@$PROJECT.iam.gserviceaccount.com`
- VPC Network: `spinnaker-$INDEX` reserved external IP
- VPC Network: `spinnaker-api-$INDEX` reserved external IP
- VPC Network: target pools, forwarding rules

## TODO
- Check quota before provisioning
- Check permissions before provisioning
- Get the reserved external IPs automatically via `gcloud compute addresses list`.
