$b2b = Get-MgUser -Filter "Usertype eq 'Guest'" -All | Select UserPrincipalName

$totalUserCount = ($b2b | Measure-Object).Count
$Usercount = 0

$b2b | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name LastLogin -Value ""
    $_ | Add-Member -MemberType NoteProperty -Name ManagerName -Value ""
    $_ | Add-Member -MemberType NoteProperty -Name ManagerEmail -Value ""
}

$ManagerCache = @{}

$currentDate = Get-Date

# Loop through each user
foreach ($b in $b2b) {
    # Retrieve last login info for the user
    $lastlogin = Get-MgUser -Filter "UserPrincipalName eq '$($b.UserPrincipalName)'" -Property SignInActivity | Select-Object -ExpandProperty SignInActivity -ErrorAction SilentlyContinue
    $b.Lastlogin = if ($lastlogin) { $lastlogin.LastSignInDateTime } else { "No login data" }

    # Initialize the variable for the parsed date
    $lastLoginDateTime = $null

    try {
        # Attempt to parse the date
        $lastLoginDateTime = Get-Date $b.Lastlogin
    } catch {
        # Handle parsing errors by skipping manager lookup
        $lastLoginDateTime = $null
    }

    # Only check for manager if a valid date was parsed and it's older than 90 days
    if ($lastLoginDateTime -and $lastLoginDateTime -lt $currentDate.AddDays(-90)) {
        # Check if the manager has already been retrieved
        if (-not $ManagerCache.ContainsKey($b.UserPrincipalName)) {
            try {
                # Attempt to retrieve the manager
                $Manager = Get-MgUserManager -UserId "$($b.UserPrincipalName)" | Select -ExpandProperty AdditionalProperties -ErrorAction Stop
                if ($Manager) {
                    $ManagerCache[$b.UserPrincipalName] = @{
                        ManagerName  = $Manager.givenName
                        ManagerEmail = $Manager.mail
                    }
                }
            } catch {
                # If the manager is not found, handle the 404 error
                $ManagerCache[$b.UserPrincipalName] = @{
                    ManagerName  = "No manager assigned"
                    ManagerEmail = "No manager assigned"
                }
            }
        }

        # Retrieve manager info from cache
        if ($ManagerCache[$b.UserPrincipalName]) {
            $b.ManagerName = $ManagerCache[$b.UserPrincipalName].ManagerName
            $b.ManagerEmail = $ManagerCache[$b.UserPrincipalName].ManagerEmail
        }
    } else {
        # If the LastLogin is not valid or recent, skip manager check
        $b.ManagerName = "N/A"
        $b.ManagerEmail = "N/A"
    }

    # Display progress
    $Usercount++
    Write-Progress -Activity "Grabbing last login: $Usercount/$totalUserCount" `
                    -Status "Currently Processing: $($b.UserPrincipalName)"
}
