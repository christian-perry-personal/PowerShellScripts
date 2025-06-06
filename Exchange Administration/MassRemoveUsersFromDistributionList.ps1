# Connect to Exchange Online
Connect-ExchangeOnline

# Define the distribution list
$DistributionList = "ENTER_DL_EMAIL_HERE"

# Get all members of the distribution list
$Members = Get-DistributionGroupMember -Identity $DistributionList

# Remove each member from the distribution list
foreach ($Member in $Members) {
    Remove-DistributionGroupMember -Identity $DistributionList -Member $Member.Alias -Confirm:$false
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
