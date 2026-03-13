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

## Proxy

### Build

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`

gcloud builds submit proxy/ \
    --project $PROJECT \
    --region $REGION \
    --config proxy/cloudbuild.yaml
```

### Deploy

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export SERVICE_ACCOUNT=`terraform -chdir=../ output -raw service_account`

gcloud run deploy hackathon-controller-proxy \
    --project $PROJECT \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/proxy:latest
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

## All

```shell
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export SERVICE_ACCOUNT=`terraform -chdir=../ output -raw service_account`

gcloud builds submit api/ \
    --project $PROJECT \
    --region $REGION \
    --config api/cloudbuild.yaml \
    --async

gcloud builds submit proxy/ \
    --project $PROJECT \
    --region $REGION \
    --config proxy/cloudbuild.yaml \
    --async

gcloud builds submit ui/ \
    --project $PROJECT \
    --region $REGION \
    --config ui/cloudbuild.yaml \
    --async

gcloud run deploy hackathon-controller-api \
    --project $PROJECT \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/api:latest \
    --async

gcloud run deploy hackathon-controller-proxy \
    --project $PROJECT \
    --region $REGION \
    --service-account $SERVICE_ACCOUNT \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/proxy:latest \
    --async

gcloud run deploy hackathon-controller-ui \
    --project $PROJECT \
    --region $REGION \
    --image us-central1-docker.pkg.dev/$PROJECT/$PROJECT/ui:latest \
    --async
```