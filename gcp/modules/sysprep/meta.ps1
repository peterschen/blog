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
            ConfigurationMode = "ApplyAndAutoCorrect"            
            ActionAfterReboot = "ContinueConfiguration"
            RefreshMode = "Push"
            DebugMode = "All"
            CertificateId = $Thumbprint
        }
    }
}