# Connect to Azure AD
Connect-AzureAD

# Get all enterprise applications with the specified tag
$apps = Get-AzureADServicePrincipal -All $true |
    Where-Object { $_.Tags -contains "WindowsAzureActiveDirectoryIntegratedApp" } |
    Select-Object ObjectId, DisplayName, AppId

# Initialize an array to hold the final results
$results = @()

# Loop through each app to get assigned groups
foreach ($app in $apps) {
    # Get the groups assigned to the current app
    $groups = Get-AzureADServiceAppRoleAssignment -ObjectId $app.ObjectId |
              ForEach-Object {
                  Get-AzureADGroup -ObjectId $_.PrincipalId |
                  Select-Object DisplayName
              }

    # Create a custom object to hold app details and assigned groups
    $result = [PSCustomObject]@{
        ObjectId    = $app.ObjectId
        DisplayName = $app.DisplayName
        AppId       = $app.AppId
        AssignedGroups = ($groups.DisplayName -join ', ') # Join group names into a single string
    }

    # Add the result to the array
    $results += $result
}

# Output the results
$results

# Optional: Export the results to a CSV file
$results | Export-Csv -Path "EnterpriseAppsWithGroups.csv" -NoTypeInformation
