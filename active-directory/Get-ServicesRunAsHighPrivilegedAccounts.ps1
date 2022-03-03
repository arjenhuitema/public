# Get a list of all service running as domain users with Domain or Enterprise Admin privileges.
$domain = "contoso"
$domainName = "contoso.com" 
$servicesFile = "c:\services.csv"
$errorFile = "c:\services-errors.csv"
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" 
$enterpriseAdmins = Get-ADGroupMember -Identity "Enterprise Admins"
$domainservices = @()

# Test and clear the result files.
if (Test-path $servicesFile) { Clear-Content $servicesFile }
if (test-path $errorFile) { Clear-Content $errorFile }

# Query AD for all computer objects with server OS
$servers = Get-ADComputer -LDAPFilter "(&(objectcategory=computer)(OperatingSystem=*server*))"

# Get a list of all service running as domain users with Domain or Enterprise Admin privileges.
foreach ($server in $servers) {
    $services = try {
        Get-WmiObject win32_service -ComputerName $server.name -ErrorAction Stop | where-object { $_.startname -like "$domain\*" -or $_.startname -like "*@$domainName" } | Select-Object name, startname, startmode
    }
    catch {
        "$server.name could not be contacted" | Out-File -Append $errorFile
    }
    foreach ($service in $services) {
        If ($service.startname -match "\w+\\\w+") {
            $runAsAccount = $service.startname -replace ($domain + "\\"), ''
        }
        If ($service.startname -notmatch "\w+\\\w+") {
            $runAsAccount = $service.startname -replace ("\@" + $domainName), ''
        }
        If ($runAsAccount -in $domainAdmins.SamAccountName) {
            
            $domserv = [pscustomobject]@{Server = $server.name; Service = $service.name; RunAsName = $service.startname; StartMode = $service.startmode; Group = "Domain Admins" }
            $domainservices += $domserv
        }
        If ($runAsAccount -in $enterpriseAdmins.SamAccountName) {
            
            $domserv = [pscustomobject]@{Server = $server.name; Service = $service.name; RunAsName = $service.startname; StartMode = $service.startmode; Group = "Enterprise Admins" }
            $domainservices += $domserv
        }
    }
}

# Export results to CSV file
$domainservices | Export-Csv -Path $servicesFile -NoTypeInformation