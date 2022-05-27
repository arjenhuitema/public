$storageCapacity = @(
    $storageAccounts = Get-AzStorageAccount
    ForEach ($storageAccount in $storageAccounts) {

        $storageAccountIdBlob = $storageAccount.Id + '/blobServices/default'
        $storageAccountIdFile = $storageAccount.Id + '/fileServices/default'
        $usedCapacityInMiB = @(Get-AzMetric -ResourceId $storageAccount.Id -MetricName "UsedCapacity").Data.Average / 1048576
        $blobCapacityInMiB = @(Get-AzMetric -ResourceId $storageAccountIdBlob -MetricName "BlobCapacity").Data.Average / 1048576
        $fileCapacityInMiB = @(Get-AzMetric -ResourceId $storageAccountIdFile -MetricName "FileCapacity").Data.Average / 1048576
        [PSCustomObject]@{storageAccount = $storageAccount.StorageAccountName; resourceGroup = $storageAccount.ResourceGroupName; location = $storageAccount.Location; skuName = $storageAccount.SkuName; kind = $storageAccount.Kind; usedCapacityInMiB = $usedCapacityInMiB; BlobCapacityInMiB = $BlobCapacityInMiB; FileCapacityInMiB = $FileCapacityInMiB }
    }	
)

$storageCapacity | Select-Object storageAccount, resourceGroup, location, skuName, kind, usedCapacityInMiB, BlobCapacityInMiB, FileCapacityInMiB | Export-Csv -delimiter ";" -Path ".\storageAccountsUsedCapacity.csv" -NoClobber -NoTypeInformation