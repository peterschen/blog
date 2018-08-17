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
                New-EventLog -LogName Application -Source "DSC/LA Inventory" -ErrorAction SilentlyContinue;
                $data = Get-Content -Path "C:\inventory.json" -Raw;
                Write-EventLog -LogName Application -Source "DSC/LA Inventory" -EntryType Information -EventId 12345 -Category 0 -Message $data;
            }
            TestScript = {
                return $false;
            }
        }
    }
}