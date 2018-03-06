# Slipway: Automated Halyard and Spinnaker provisioning

This script automates one use-case only; provisioning
[Spinnaker](https://www.spinnaker.io/) on a Kubernetes cluster, controlled by
an Ubuntu host VM running
[Halyard](https://www.spinnaker.io/reference/halyard/). If this exact
configuration is not what you want then the
[Spinnaker Setup docs](https://www.spinnaker.io/setup/) might be a good starting
point.

## 1. Preamble
Install [gcloud](https://cloud.google.com/sdk/downloads) SDK

## 2. Provision Halyard Host VM

### Configure gcloud
```
gcloud auth login
```
```
gcloud config set project $your_project_name
```

### Get the Halyard host provisioning script
```
curl -O  https://raw.githubusercontent.com/betandr/slipway/master/01_hal_up.sh
```

### Run Halyard host provisioning script
```
# Change 001 to another label if you already have a halyard-host-001
sh 01_hal_up.sh 001
```

_*Important: All further scripts are run from the Halyard Host VM!*_

## 3. Install Halyard (from Halyard host VM!)

## Configure and Deploy Spinnaker



## Notes
 Decom: Host VM, persistent disk (goes with VM),
 gcs-service-account-INDEX@PROJECT.iam.gserviceaccount.com,
 halyard-service-account-INDEX@PROJECT.iam.gserviceaccount.com
