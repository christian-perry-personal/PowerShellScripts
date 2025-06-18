# Define the Distribution List
$distributionList = "ENTER_DL_EMAIL_HERE"

# Get the members of the Distribution List
$members = Get-DistributionGroupMember -Identity $distributionList

# Create an array to store user details
$userDetails = @()

# Loop through each member and add their details to the array
foreach ($member in $members) {
    $userDetails += [PSCustomObject]@{
        Name  = $member.Name
        Email = $member.PrimarySmtpAddress
    }
}

# Export the user details to a CSV file
$userDetails | Export-Csv -Path "C:\Temp\ENTER_CSV_NAME_HERE.csv" -NoTypeInformation

Write-Host "User list exported successfully"
