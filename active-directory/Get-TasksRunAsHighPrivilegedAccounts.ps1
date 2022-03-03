# Get a list of all service running as domain users with Domain or Enterprise Admin privileges
$domain = "contoso"
$domainName = "contoso.com"
$tasksFile = "c:\tasks.csv" 
$errorFile = "c:\tasks-errors.csv"
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" 
$enterpriseAdmins = Get-ADGroupMember -Identity "Enterprise Admins"
$domainservices = @()

# Test and clear the result files.
if (Test-path $tasksFile) { Clear-Content $tasksFile }
if (test-path $errorFile) { Clear-Content $errorFile }

# Query AD for all computer objects with server OS
$servers = Get-ADComputer -LDAPFilter "(&(objectcategory=computer)(OperatingSystem=*server*))"

# Get a list of all service running as domain users with Domain or Enterprise Admin privileges
foreach ($server in $servers) {
    $tasks = try {
        schtasks.exe /query /s $server.name /V /FO CSV | ConvertFrom-Csv | Where-Object { $_.TaskName -ne "TaskName" }
    }
    catch {
        "$server.name could not be contacted" | Out-File -Append $errorFile
    }
    foreach ($task in $tasks) {
        If ($task."Run As User" -match "\w+\\\w+") {
            $runAsAccount = $task."Run As User" -replace ($domain + "\\"), ''
        }
        If ($task."Run As User" -notmatch "\w+\\\w+") {
            $runAsAccount = $task."Run As User" -replace ("\@" + $domainName), ''
        }
        If ($runAsAccount -in $domainAdmins.SamAccountName) {
            
            $domserv = [pscustomobject]@{Server = $server.name; Task = $task.TaskName; RunAsName = $task."Run As User"; Group = "Domain Admins" }
            $domainservices += $domserv
        }
        If ($runAsAccount -in $enterpriseAdmins.SamAccountName) {
            
            $domserv = [pscustomobject]@{Server = $server.name; Task = $task.TaskName; RunAsName = $task."Run As User"; Group = "Enterprise Admins" }
            $domainservices += $domserv
        }
    }
}

# Export results to CSV file
$domainservices | Export-Csv -Path $tasksFile -NoTypeInformation