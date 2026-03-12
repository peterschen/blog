# Hackathon controller

## API

### Build

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`

gcloud builds submit api/ \
    --project $PROJECT \
    --region $REGION \
    --config api/cloudbuild.yaml
```

### Deploy

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export SERVICE_ACCOUNT=`terraform -chdir=../ output -raw service_account`

gcloud run deploy hackathon-controller-api \
    --project $PROJECT \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/api:latest
```

## UI

### Build

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`

gcloud builds submit ui/ \
    --project $PROJECT \
    --region $REGION \
    --config ui/cloudbuild.yaml
```

### Deploy

```bash
gcloud run deploy hackathon-controller-ui \
    --project $PROJECT \
    --region $REGION \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/ui:latest
```

```shell
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export SERVICE_ACCOUNT=`terraform -chdir=../ output -raw service_account`

gcloud builds submit api/ \
    --project $PROJECT \
    --region $REGION \
    --config api/cloudbuild.yaml \
    --async

gcloud builds submit ui/ \
    --project $PROJECT \
    --region $REGION \
    --config ui/cloudbuild.yaml

gcloud run deploy hackathon-controller-api \
    --project $PROJECT \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/api:latest

gcloud run deploy hackathon-controller-ui \
    --project $PROJECT \
    --region $REGION \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/ui:latest
```