# Connect to Exchange Online, remember to use rsa account
Connect-ExchangeOnline

# List of Distribution Lists to delete, edit this line with DL emails. Emails should be in "" and have a comma between each entry
# "DL1@Email.com", "DL2@Email.com"
$distributionLists = @("ENTER_DL_EMAIL(S)_HERE")

# Loop through each Distribution List and delete it
foreach ($dl in $distributionLists) {
    Remove-DistributionGroup -Identity $dl -Confirm:$false
    Write-Host "Deleted Distribution List: $dl"
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
