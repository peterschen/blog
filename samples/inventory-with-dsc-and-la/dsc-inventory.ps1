configuration DscInventory
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration;

    Node "localhost"
    {
        Script "Inventory2EventLog"
        {
            GetScript = {
                return @{ Result = $true }
            }
            SetScript = {
                $source = "DSC/LA Inventory";

                if(-not [System.Diagnostics.EventLog]::SourceExists($source))
                {
                    New-EventLog -LogName Application -Source "DSC/LA Inventory";
                }

                $data = Get-Content -Path "C:\inventory.json" -Raw;
                Write-EventLog -LogName Application -Source $source -EntryType Information -EventId 12345 -Category 0 -Message $data;
            }
            TestScript = {
                return $false;
            }
        }
    }
}