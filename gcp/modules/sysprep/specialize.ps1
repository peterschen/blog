# Strict mode breaks DSC configuration compilation due to bugs in DSC modules
# Set-StrictMode -Version Latest;
$ErrorActionPreference = "Stop";
$VerbosePreference = "SilentlyContinue";
$DebugPreference = "SilentlyContinue";

$nameHost = '${nameHost}';
$nameConfiguration = '${nameConfiguration}';
$uriMeta = '${uriMeta}';
$uriConfigurations = '${uriConfigurations}';
$password = '${password}';
$passwordSecure = ConvertTo-SecureString -String $password -AsPlainText -Force;
$parametersConfiguration = ConvertFrom-Json -InputObject '${parametersConfiguration}';

# Enable administrator
Set-LocalUser -Name Administrator -Password $passwordSecure;
Enable-LocalUser -Name Administrator;

# Fix issues with downloading from GitHub due to deprecation of TLS 1.0 and 1.1
# https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405#issuecomment-379932793
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 | Out-Null;
New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 | Out-Null;

# Install required PowerShell modules
# Using PowerShellGet in specialize does not work as PSGallery PackageSource can't be registered
$modules = @(
    @{
        Name = "xPSDesiredStateConfiguration"
        Version = "8.10.0.0"
        Uri = "https://github.com/dsccommunity/xPSDesiredStateConfiguration/archive/v8.10.0.zip"
    },
    @{
        Name = "NetworkingDsc"
        Version = "7.4.0.0"
        Uri = "https://github.com/dsccommunity/NetworkingDsc/archive/v7.4.0.zip"
    },
    @{
        Name = "ComputerManagementDsc"
        Version = "8.1.0.0"
        Uri = "https://github.com/dsccommunity/ComputerManagementDsc/archive/v8.1.0.zip"
    }
);

if($parametersConfiguration.modulesDsc -ne $null)
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
    $pathPsModuleStaging = Join-Path -Path $pathPsBase -ChildPath "ModulesStaging";
    $pathPsModule = Join-Path -Path $pathPsBase -ChildPath "Modules\$($module.Name)"

    New-Item -Type Directory -Path $pathPsModule | Out-Null;
    Invoke-WebRequest -Uri $module.Uri -OutFile $pathPsModuleZip;
    Expand-Archive -Path $pathPsModuleZip -DestinationPath $pathPsModuleStaging;
    Rename-Item -Path (Get-Item -Path (Join-Path -Path $pathPsModuleStaging -ChildPath "*")).FullName -NewName $module.Version;
    Move-Item -Path (Join-Path -Path $pathPsModuleStaging -ChildPath $module.Version) -Destination $pathPsModule;
}

# Create certificate to encrypt mof
$pathDscCertificate = (Join-Path -Path $env:TEMP -ChildPath "dsc.cer");
$certificate = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName "DscEncryptionCertificate" -HashAlgorithm SHA256;
Export-Certificate -Cert $certificate -FilePath $pathDscCertificate -Force | Out-Null;

# Download DSC (meta) configuration
$pathDscConfigrationDefinitionMeta = (Join-Path -Path $env:TEMP -ChildPath "meta.ps1");
$pathDscConfigrationDefinition = (Join-Path -Path $env:TEMP -ChildPath "$nameConfiguration.ps1");
Invoke-WebRequest -Uri "$uriMeta/meta.ps1" -OutFile $pathDscConfigrationDefinitionMeta;
Invoke-WebRequest -Uri "$uriConfigurations/$nameConfiguration.ps1" -OutFile $pathDscConfigrationDefinition;

# Source DSC (meta) configuration
. $pathDscConfigrationDefinitionMeta;
. $pathDscConfigrationDefinition;

# Build DSC (meta) configuration
$pathDscConfigurationOutput = Join-Path -Path $env:TEMP -ChildPath "dsc";

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

# Make DSC configuration pending
$pathDscConfigurationPending = Join-Path -Path "C:\Windows\system32\Configuration" -ChildPath "pending.mof";
Move-Item -Path (Join-Path -Path $pathDscConfigurationOutput -ChildPath "$($nameHost).mof") -Destination $pathDscConfigurationPending;

# Enact meta configuration
Set-DscLocalConfigurationManager -Path $pathDscConfigurationOutput -ComputerName "localhost";