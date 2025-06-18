# Ensure Microsoft Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "Device.ReadWrite.All", "Directory.Read.All"

# Import the CSV file
$devices = Import-Csv -Path "C:\Path\To\devices.csv"

foreach ($device in $devices) {
    $deviceName = $device.DeviceName

    # Find the device by display name
    $foundDevice = Get-MgDevice -Filter "displayName eq '$deviceName'"

    if ($foundDevice) {
        # Delete the device
        Remove-MgDevice -DeviceId $foundDevice.Id
        Write-Host "Deleted device: $deviceName"
    } else {
        Write-Warning "Device not found: $deviceName"
    }
}