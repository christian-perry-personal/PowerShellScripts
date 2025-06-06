# Define registry path
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"

# Function to check a registry value
function Check-RegistryValue {
    param (
        [string]$Name
    )

    $value = Get-ItemProperty -Path $regPath -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue

    if ($null -eq $value) {
        Write-Output "$Name is not defined. Remediation required."
    } elseif ($value -eq 0) {
        Write-Output "$Name is set correctly to 0."
    } else {
        Write-Output "$Name is set incorrectly to $value. Remediation required."
    }
}

# Check both values
if (Test-Path $regPath) {
    Check-RegistryValue -Name "NoWarningNoElevationOnInstall"
    Check-RegistryValue -Name "UpdatePromptSettings"
} else {
    Write-Output "Registry path does not exist. Remediation required."
}
