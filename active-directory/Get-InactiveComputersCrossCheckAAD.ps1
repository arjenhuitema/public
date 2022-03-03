# Exports to CSV a list of computers that have not been active in AD during the last 90 days
Connect-AzureAD
$DaysInactive = 90 
$time = (Get-Date).Adddays( - ($DaysInactive))
 
# Get all AD and AAD computers with lastLogonTimestamp less than $time
$InactiveComputersAD = Get-ADComputer -Filter { LastLogonTimeStamp -lt $time } -Properties LastLogonTimeStamp | select-object Name, @{Name = "Stamp"; Expression = { [DateTime]::FromFileTime($_.lastLogonTimestamp) } }
$InactiveComputersAAD = Get-AzureADDevice | Where-Object { $_.ApproximateLastLogonTimeStamp -lt $time } | select-object displayName, ApproximateLastLogonTimeStamp
# Only show computers that have not been active in both AD and AAD for more than 90 days
$InactiveComputers = $InactiveComputersAD | Where-Object { $_.Name -in $InactiveComputersAAD.displayName }
#Export to CSV
$InactiveComputers | Export-CSV "C:\InactiveComputersAD-AAD.CSV" -NoTypeInformation -Encoding UTF8

# Inactive computers are moved and disabled
foreach ($computer in $InactiveComputers) {
    $newOU = "OU=disabled computers,DC=contoso,DC=com"
    Write-Host ("Moving " + $computer.Name + " to " + $newOU)
    Get-ADComputer $computer.Name | Set-ADObject -ProtectedFromAccidentalDeletion:$false
    Get-ADComputer $computer.Name | Move-ADObject -TargetPath $newOU
    Get-ADComputer $computer.Name | Disable-ADAccount -Confirm:$false
}