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

# Inline configuration passed through parametersConfiguration
# to not break configurations with dependency on sysprep
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
        Version = "8.10.0"
        Uri = "https://github.com/dsccommunity/xPSDesiredStateConfiguration/archive/v8.10.0.zip"
    },
    @{
        Name = "NetworkingDsc"
        Version = "7.4.0"
        Uri = "https://github.com/dsccommunity/NetworkingDsc/archive/v7.4.0.zip"
    },
    @{
        Name = "ComputerManagementDsc"
        Version = "8.1.0"
        Uri = "https://github.com/dsccommunity/ComputerManagementDsc/archive/v8.1.0.zip"
    },
    @{
        Name = "ActiveDirectoryDsc"
        Version = "6.0.0"
        Uri = "https://github.com/dsccommunity/ActiveDirectoryDsc/archive/v6.0.0.zip"
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
    $pathPsModule = Join-Path -Path $pathPsBase -ChildPath "Modules\$($module.Name)";

    if(-not (Test-Path -Path $pathPsModule))
    {
        New-Item -Type Directory -Path $pathPsModule | Out-Null;
        Invoke-WebRequest -Uri $module.Uri -OutFile $pathPsModuleZip;
        Expand-Archive -Path $pathPsModuleZip -DestinationPath $pathPsModuleStaging;

        $pathPsModuleStaging = Join-Path -Path $pathPsModuleStaging -ChildPath "$($module.Name)-$($module.Version)";
        $pathPsModuleSource = Join-Path -Path $pathPsModuleStaging -ChildPath "source";

        # Check if expanded path contains a source/ directory
        # Newer versions of DSC modules tend to move to that
        if(Test-Path -Path $pathPsModuleSource)
        {
            $pathPsModuleStaging = $pathPsModuleSource;
        }

        # For whatever reason source release do not carry the correct module version in .psd1
        $pathPsModulePsd1 = Join-Path -Path $pathPsModuleStaging -ChildPath "$($module.Name).psd1";
        (Get-Content -Path $pathPsModulePsd1 -Raw) -replace "moduleVersion(.*)=(.*)'(.*)'", "moduleVersion = '$($module.Version)'" | Set-Content -Path $pathPsModulePsd1;
    
        Move-Item -Path $pathPsModuleStaging -Destination (Join-Path -Path $pathPsModule -ChildPath $module.Version);
    }
}

# Create certificate to encrypt mof
$pathDscCertificate = (Join-Path -Path $env:TEMP -ChildPath "dsc.cer");
$certificate = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName "DscEncryptionCertificate" -HashAlgorithm SHA256;
Export-Certificate -Cert $certificate -FilePath $pathDscCertificate -Force | Out-Null;

# Download DSC (meta) configuration
$pathDscConfigurationDefinitionMeta = (Join-Path -Path $env:TEMP -ChildPath "meta.ps1");
$pathDscConfigurationDefinition = (Join-Path -Path $env:TEMP -ChildPath "$nameConfiguration.ps1");
Invoke-WebRequest -Uri "$uriMeta/meta.ps1" -OutFile $pathDscConfigurationDefinitionMeta;
if([string]::IsNullOrEmpty($inlineConfiguration))
{
    Invoke-WebRequest -Uri "$uriConfigurations/$nameConfiguration.ps1" -OutFile $pathDscConfigurationDefinition;
}
else
{
    [IO.File]::WriteAllBytes($pathDscConfigurationDefinition, [Convert]::FromBase64String($inlineConfiguration));
}

# Source DSC (meta) configuration
. $pathDscConfigurationDefinitionMeta;
. $pathDscConfigurationDefinition;

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
