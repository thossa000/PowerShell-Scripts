$guests = Get-AzureADUser -Filter "userType eq 'Guest'" -All $true

foreach ($guest in $guests) {
$Userlogs = Get-AzureADAuditSignInLogs -Filter "userprincipalname eq `'$($guest.mail)'" -ALL:$true

if ($Userlogs -is [array]) {
$timestamp = $Userlogs[0].createddatetime
}
else {
$timestamp = $Userlogs.createddatetime
}
$Info = [PSCustomObject]@{
Name = $guest.DisplayName
UserType = $guest.UserType
UPN = $guest.UserPrincipalName
Enabled = $guest.AccountEnabled
LastSignin = $timestamp
}
Start-Sleep -Milliseconds 500
$Info | Export-csv C:\Users\thossa000\Downloads\GuestUserLastSignins.csv -NoTypeInformation -Append
Remove-Variable Info
}
Disconnect-AzureAD
Write-Host -ForegroundColor Green "Exported Logs successfully"
Get-PSsession | Exit-PSSession
