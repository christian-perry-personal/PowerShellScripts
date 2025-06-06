# Define registry path
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"

# Ensure the registry path exists
if (-not (Test-Path $regPath)) {
    Write-Output "Registry path does not exist. Creating it..."
    New-Item -Path $regPath -Force | Out-Null
}

# Function to enforce registry value
function Set-RegistryValue {
    param (
        [string]$Name
    )

    $currentValue = Get-ItemProperty -Path $regPath -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name -ErrorAction SilentlyContinue

    if ($null -eq $currentValue -or $currentValue -ne 0) {
        Write-Output "Setting $Name to 0..."
        Set-ItemProperty -Path $regPath -Name $Name -Value 0 -Type DWord
    } else {
        Write-Output "$Name is already set correctly."
    }
}

# Remediate both values
Set-RegistryValue -Name "NoWarningNoElevationOnInstall"
Set-RegistryValue -Name "UpdatePromptSettings"

Write-Output "Remediation complete."
