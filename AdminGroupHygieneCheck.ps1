Connect-MgGraph

# Initialize an array to hold group member details
$groupMemberDetails = @()

# Function to process groups and their nested groups
function Process-GroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParentGroupName,

        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    try {
        # Fetch members of the current group
        $groupMembers = Get-MgGroupMember -GroupId $GroupId -All

        # Check if the group has members
        if ($groupMembers.Count -eq 0) {
            Write-Host "Group $ParentGroupName is empty."
            return
        }

        # Collect the group name and member details
        foreach ($member in $groupMembers) {
            # Check if the required properties exist before accessing them
            $displayName = $member.AdditionalProperties['displayName']
            $userPrincipalName = $member.AdditionalProperties['userPrincipalName']

            # Add the details to the array
            $groupMemberDetails += [pscustomobject]@{
                GroupName         = $ParentGroupName
                DisplayName       = $displayName
                UserPrincipalName = $userPrincipalName
            }
        }

        # Fetch nested groups within the current group
        $members = Get-MgGroupMember -GroupId $GroupId -All

        # Filter nested groups from the members
        $nestedGroups = $members | Where-Object { $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group' }

        # Check if there are nested groups
        if ($nestedGroups.Count -eq 0) {
            Write-Host "No nested groups found in $ParentGroupName."
        }

        foreach ($nestedGroup in $nestedGroups) {
            $nestedGroupId = $nestedGroup.Id
            $nestedGroupName = $nestedGroup.AdditionalProperties['displayName']

            # Process the nested group's members
            Process-GroupMembers -ParentGroupName "$ParentGroupName - $nestedGroupName" -GroupId $nestedGroupId
        }
    } catch {
        Write-Error "Failed to process group ${GroupId}: $_"
    }
}

# Fetch only groups that start with 'ADM-'
# $admGroups = Get-MgGroup -Filter "startswith(displayName, 'ADM-')" -All

# Total number of groups (for progress bar)
$totalGroups = $admGroups.Count

# Loop through each ADM group and retrieve members
foreach ($groupIndex in 0..($totalGroups - 1)) {
    $group = $admGroups[$groupIndex]

    # Calculate the number of groups remaining
    $groupsRemaining = $totalGroups - $groupIndex - 1

    # Update progress bar to show groups remaining
    Write-Progress -Activity "Processing ADM Groups" `
        -Status "$groupsRemaining groups remaining - Currently Processing: $($group.DisplayName)" `
        -PercentComplete ((($groupIndex + 1) / $totalGroups) * 100)

    # Process the current group's members and nested groups
    $ParentGroupName = $group.DisplayName
    $GroupID = $group.Id
    Process-GroupMembers -ParentGroupName $ParentGroupName -GroupId $GroupID
}

# Output the data as a table
$groupMemberDetails | Format-Table -AutoSize
