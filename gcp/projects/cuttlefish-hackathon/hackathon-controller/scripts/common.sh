create_claim()
{
    SERVICE_ACCOUNT=$1
    API_URI=$2

    cat > claim.json << EOM
{
    "iss": "$SERVICE_ACCOUNT",
    "sub": "$SERVICE_ACCOUNT",
    "aud": "$API_URI",
    "iat": $(date +%s),
    "exp": $((`date +%s` + 3600))
}
EOM
}

sign_jwt()
{
    SERVICE_ACCOUNT=$1
    API_URI=$2

    create_claim $SERVICE_ACCOUNT $API_URI
    gcloud iam service-accounts sign-jwt --iam-account $SERVICE_ACCOUNT claim.json signed.jwt

    if [ ! -f signed.jwt ]; then
        exit 1
    fi

    TOKEN=$(cat signed.jwt)
    rm claim.json signed.jwt
    echo "$TOKEN"
}