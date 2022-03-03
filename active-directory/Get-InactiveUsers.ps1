# Exports to CSV a list of users that have not been active in AD during the last 90 days
Import-Module activedirectory 
$DaysInactive = 90 
$time = (Get-Date).Adddays( - ($DaysInactive))
Get-ADUser -Filter { LastLogonTimeStamp -lt $time -and enabled -eq $true } -Properties LastLogonTimeStamp | select-object Name, @{Name = "Stamp"; Expression = { [DateTime]::FromFileTime($_.lastLogonTimestamp) } } | Export-Csv InactiveUsers.csv -NoTypeInformation