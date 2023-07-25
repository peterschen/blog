[DSCLocalConfigurationManager()]
configuration ConfigurationMeta
{
    param
    (
        [ValidateNotNullOrEmpty()] 
        [string] $ComputerName,

        [ValidateNotNullOrEmpty()] 
        [string] $Thumbprint
    );

    Node $ComputerName
    {
        Settings
        {
            ConfigurationModeFrequencyMins = 15 
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndMonitor"            
            ActionAfterReboot = "ContinueConfiguration"
            RefreshMode = "Push"
            DebugMode = "All"
            CertificateId = $Thumbprint
        }
    }
}