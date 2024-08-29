#Email information to email managers regarding inactive users.
$smtpServer = "smtp.example.com"  
$fromAddress = "ITCompliance@example.com" 
$ouPath = "OU=Users,OU=Example,DC=Example,DC=com"
#Variable to hold 60 day inactivity date.
$thresholdDate = (Get-Date).AddDays(-60)

#Log into Microsoft Graph to pull login information for Azure users.
$Modules= Get-InstalledModule -Name Microsoft.Graph -erroraction 'silentlycontinue' | Measure
if($Modules.count -eq 0)
{
Install-Module Microsoft.Graph
}
Connect-MgGraph -NoWelcome -Scopes "User.Read.All"

Add-Type -AssemblyName System.Windows.Forms;

[System.Windows.Forms.MessageBox]::Show("We will now load all CVE Domain users (Approximately 13000 users). This should take 15-30 minutes to complete. `n(Press OK to Start)", "Load All CVE AD Users", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information);


#Grab all users in the EndUser OU in Active Directory. Only use if Directory team does not provide CVE user list. Running this command takes around 20-30 minutes to load all users.
$users = get-aduser * -SearchRoot $oupath -SizeLimit 1000 -IncludedProperties FirstName, LastName, SamAccountName, UserPrincipalName, DisplayName, Type, AccountIsDisabled, whenCreated, LastLogonTimestamp, LastLogon, Manager | Where-Object {$_.Samaccountname -notlike '*SERVICEACCOUNT*'} | Select FirstName, LastName, SamAccountName, UserPrincipalName, DisplayName, Type, AccountIsDisabled, whenCreated, LastLogonTimestamp, LastLogon, Manager

#Grab total number of users for progress bars to show enduser.
$totalusers = $users | Measure

#Add new column called Inactive, this will hold info on whether the user has logged in or is inactive
foreach ($user in $users) {
$user | Add-Member -MemberType NoteProperty -Name Inactive -Value ""
}

#Check LastLogons from On-Prem AD
foreach ($user in $users) {
    if ($user.LastLogonTimestamp -gt $thresholdDate) {
        $user.Inactive = "No, User account LastLoginTimestamp was in the last 90 days."
    } 
    else {
        if ($user.AccountIsDisabled -eq $True) {$user.Inactive = "Account Is Disabled"} 
        else {
            if ($user.WhenCreated -gt $thresholdDate) {$user.Inactive = "No, User account created within the last 90 days."} 
            else { 
                if ($user.LastLogon -gt $thresholdDate) {$user.Inactive = "No, User account LastLogon was in the last 90 days."} 
                else {$user.Inactive = "Yes, user has not logged in the last 90 days."}
            }
        }
    } 
}

#Check Last Login from Entra ID through Microsoft Graph, this requires access through admin account.
$Usercount = 0;
foreach ($user in $users) {
    if ($user.Inactive -eq "Yes, user has not logged in the last 90 days."){
    $userlogin = Get-MgUser -Filter "userprincipalname eq '$($user.userprincipalname)'" -Property SigninActivity -erroraction 'silentlycontinue' | Select -ExpandProperty SignInActivity;
        if($userlogin.LastSignInDateTime -gt $thresholdDate){
        $user.Inactive = "No, user logged into Azure on $($userlogin.LastSignInDateTime)"
        }
    }
    $usercount++;
    Write-Progress -Activity "`n     Checking inactive users for Azure login activity: $UserCount/$($totalusers.count)"`n"  Currently Processing: $($user.userprincipalname)"
}


#Grabbing manager info for email.
foreach ($user in $users) {
$user | Add-Member -MemberType NoteProperty -Name ManagerEmail -Value ""
$user | Add-Member -MemberType NoteProperty -Name ManagerName -Value ""
}

$Usercount = 0
foreach ($user in $users) {
# Get the manager's details using the Manager attribute for inactive users
if ($user.manager -and ($user.inactive -eq "Yes, user has not logged in the last 90 days." -or $user.inactive -eq 'Account Is Disabled')) {
    $managerDetails = Get-ADUser -Identity $user.Manager | Select UserPrincipalName, FirstName;
    $user.ManagerEmail = $managerDetails.Userprincipalname;
    $user.ManagerName = $managerDetails.FirstName;

  }
# If user does not have a manager, leave field blank.
else {
    $user.ManagerEmail = ""
    $user.ManagerName = ""
    }
        
    $usercount++
    Write-Progress -Activity "`n     Grabbing supervisor's information and employement status for inactive users: $UserCount/$($totalusers.count)"`n"  Currently Processing: $($user.samaccountname)"
}

