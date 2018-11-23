[DSCLocalConfigurationManager()]
configuration DscLcm
{
    Node localhost
    {
        Settings
        {
            ConfigurationModeFrequencyMins = 720
        }
    }
}