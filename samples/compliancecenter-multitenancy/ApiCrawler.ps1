# dot-load functions and globals
. .\Functions.ps1;
. .\Globals.ps1;

# Set local variables
# Storage Account Settings, this is needed to access the storage queue
$pathWatermark = $env:CRAWLER_PATHWATERMARK;
$storageAccountName = $env:CRAWLER_STORAGENAME;
$storageAccountKey = $env:CRAWLER_STORAGEKEY;
$storageQueueName = $env:CRAWLER_STORAGQUEUENAME;

# Workloads for which to retrieve audit data
$workloads = @(
    "Audit.AzureActiveDirectory",
    "Audit.SharePoint",
    "Audit.Exchange",
    "Audit.General",
    "DLP.All"
);  

# Authenticate against AAD
$headers = Get-O365AuthenticationHeaders -TenantDomain $tenantDomain -ClientId $clientId -ClientSecret $clientSecret;
$headers["Authorization"];

# Load the Storage Queue
$queue = Get-Queue -Name $storageQueueName -NameAccount $storageAccountName -KeyAccount $storageAccountKey;
$messageSize = 10;

# Read all content blobs until now
$timeEnd = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ";

foreach ($workload in $workloads) 
{
    # Retrieve watermark
    $timeWatermark = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
    $watermarkFile = "$pathWatermark\$workload.log";
    if(Test-Path -Path $watermarkFile)
    {
        $timeWatermark = Get-Content -Path $watermarkFile;
    }

    $rawRef = Invoke-WebRequest -UseBasicParsing -Headers $headers `
        -Uri "https://manage.office.com/api/v1.0/$tenantId/activity/feed/subscriptions/content?contenttype=$workload&startTime=$timeWatermark&endTime=$timeEnd&PublisherIdentifier=$tenantId";

    $rawRef.GetType();
    "`$rawRef.Headers.NextPageUri:`t$($rawRef.Headers.NextPageUri)";
    "`$rawRef.Content:`t`t$($rawRef.Content)";
    #$rawRef.Headers;

    # Write watermark
    # (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") | Out-File -FilePath $watermarkFile -NoNewline;
}
    <#
    

    $storedTime = Get-content $Tracker;

    # Retrieve data
    $rawRef = Invoke-WebRequest -UseBasicParsing -Headers $headers `
        -Uri "https://manage.office.com/api/v1.0/$tenantId/activity/feed/subscriptions/content?contenttype=$workload&startTime=$Storedtime&endTime=$endTime&PublisherIdentifier=$tenantId";

    # If more than one page is returned capture and return in pageArray
    if ($rawRef.Headers.NextPageUri)
    {
        $pageTracker = $true;
        $pagedReq = $rawRef.Headers.NextPageUri;
    
        while ($pageTracker -ne $false)
        {   
            $pageuri = $pagedReq + "?PublisherIdentifier=" + $tenantId;

            $currentPage = Invoke-WebRequest -Headers $headerParams -Uri $pageuri -UseBasicParsing
            $pageArray += $currentPage
        
            if (-not $currentPage.Headers.NextPageUri)
            {
                $pageTracker = $false    
            }
            else
            {
                $pagedReq = $currentPage.Headers.NextPageUri;
            }
        }
    }

    $pageArray += $rawref;
    if ($pageArray.RawContentLength -gt 3)
    {
        foreach ($page in $pageArray)
        {
            $request = $page.content | convertfrom-json
            $runs = $request.Count/($messageSize +1)
            $writeSize = $messageSize
            $i = 0

            while ($runs -ge 1)
            { 
                $rawmessage = $request[$i..$writeSize].contenturi; 

                foreach ($msg in $rawmessage)
                { 
                    $msgarray += @($msg) 
                    $message = $msgarray | ConvertTo-Json;
                }

                $queueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage -ArgumentList "$message";
                $queue.CloudQueue.AddMessage($queuemessage);

                $runs -= 1
                $i+= $messageSize +1
                $writeSize += $messageSize + 1 
            }   

            if ($runs -gt 0)
            {
                $rawMessage = $request[$i..$writeSize].contenturi;
                
                foreach ($msg in $rawMessage)
                {  
                    $msgarray += @($msg)
                    $message = $msgarray | ConvertTo-Json;
                }                                                           
                
                $runs -=1                                   
                $queueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage -ArgumentList "$message"
                $queue.CloudQueue.AddMessage($queueMessage)
            }
        }

        $time = $pagearray[0].Content | ConvertFrom-Json;
        $Lastentry = $time[$Time.contentcreated.Count -1].contentCreated;
        
        if ($Lastentry -ge $storedTime)
        {   
            Out-File -FilePath $Tracker -NoNewline -InputObject (Get-Date $lastentry).Addseconds(1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } 
    }
}
#>
