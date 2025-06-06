# Connect to Exchange Online
Connect-ExchangeOnline -Credential $UserCredential

# Define the distribution list
$DistributionList = "ENTER_DL_EMAIL_HERE"

# Import users from CSV file
$CSVPath = "C:\Temp\ENTER_CSV_NAME_HERE.csv"
$Users = Import-Csv -Path $CSVPath

# Add each user to the distribution list
foreach ($User in $Users) {
    Add-DistributionGroupMember -Identity $DistributionList -Member $User.EmailAddress
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
