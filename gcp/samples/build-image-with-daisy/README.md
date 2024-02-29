# Build image with Daisy

## Deploy environment

```sh
terraform apply
```

## Retrieve installation files

```sh
bucket_name=`terraform output -raw bucket_name`

url_powershell="https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
url_netsdk="https://go.microsoft.com/fwlink/?linkid=2088631"
url_cloudsdk="https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"

# Update with download URL for Windows Server
url_windowsserver=""

if [ ! -d media ]; then
    mkdir media
fi

if [ ! -f media/PowerShell.msi ]; then
    wget -qO media/PowerShell.msi $url_powershell
    gsutil cp media/PowerShell.msi gs://$bucket_name/media/
fi 

if [ ! -f media/dotnet-sdk.exe ]; then
    wget -qO media/dotnet-sdk.exe $url_netsdk
    gsutil cp media/dotnet-sdk.exe gs://$bucket_name/media/
fi 

if [ ! -f media/GoogleCloudSDKInstaller.exe ]; then
    wget -qO media/GoogleCloudSDKInstaller.exe $url_cloudsdk
    gsutil cp media/GoogleCloudSDKInstaller.exe gs://$bucket_name/media/
fi

if [ ! -f media/windows_server.iso ]; then
    if [ ! -z "$url_windowsserver" ]; then
        wget -qO media/windows_server.iso $url_windowsserver
        gsutil cp media/windows_server.iso gs://$bucket_name/media/
    else
        echo "No download URL for Windows Server ISO provided, please download manually and copy to `pwd`/media/windows_server.iso"
    fi
fi

```

## Run build

```sh
project_id=`terraform output -raw project_id`
region=`terraform output -raw region`
zone=`terraform output -raw zone`

gcloud builds submit \
    --project=$project_id \
    --region=$region \
    --no-source \
    --substitutions=_ZONE=$zone
```