foreach ($user in $users) {
$user | Add-Member -MemberType NoteProperty -Name EmailSent -Value ""
}
<# Group inactive users by their manager#>
$inactiveUsersByManager = $users | Where-Object { $_.Inactive -eq "Yes, user has not logged in the last 60 days."} | Group-Object -Property ManagerEmail;
$confirm = $inactiveUsersByManager | Select -ExpandProperty Group;
$confirm | Select DisplayName, AccountIsDisabled, whenCreated, LastLogonTimestamp, Inactive, ManagerEmail, ManagerName, ActiveStatus,StaffType,TerminationDate | export-csv -NoTypeInformation C:\Users\ConfirmEmailList.csv;

[System.Windows.Forms.MessageBox]::Show("A list of inactive users has been exported to C:\Users\ConfirmEmailList.csv.`nPlease confirm the list and press OK to Continue`nOtherwise close this script and report any issues.", "Confirm User List Before Sending Emails", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information);

$Usercount = 0;

foreach ($group in $inactiveUsersByManager) {
    $managerEmail = $group.Name;
    $inactiveUsers = $group.Group;

    <# Get the manager's name from one of the inactive users (assuming all users under this manager have the same manager name)#>
    $managerName = ($inactiveUsers | Select-Object -First 1).ManagerName;
    
    $body = "<html><body>";
    $body += "Dear $managerName,<br><br>IT is in the process of reviewing all inactive user accounts and requires your assistance as you are listed as the Supervisor for the following staff member(s). These network account(s) have not been used in over <strong>90 days</strong>.  
    Inactive accounts pose a potential security risk as they may be vulnerable to unauthorized access or misuse. IT performs a cleanup of staff accounts to protect the integrity of the network, and in support of SOX compliance.<br><br><ul>";
    $body += "<table border='1' cellpadding='5' cellspacing='0'>";
    $body += "<tr><th>Name</th><th>E-mail</th><th>Username</th></tr>";
    foreach ($user in $inactiveUsers) {
        <#$body += "<li>Name: $($user.DisplayName) - Email: $($user.UserPrincipalName) - UserName: $($user.SamAccountName)</li>";#>
        <# Mark that an email has been sent for this user#>
        $body += "<tr>";
        $body += "<td>$($user.DisplayName)</td>";
        $body += "<td>$($user.UserPrincipalName)</td>";
        $body += "<td>$($user.SamAccountName)</td>";
        $body += "</tr>";
        $user.EmailSent = "Yes";
        }
        $body += "</table><br>";
       
        Once you have reviewed the above information, please let us know what should be done with the accounts (Terminate or Retain the Network Account). In the event you would still like to retain access, please provide a valid reason and have the user enable the network account by logging into a computer.
        <br><br>
        <strong><u>Important</u></strong>: Your response is required within 10 business days, no response will be considered as confirmation that the network account is no longer needed and can be deleted.<br>
        If you have any questions, please contact IS Compliance and Controls Monitoring.
        <br><br>
        Thank you,<br>
        IT Compliance";
        $body += "</body></html>";
        <# Send the email#>
        if ($managerEmail) {
            Send-MailMessage -From $fromAddress -To $managerEmail -Subject "Inactive User Account(s)" -Body $body -SmtpServer $smtpServer -port 25 -BodyAsHtml;
        }
    $usercount++
    Write-Progress -Activity "`n     Emailing supervisor regarding inactive user accounts: $UserCount"`n"  Currently Processing: $($managerEmail)"
    }
<# Add a new column to $users to indicate if an email was sent to the manager#>
    foreach ($user in $users) {
        if (-not $user.PSObject.Properties.Match('EmailSent')) {
            $user.EmailSent = "No";
        }
}

$finalList = $users | Select EmployeeID, FirstName, LastName, SamAccountName, UserPrincipalName, DisplayName, Type, AccountIsDisabled, WhenCreated, LastLogonTimestamp, LastLogon, Inactive, ManagerEmail, ActiveStatus, StaffType, TerminationDate, EmailSent | Sort-Object Inactive;
$finalList | export-csv -NoTypeInformation C:\Users\fulltest.csv;
[System.Windows.Forms.MessageBox]::Show("Final List for review exported to C:\Users\fulltest.csv.`nPress OK to end.", "End Script", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information);

Disconnect-MgGraph
Get-PSSession | Remove-PSSession
