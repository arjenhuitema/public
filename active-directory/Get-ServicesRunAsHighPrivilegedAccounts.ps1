# Get a list of all service running as domain users with Domain or Enterprise Admin privileges.
$domain = "contoso"
$domainName = "contoso.com" 
$servicesFile = "c:\services.csv"
$errorFile = "c:\services-errors.csv"
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" 
$enterpriseAdmins = Get-ADGroupMember -Identity "Enterprise Admins"
$domainservices = @()
$i = 0

# Test and clear the result files.
if (Test-path $servicesFile) { Clear-Content $servicesFile }
if (test-path $errorFile) { Clear-Content $errorFile }

# Query AD for all computer objects with server OS
$servers = Get-ADComputer -LDAPFilter "(&(objectcategory=computer)(OperatingSystem=*server*))"

# Get a list of all service running as domain users with Domain or Enterprise Admin privileges.
foreach ($server in $servers) {
    $i = $i + 1
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar heading, respectively.
    Write-Progress -Activity "Searching servers for services running with privileged accounts" -Status "Progress:" -PercentComplete ($i / $servers.count * 100)
    
    if (Test-Connection -computername $server.name -Quiet -Count 1) {
        $services = try {
            Get-WmiObject win32_service -ComputerName $server.name -ErrorAction Stop | where-object { $_.startname -like "$domain\*" -or $_.startname -like "*@$domainName" } | Select-Object name, startname, startmode
        }
        catch {
            $server.name + " could not be contacted via Get-WmiObject" | Out-File -Append $errorFile
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
    else {
        $server.name + " did not respond to ping" | Out-File -Append $errorFile
    }
}

# Export results to CSV file
$domainservices | Export-Csv -Path $servicesFile -NoTypeInformation