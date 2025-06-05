#Define list of excluded apps and method to detect all installed Dell apps
$excludedApps = @("Dell Pair", "Dell Command | Update", "Dell Peripheral Manager", "Dell Command | Update for Windows Universal")
$installedApps = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Vendor LIKE '%Dell%'"

$unwantedApps = $installedApps | Where-Object { $excludedApps -notcontains $_.Name }

#If statement to detect unwanted Dell Apps
if ($unwantedApps) {
    Write-Output "Unwanted Dell software detected"
    exit 1
} else {
    Write-Output "No unwanted Dell software detected"
    exit 0
}
