# Get Graph API Access Token
# Provide your Azure AD Domain Name
$TenantId = "*.onmicrosoft.com"

# Provide Azure AD Application client Id of your app.
# You should have granted Admin consent for this app to use the application permissions "AuditLog.Read.All and User.Read.All" in your tenant.
$AppClientId = "********-****-****-****-************"
  
# Provide Application client secret key
$ClientSecret = "************************"
  
$RequestBody = @{client_id = $AppClientId; client_secret = $ClientSecret; grant_type = "client_credentials"; scope = "https://graph.microsoft.com/.default"; }
$OAuthResponse = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $RequestBody
$AccessToken = $OAuthResponse.access_token


# Export Last login date for all Azure AD Users
# Form request headers with the acquired $AccessToken
$headers = @{'Content-Type' = "application\json"; 'Authorization' = "Bearer $AccessToken" }
 
# This request get users list with signInActivity.
$ApiUrl = "https://graph.microsoft.com/beta/users?`$select=displayName,userPrincipalName,signInActivity,userType,assignedLicenses"
 
$Result = @()
While ($ApiUrl -ne $Null) {
    #Perform pagination if next page link (odata.nextlink) returned.
    $Response = Invoke-WebRequest -Method GET -Uri $ApiUrl -ContentType "application\json" -Headers $headers | ConvertFrom-Json
    if ($Response.value) {
        $Users = $Response.value
        ForEach ($User in $Users) {
 
            $Result += New-Object PSObject -property $([ordered]@{ 
                    DisplayName        = $User.displayName
                    UserPrincipalName  = $User.userPrincipalName
                    LastSignInDateTime = if ($User.signInActivity.lastSignInDateTime) { [DateTime]$User.signInActivity.lastSignInDateTime } Else { $null }
                    IsLicensed         = if ($User.assignedLicenses.Count -ne 0) { $true } else { $false }
                    IsGuestUser        = if ($User.userType -eq 'Guest') { $true } else { $false }
                })
        }
 
    }
    $ApiUrl = $Response.'@odata.nextlink'
}
$Result | Export-CSV "C:\LastLoginDateReport.CSV" -NoTypeInformation -Encoding UTF8

# Find Inactive users
$DaysInactive = 90
$dateTime = (Get-Date).Adddays( - ($DaysInactive))
$activeDirectoryInactive = Get-ADUser -Filter { LastLogonTimeStamp -lt $dateTime -and enabled -eq $true } -Properties LastLogonTimeStamp | select-object Name, UserPrincipalName, @{Name = "Stamp"; Expression = { [DateTime]::FromFileTime($_.lastLogonTimestamp) } }
$resultFilteredInactive = $Result | Where-Object { $_.LastSignInDateTime -eq $Null -OR $_.LastSignInDateTime -le $dateTime }
$resultFilteredCrossCheck = $activeDirectoryInactive | Where-Object { $_.UserPrincipalName -in $resultFilteredInactive.UserPrincipalName }
$resultFilteredCrossCheck | Export-CSV "C:\InactiveUsersAD-AAD.CSV" -NoTypeInformation -Encoding UTF8

# Inactive users are moved and disabled
foreach ($user in $resultFilteredCrossCheck) {
    $username = $user.userPrincipalName -replace '@*DNS NAME DOMAIN*', ''
    $newOU = "OU=disabled users,DC=contoso,DC=com"
    Write-Host ("Moving " + $username + " to " + $newOU)
    Get-ADUser $username | Set-ADObject -ProtectedFromAccidentalDeletion:$false
    Get-ADUser $username | Move-ADObject -TargetPath $newOU
    Get-ADUser $username | Disable-ADAccount -Confirm:$false
}