# Hackathon controller

## API

### Build

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export COMMIT_SHA=`git show --pretty=format:"%H" --no-patch`

gcloud builds submit api/ \
    --project $PROJECT \
    --region $REGION \
    --config api/cloudbuild.yaml \
    --substitutions COMMIT_SHA=$COMMIT_SHA
```

### Deploy

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export COMMIT_SHA=`git show --pretty=format:"%H" --no-patch`
export DATABASE=`terraform -chdir=../ output -raw database`

gcloud run deploy hackathon-controller-api \
    --project $PROJECT \
    --region $REGION \
    --image gcr.io/$PROJECT/hackathon-controller-api:$COMMIT_SHA \
    --set-env-vars DB_NAME=$DATABASE \
    --allow-unauthenticated
```

## API

### Build

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export COMMIT_SHA=`git show --pretty=format:"%H" --no-patch`

gcloud builds submit ui/ \
    --project $PROJECT \
    --region $REGION \
    --config ui/cloudbuild.yaml \
    --substitutions COMMIT_SHA=$COMMIT_SHA
```

### Deploy

```bash
export PROJECT=`terraform -chdir=../ output -raw project`
export REGION=`terraform -chdir=../ output -raw region`
export COMMIT_SHA=`git show --pretty=format:"%H" --no-patch`
export URI=`gcloud run services describe hackathon-controller-api \
    --project $PROJECT \
    --region $REGION \
    --format "value(status.url)"`

gcloud run deploy hackathon-controller-ui \
    --project $PROJECT \
    --region $REGION \
    --image gcr.io/$PROJECT/hackathon-controller-ui:$COMMIT_SHA \
    --set-env-vars API_URI=$URI \
    --allow-unauthenticated
```