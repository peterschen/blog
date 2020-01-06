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

# Enable WinRM
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Enabled True -Protocol "tcp" -LocalPort 5985 | Out-Null;
winrm set winrm/config/service/Auth '@{Basic="true"}' | Out-Null;
winrm set winrm/config/service '@{AllowUnencrypted="true"}' | Out-Null;
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}' | Out-Null;

# Fix issues with downloading from GitHub due to deprecation of TLS 1.0 and 1.1
# https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405#issuecomment-379932793
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 | Out-Null;
New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 | Out-Null;

# Install required PowerShell modules
# Using PowerShellGet in specialize does not work as PSGallery PackageSource can't be registered
$modules = @(
    @{
        Name = "ActiveDirectoryDsc"
        Version = "4.2.0.0"
        Uri = "https://github.com/dsccommunity/ActiveDirectoryDsc/archive/4.2.0.0.zip"
    },
    @{
        Name = "xPSDesiredStateConfiguration"
        Version = "8.10.0.0"
        Uri = "https://github.com/dsccommunity/xPSDesiredStateConfiguration/archive/8.10.0.0.zip"
    },
    @{
        Name = "NetworkingDsc"
        Version = "7.4.0.0"
        Uri = "https://github.com/dsccommunity/NetworkingDsc/archive/7.4.0.0.zip"
    },
    @{
        Name = "ComputerManagementDsc"
        Version = "6.4.0.0"
        Uri = "https://github.com/dsccommunity/ComputerManagementDsc/archive/6.4.0.0-PSGallery.zip"
    },
    @{
        Name = "xDnsServer"
        Version = "1.13.0.0"
        Uri = "https://github.com/dsccommunity/xDnsServer/archive/1.13.0.0-PSGallery.zip"
    },
    @{
        Name = "xFailOverCluster"
        Version = "1.12.0.0"
        Uri = "https://github.com/dsccommunity/xFailOverCluster/archive/1.12.0.0-PSGallery.zip"
    }
);

$pathPsBase = "C:\Program Files\WindowsPowerShell";
foreach($module in $modules)
{
    $pathPsModuleZip = Join-Path -Path $pathPsBase -ChildPath "$($module.Name).zip";
    $pathPsModuleStaging = Join-Path -Path $pathPsBase -ChildPath "ModulesStaging";
    $pathPsModule = Join-Path -Path $pathPsBase -ChildPath "Modules\$($module.Name)"

    New-Item -Type Directory -Path $pathPsModule | Out-Null;
    Invoke-WebRequest -Uri $module.Uri -OutFile $pathPsModuleZip;
    Expand-Archive -Path $pathPsModuleZip -DestinationPath $pathPsModuleStaging;
    Rename-Item -Path (Get-Item -Path (Join-Path -Path $pathPsModuleStaging -ChildPath "*-PSGallery")).FullName -NewName $module.Version;
    Move-Item -Path (Join-Path -Path $pathPsModuleStaging -ChildPath $module.Version) -Destination $pathPsModule;
}

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
    -OutputPath $pathDscConfigurationOutput | Out-Null;

ConfigurationWorkload `
    -ComputerName $nameHost `
    -Password $passwordSecure `
    -Parameters $parametersConfiguration `
    -ConfigurationData @{AllNodes = @(@{NodeName = "$nameHost"; PSDscAllowPlainTextPassword = $true; PSDscAllowDomainUser = $true})} `
    -OutputPath $pathDscConfigurationOutput | Out-Null;

# Make DSC configuration pending
$pathDscConfigurationPending = Join-Path -Path "C:\Windows\system32\Configuration" -ChildPath "pending.mof";
Move-Item -Path (Join-Path -Path $pathDscConfigurationOutput -ChildPath "$($nameHost).mof") -Destination $pathDscConfigurationPending;

# Enact meta configuration
Set-DscLocalConfigurationManager -Path $pathDscConfigurationOutput -ComputerName "localhost";