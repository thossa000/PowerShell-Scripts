<#
=============================================================================================
Tanzin Hossain - Script created to output one list of user's in the domain with their MFA status. 
Please reach out regarding any questions or issues.

Name:           Export Office 365 MFA status report
Description:    This script exports Microsoft 365 MFA status report to CSV
Originally By:  Kathy Cooper (o365reports.com)
============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [switch]$DisabledOnly,
    [switch]$EnabledOnly,
    [switch]$EnforcedOnly,
    [switch]$ConditionalAccessOnly,
    [switch]$AdminOnly,
    [switch]$LicensedUserOnly,
    [Nullable[boolean]]$SignInAllowed = $null
)
#Check for MSOnline module
$Modules=Get-Module -Name MSOnline -ListAvailable
if($Modules.count -eq 0)
{
  Write-Host  Please install MSOnline module using below command: `nInstall-Module MSOnline  -ForegroundColor yellow
  Install-Module MSOnline
}

#Connect to MSOnlin
Connect-MsolService | Out-Null

$Result=""
$Results=@()
$UserCount=0
$PrintedUser=0

#Output file declaration
$ExportCSVReport=".\MFAEnabledUserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"


#Modify Where-Object statement to include properties to filter on, in my case I am filtering out service accounts for this check.
Get-MsolUser -All | Where-Object {$_.Department -ne "Service Account Department"} | foreach{
 $UserCount++
 $DisplayName=$_.DisplayName
 $Upn=$_.UserPrincipalName
 $FirstName=$_.FirstName
 $LastName=$_.LastName
 $JobTitle=$_.Title
 $Department=$_.Department
 $Office=$_.Office
 $UserType=$_.UserType
 $WhenCreated=$_.WhenCreated
 $MethodTypes=$_.StrongAuthenticationMethods
 $RolesAssigned=""
 Write-Progress -Activity "`n     Processed user count: $UserCount "`n"  Currently Processing: $DisplayName"
 if($_.BlockCredential -eq "True")
 {
  $SignInStatus="False"
  $SignInStat="Denied"
 }
 else
 {
  $SignInStatus="True"
  $SignInStat="Allowed"
 }

 #Filter result based on SignIn status
 if(($SignInAllowed -ne $null) -and ([string]$SignInAllowed -ne [string]$SignInStatus))
 {
  return
 }

 #Filter result based on License status
 if(($LicensedUserOnly.IsPresent) -and ($_.IsLicensed -eq $False))
 {
  return
 }

 if($_.IsLicensed -eq $true)
 {
  $LicenseStat="Licensed"
 }
 else
 {
  $LicenseStat="Unlicensed"
 }

 #Check for user's Admin role
 $Roles=(Get-MsolUserRole -UserPrincipalName $upn).Name
 if($Roles.count -eq 0)
 {
  $RolesAssigned="No roles"
  $IsAdmin="False"
 }
 else
 {
  $IsAdmin="True"
  foreach($Role in $Roles)
  {
   $RolesAssigned=$RolesAssigned+$Role
   if($Roles.indexof($role) -lt (($Roles.count)-1))
   {
    $RolesAssigned=$RolesAssigned+","
   }
  }
 }

 #Filter result based on Admin users
 if(($AdminOnly.IsPresent) -and ([string]$IsAdmin -eq "False"))
 {
  return
 }

  $Methods=""
  $MethodTypes=""
  $MethodTypes=$_.StrongAuthenticationMethods.MethodType
  $DefaultMFAMethod=($_.StrongAuthenticationMethods | where{$_.IsDefault -eq "True"}).MethodType
  $MFAPhone=$_.StrongAuthenticationUserDetails.PhoneNumber
  $MFAEmail=$_.StrongAuthenticationUserDetails.Email

  if($MFAPhone -eq $Null)
  { $MFAPhone="-"}
  if($MFAEmail -eq $Null)
  { $MFAEmail="-"}

  if($MethodTypes -ne $Null)
  {
   $ActivationStatus="Yes"
   foreach($MethodType in $MethodTypes)
   {
    if($Methods -ne "")
    {
     $Methods=$Methods+","
    }
    $Methods=$Methods+$MethodType
   }
  }
  else
  {
   $ActivationStatus="No"
   $Methods="-"
   $DefaultMFAMethod="-"
   $MFAPhone="-"
   $MFAEmail="-"
  }

  #Print to output file
  $PrintedUser++
  $Result=@{'DisplayName'=$DisplayName;'UserPrincipalName'=$upn;'FirstName'=$FirstName;'LastName'=$LastName;'JobTitle'=$JobTitle;'Department'=$Department;'Location'=$Office;'UserType'=$UserType;'CreationDateTime'=$WhenCreated;'ActivationStatus'=$ActivationStatus;'DefaultMFAMethod'=$DefaultMFAMethod;'AllMFAMethods'=$Methods;'MFAPhone'=$MFAPhone;'MFAEmail'=$MFAEmail;'LicenseStatus'=$LicenseStat;'IsAdmin'=$IsAdmin;'AdminRoles'=$RolesAssigned;'SignInStatus'=$SigninStat}
  $Results= New-Object PSObject -Property $Result
  $Results | Select-Object DisplayName,UserPrincipalName,FirstName,LastName,JobTitle,Department,Location,UserType,CreationDateTime,ActivationStatus,DefaultMFAMethod,AllMFAMethods,MFAPhone,MFAEmail,LicenseStatus,IsAdmin,AdminRoles,SignInStatus | Export-Csv -Path $ExportCSVReport -Notype -Append
 }

#Open output file after execution
Write-Host `nScript executed successfully

if((Test-Path -Path $ExportCSV) -eq "True")
{
 Write-Host " MFA Disabled user report available in:" -NoNewline -ForegroundColor Yellow
 Write-Host $ExportCSV `n 
 $Prompt = New-Object -ComObject wscript.shell
 $UserInput = $Prompt.popup("Do you want to open output file?",`
 0,"Open Output File",4)
 If ($UserInput -eq 6)
 {
  Invoke-Item "$ExportCSV"
 }
 Write-Host Exported report has $PrintedUser users
}
elseif((Test-Path -Path $ExportCSVReport) -eq "True")
{
 Write-Host ""
 Write-Host " MFA Enabled user report available in:" -NoNewline -ForegroundColor Yellow
 Write-Host $ExportCSVReport `n
 $Prompt = New-Object -ComObject wscript.shell
 $UserInput = $Prompt.popup("Do you want to open output file?",`
 0,"Open Output File",4)
 If ($UserInput -eq 6)
 {
  Invoke-Item "$ExportCSVReport"
 }
 Write-Host Exported report has $PrintedUser users  
}

#Clean up session
Get-PSSession | Remove-PSSession
