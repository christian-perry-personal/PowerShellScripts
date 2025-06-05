$logPath = "C:\Logs"
$logFile = "$logPath\DellSoftwareRemoval.log"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory
}

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logMessage
}

$excludedApps = @("Dell Pair", "Dell Command | Update", "Dell Peripheral Manager", "Dell Command | Update for Windows Universal")
$installedApps = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Vendor LIKE '%Dell%'"

$unwantedApps = $installedApps | Where-Object { $excludedApps -notcontains $_.Name }

foreach ($app in $unwantedApps) {
    try {
        $appName = $app.Name
        $appIdentifyingNumber = $app.IdentifyingNumber
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $appIdentifyingNumber /quiet /norestart" -Wait
        Log-Message "Uninstalled $appName silently"
    } catch {
        $errorMessage = $_.Exception.Message
        Log-Message ("Failed to uninstall " + $appName + ": " + $errorMessage)
    }
}

Log-Message "Script execution completed."
