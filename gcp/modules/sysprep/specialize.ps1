Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";
$VerbosePreference = "SilentlyContinue";
$DebugPreference = "SilentlyContinue";

$nameHost = '${nameHost}';
$password = '${password}';
$passwordSecure = ConvertTo-SecureString -String $password -AsPlainText -Force;
$parametersConfiguration = ConvertFrom-Json -InputObject '${parametersConfiguration}';
$pathTemp = "$($env:SystemDrive)\Windows\Temp";

$inlineMeta = $parametersConfiguration.inlineMeta;
$inlineConfiguration = $parametersConfiguration.inlineConfiguration;

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
        Version = "6.0.1"
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

# Download DSC (meta) configuration
$pathDscMetaDefinition = (Join-Path -Path $pathTemp -ChildPath "meta.ps1");
$pathDscConfigurationDefinition = (Join-Path -Path $pathTemp -ChildPath "configuration.ps1");

if(-not [string]::IsNullOrEmpty($inlineMeta))
{
    # Only write inlineMeta if file does not exist on disk
    if(-not (Test-Path -Path $pathDscMetaDefinition))
    {
        [IO.File]::WriteAllBytes($pathDscMetaDefinition, [Convert]::FromBase64String($inlineMeta));
    }
}
else
{
    throw [System.ArgumentException]::New("inlineMeta data is missing"); 
}

if(-not [string]::IsNullOrEmpty($inlineConfiguration))
{
    # Only write inlineConfiguration if file does not exist on disk
    if(-not (Test-Path -Path $pathDscConfigurationDefinition))
    {
        [IO.File]::WriteAllBytes($pathDscConfigurationDefinition, [Convert]::FromBase64String($inlineConfiguration));
    }
}
else
{
    throw [System.ArgumentException]::New("inlineConfiguration data is missing"); 
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

# Make DSC configuration pending
$pathDscConfigurationPending = Join-Path -Path "C:\Windows\system32\Configuration" -ChildPath "pending.mof";
Move-Item -Path (Join-Path -Path $pathDscConfigurationOutput -ChildPath "$($nameHost).mof") -Destination $pathDscConfigurationPending;
