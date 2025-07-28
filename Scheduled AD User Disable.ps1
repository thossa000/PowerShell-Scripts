# Identify and load the daily .txt file.

#Searching for a daily .txt file to check for user accounts.
$date = Get-Date -format 'yyyy-MM-dd'
$txtFile = Get-ChildItem ".\Disabled Users\$date.txt" -ErrorAction SilentlyContinue | Select Name | Select-Object -ExpandProperty Name
$txtFileExists = ''
if($txtfile -ne $null)
{
Write-Host "Running disablement for users in $txtfile" -ForegroundColor Green
$txtFileExists=$true
$txtFilePath= Get-ChildItem ".\Disabled Users\$date.txt" | Select Fullname | Select-Object -ExpandProperty Fullname
}
else
{
Write-Host "ERROR NO FILE FOUND FOR TODAY IN THE DIRECTORY, PLEASE CHECK .txt FILE IF FILE EXPECTED" -ForegroundColor Red
$txtFileExists=$false
}

if($txtFileExists -eq $True)
{
$usernames = Get-Content $txtFilePath -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($usernames)) {
    # Email analyst and let them no nothing was sent today but the file exists.
        Write-Host "The file exists but is blank." -ForegroundColor Yellow
    } else {
        $usernames
    }
}
else
{
# Email just to tell him no file exists for the script to use today.
}

# Query the users’ in the text file and grab their information from AD.
foreach($user in $usernames)
{
get-aduser $usernames
# Gather properties required for next tasks into a variable.
# Create error handling for usernames that do not exist.
}

# Disable their account.



# Update their description.



# Email the actions completed by the script to the IAM team.

