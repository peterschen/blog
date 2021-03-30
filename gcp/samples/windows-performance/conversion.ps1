[CmdletBinding()]
param
(
    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [Array] $Results,
    [string] $Sku = "Performance",
    [int] $Size = 1000
);

process
{
    Set-StrictMode -Version Latest;
    $InformationPreference = "Continue";
    $ErrorActionPreference = "Stop";

    $records = @();
    foreach($result in $Results)
    {
        $record = New-Object psobject;
        $record | Add-Member -MemberType NoteProperty -Name "SKU" -Value $Sku;
        $record | Add-Member -MemberType NoteProperty -Name "Scenario" -Value $result.Scenario;
        $record | Add-Member -MemberType NoteProperty -Name "Size" -Value $Size;
        $record | Add-Member -MemberType NoteProperty -Name "WriteRatio" -Value $result.WriteRatio;
        $record | Add-Member -MemberType NoteProperty -Name "ReadRatio" -Value (100 - $result.WriteRatio);
        $record | Add-Member -MemberType NoteProperty -Name "Duration" -Value $result.DurationSeconds;
        $record | Add-Member -MemberType NoteProperty -Name "Threads" -Value $result.ThreadCount;
        $record | Add-Member -MemberType NoteProperty -Name "QueueDepth" -Value $result.RequestCount;
        $record | Add-Member -MemberType NoteProperty -Name "FileSystem" -Value $result.FileSystem;
        $record | Add-Member -MemberType NoteProperty -Name "AllocationUnitSize" -Value $result.AllocationUnitSize;
        $record | Add-Member -MemberType NoteProperty -Name "MbTotal" -Value $result.MbTotal;
        $record | Add-Member -MemberType NoteProperty -Name "IoTotal" -Value $result.IoTotal;
        $record | Add-Member -MemberType NoteProperty -Name "MbSecondTotal" -Value $result.MbSecondTotal;
        $record | Add-Member -MemberType NoteProperty -Name "IoSecondTotal" -Value $result.IoSecondTotal;
        $record | Add-Member -MemberType NoteProperty -Name "AvgLatencyRead" -Value $result.AvgLatencyRead;
        $record | Add-Member -MemberType NoteProperty -Name "AvgLatencyWrite" -Value $result.AvgLatencyWrite;
        $records += $record;
    }

    return $records;
}