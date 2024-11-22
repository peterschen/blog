Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";
$VerbosePreference = "SilentlyContinue";
$DebugPreference = "SilentlyContinue";

$nameHost = '${nameHost}';
$password = '${password}';
$passwordSecure = ConvertTo-SecureString -String $password -AsPlainText -Force;
$parametersConfiguration = ConvertFrom-Json -InputObject '${parametersConfiguration}';
$pathTemp = "$($env:SystemDrive)\Windows\Temp";

# Enable administrator
Set-LocalUser -Name Administrator -Password $passwordSecure;
Enable-LocalUser -Name Administrator;

# Fix issues with downloading from GitHub due to deprecation of TLS 1.0 and 1.1
# https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405#issuecomment-379932793
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 -Force | Out-Null;
New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 -Force | Out-Null;

# Install required PowerShell modules
# Using PowerShellGet in specialize does not work as PSGallery PackageSource can't be registered
$modules = @(
    @{
        Name = "xPSDesiredStateConfiguration"
        Version = "9.1.0"
    },
    @{
        Name = "NetworkingDsc"
        Version = "8.2.0"
    },
    @{
        Name = "ComputerManagementDsc"
        Version = "8.4.0"
    },
    @{
        Name = "ActiveDirectoryDsc"
        Version = "6.2.0"
    },
    @{
        Name = "xCredSSP"
        Version = "1.4.0"
    }
);

if([bool]$parametersConfiguration.PSObject.Properties["modulesDsc"])
{
    foreach($module in $parametersConfiguration.modulesDsc)
    {
        $modules += $module;
    }
}

$pathPsBase = "C:\Program Files\WindowsPowerShell";
foreach($module in $modules)
{
    $pathPsModuleZip = Join-Path -Path $pathPsBase -ChildPath "$($module.Name).zip";
    $pathPsModuleStaging = Join-Path -Path $pathPsBase -ChildPath "ModulesStaging\$($module.Name)-$($module.Version)";
    $pathPsModule = Join-Path -Path $pathPsBase -ChildPath "Modules\$($module.Name)";

    if(-not (Test-Path -Path $pathPsModule))
    {
        New-Item -Type Directory -Path $pathPsModule | Out-Null;
        Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/$($module.Name)/$($module.Version)" -OutFile $pathPsModuleZip;
        Expand-Archive -Path $pathPsModuleZip -DestinationPath $pathPsModuleStaging;
        
        # Cleanup nupkg files
        $files = @(
            "[Content_Types].xml",
            "*.nuspec",
            "_rels"
        );

        foreach($file in $files)
        {
            $pathDeletion = Join-Path -Path $pathPsModuleStaging -ChildPath $file;
            if(Test-Path -Path $pathDeletion)
            {
                Remove-Item -Path $pathDeletion -Recurse;
            }
        }

        Move-Item -Path $pathPsModuleStaging -Destination (Join-Path -Path $pathPsModule -ChildPath $module.Version);
    }
}

# Create certificate to encrypt mof
$pathDscCertificate = (Join-Path -Path $pathTemp -ChildPath "dsc.cer");
if(-not (Test-Path -Path $pathDscCertificate))
{
    $certificate = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName "DscEncryptionCertificate" -HashAlgorithm SHA256;
    Export-Certificate -Cert $certificate -FilePath $pathDscCertificate -Force | Out-Null;
}
else
{
    $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=DscEncryptionCertificate"};
}

$pathDscMetaDefinition = (Join-Path -Path $pathTemp -ChildPath "meta.ps1");
$pathDscConfigurationDefinition = (Join-Path -Path $pathTemp -ChildPath "configuration.ps1");

$inlineMeta = $parametersConfiguration.inlineMeta;
$inlineConfiguration = $parametersConfiguration.inlineConfiguration;

# Only write inlineMeta if file does not exist on disk
if(-not (Test-Path -Path $pathDscMetaDefinition))
{
    [IO.File]::WriteAllBytes($pathDscMetaDefinition, [Convert]::FromBase64String($inlineMeta));
}

# Customization is optional
$inlineConfigurationCustomization = $null;
if("inlineConfigurationCustomization" -in $parametersConfiguration.PSObject.Properties.Name)
{
    $inlineConfigurationCustomization = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parametersConfiguration.inlineConfigurationCustomization));
}

# Only write inlineConfiguration if file does not exist on disk
if(-not (Test-Path -Path $pathDscConfigurationDefinition))
{
    $content = "";

    if(-not [string]::IsNullOrEmpty($inlineConfigurationCustomization))
    {
        # Customization is present write first
        $content = $inlineConfigurationCustomization;
    }
    else
    {
        # Set empty customization if not present
        $content = @'
Configuration Customization {
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Parameters
    ); 
}
'@;
    }

    $content += "`n`n$([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($inlineConfiguration)))";
    Set-Content -Path $pathDscConfigurationDefinition -Value $content;
}

# Create specialize.ps1 for local execution if it doesn't exists
$pathSpecializeScript = Join-Path -Path $pathTemp -ChildPath "specialize.ps1";
if(-not (Test-Path -Path $pathSpecializeScript))
{
    $specializeScript = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} `
        -Uri "http://metadata.google.internal/computeMetadata/v1/instance/attributes/sysprep-specialize-script-ps1";
    Set-Content -Path $pathSpecializeScript -Value $specializeScript;
}

# Source DSC (meta) configuration
. $pathDscMetaDefinition;
. $pathDscConfigurationDefinition;

# Build DSC (meta) configuration
$pathDscConfigurationOutput = Join-Path -Path $pathTemp -ChildPath "dsc";

ConfigurationMeta `
    -ComputerName "localhost" `
    -Thumbprint $certificate.Thumbprint `
    -OutputPath $pathDscConfigurationOutput | Out-Null;

ConfigurationWorkload `
    -ComputerName $nameHost `
    -Password $passwordSecure `
    -Parameters $parametersConfiguration `
    -ConfigurationData @{AllNodes = @(@{NodeName = "$nameHost"; PSDscAllowDomainUser = $true; CertificateFile = $pathDscCertificate; Thumbprint = $certificate.Thumbprint})} `
    -OutputPath $pathDscConfigurationOutput | Out-Null;
    
# Enact meta configuration
Set-DscLocalConfigurationManager -Path $pathDscConfigurationOutput -ComputerName "localhost";

# Make DSC configuration pending to execute on next LCM cycle
$pathDscConfigurationPending = Join-Path -Path "C:\Windows\system32\Configuration" -ChildPath "pending.mof";
Move-Item -Path (Join-Path -Path $pathDscConfigurationOutput -ChildPath "$($nameHost).mof") -Destination $pathDscConfigurationPending;

# Enact DSC configuration for debugging/testing purposes
# Start-DscConfiguration -Path $pathDscConfigurationOutput -Wait -Force -ErrorAction Stop;
