# Identify and load the daily .txt file.
 
#Searching for a daily .txt file to check for user accounts.
$date = Get-Date -format 'yyyy-MM-dd'
$logDate = Get-Date -format 'yyyy-MM-dd HH:mm:ss'
$currentUser = $env:USERNAME
 
if("C:\Users\$currentUser\Documents\Powershell\logs\$date log.txt" -eq $false)
{
    New-Item -Path "C:\Users\$currentUser\Documents\Powershell\logs\$date log.txt" -ItemType File
}
 
$logFile = "C:\Users\$currentUser\Documents\Powershell\logs\$date log.txt"
 
Add-Content -Path $logFile -Value "$logDate Start Script"
$txtFile = Get-ChildItem "C:\Users\$currentUser\Documents\Powershell\Disabled Users\$date.txt" -ErrorAction SilentlyContinue | Select Name | Select-Object -ExpandProperty Name
$txtFileExists = ''
if($txtfile -ne $null)
{ 
    $txtFileExists=$true
    $txtFilePath= Get-ChildItem ".\Disabled Users\$date.txt" | Select Fullname | Select-Object -ExpandProperty Fullname
    Add-Content -Path $logFile -Value "Text file found. Running disablement for users in $txtfile"
}
else
{
    Add-Content -Path $logFile -Value "ERROR: NO FILE FOUND FOR TODAY IN THE DIRECTORY, PLEASE CHECK .txt FILE IF FILE EXPECTED"
    $txtFileExists=$false
    exit
}
 
if($txtFileExists -eq $True)
{
    $usernames = Get-Content $txtFilePath -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($usernames)) {
    Add-Content -Path $logFile -Value "ERROR: No users found in $txtfile"
    exit
    } else {
        $usernames
        Add-Content -Path $logFile -Value "Grabbing user information for $usernames"
    }
}
else
{
Add-Content -Path $logFile -Value "ERROR: No $txtfile found in Disabled Users directory."
exit
}
 
# Query the users’ in the text file and grab their information from AD.
 
$userDisableList = @()
 
foreach ($user in $usernames) {
    try {
        $userInfo = Get-ADUser -Identity $user -Properties City, DisplayName, Department, Description, EmailAddress, EmployeeID, Manager, MemberOf, Office, SamAccountName, SID, Title, Enabled |
            Select-Object City, DisplayName, Department, Description, EmailAddress, EmployeeID, Manager, MemberOf, Office, SamAccountName, SID, Title, Enabled
        Add-Content -Path $logFile -Value "Retrieved user info for $user"
        if ($userInfo) {
            $userDisableList += $userInfo
        }
    }
    catch {
        Add-Content -Path $logFile -Value "ERROR: Failed to retrieve info for user: $user. Error: $_"
        exit
    }
}
 
# Disable their account.
foreach ($user in $userDisableList) {
$logDate = Get-Date -format 'yyyy-MM-dd HH:mm:ss'
Set-ADUser $user.SamAccountName -Enabled $false -Description "Disabled by PS Script on $date"
Add-Content -Path $logFile -Value "$logDate Disabled user $user"
}
