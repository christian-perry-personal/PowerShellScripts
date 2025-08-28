<#
.SYNOPSIS
Bulk-create Entra ID users from a CSV, with optional license assignment, group membership, and manager relationships.

.PARAMETER CsvPath
Path to the CSV file (see sample schema in the README section).

.PARAMETER DefaultUsageLocation
Fallback UsageLocation (e.g., US) if not provided per row. Required if assigning licenses and the row is missing a value.

.PARAMETER SkipExisting
If a user (by UPN) already exists, skip it. (Default)

.PARAMETER UpdateIfExists
If a user exists, update provided fields instead of skipping.

.PARAMETER GeneratePasswordLength
Length of an auto-generated password when Password is not supplied.

.PARAMETER WhatIf
Simulate actions without making changes.

.EXAMPLE
.\New-EntraUsersFromCsv.ps1 -CsvPath .\new-users.csv -DefaultUsageLocation US -WhatIf

.EXAMPLE
.\New-EntraUsersFromCsv.ps1 -CsvPath .\new-users.csv -UpdateIfExists
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,

    [string]$DefaultUsageLocation = "US",

    [switch]$SkipExisting,

    [switch]$UpdateIfExists,

    [ValidateRange(8,128)]
    [int]$GeneratePasswordLength = 16
)

function Ensure-Graph {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Verbose "Installing Microsoft.Graph module..."
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
    }
    if (-not (Get-MgContext)) {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
        # Request scopes needed for creation, licensing, group membership, and manager relations
        Connect-MgGraph -Scopes @(
            "User.ReadWrite.All",
            "Directory.Read.All",
            "Group.ReadWrite.All"
        )
        Select-MgProfile -Name "v1.0"
    }
}

function New-RandomSecurePassword {
    param([int]$Length = 16)
    # Generate a complex password that typically satisfies default tenant policies
    $charsUpper =  [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $charsLower =  [char[]]"abcdefghijklmnopqrstuvwxyz"
    $charsDigits = [char[]]"0123456789"
    $charsPunct =  [char[]]"!@#$%^&*()-_=+[]{};:,.?/"

    $pool = $charsUpper + $charsLower + $charsDigits + $charsPunct
    $rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] ($Length)
    $rand.GetBytes($bytes) | Out-Null

    $pwdChars = for ($i=0; $i -lt $Length; $i++) { $pool[$bytes[$i] % $pool.Length] }

    # Ensure presence of each category
    $pwdChars[0] = $charsUpper[(Get-Random -Max $charsUpper.Length)]
    $pwdChars[1] = $charsLower[(Get-Random -Max $charsLower.Length)]
    $pwdChars[2] = $charsDigits[(Get-Random -Max $charsDigits.Length)]
    $pwdChars[3] = $charsPunct[(Get-Random -Max $charsPunct.Length)]
    -join ($pwdChars | Sort-Object {Get-Random})
}

function Get-SkuMap {
    # Returns a hashtable of SKU part number -> SkuId GUID
    $map = @{}
    try {
        $skus = Get-MgSubscribedSku -All
        foreach ($s in $skus) {
            # SkuPartNumber example: ENTERPRISEPACK
            $map[$s.SkuPartNumber] = $s.SkuId
        }
    } catch {
        Write-Warning "Could not retrieve subscribed SKUs. License assignment will be skipped. $_"
    }
    return $map
}

function Get-UserByUpn {
    param([string]$Upn)
    try {
        return Get-MgUser -UserId $Upn -ErrorAction Stop
    } catch {
        return $null
    }
}

function Set-ManagerIfProvided {
    param(
        [string]$UserId,
        [string]$ManagerUpn
    )
    if ([string]::IsNullOrWhiteSpace($ManagerUpn)) { return }

    $mgr = Get-UserByUpn -Upn $ManagerUpn
    if (-not $mgr) {
        Write-Warning "  Manager '$ManagerUpn' not found. Skipping manager set."
        return
    }

    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($mgr.Id)"
    }

    if ($PSCmdlet.ShouldProcess($UserId, "Set manager to $ManagerUpn")) {
        try {
            Set-MgUserManagerByRef -UserId $UserId -BodyParameter $body -ErrorAction Stop
            Write-Host "  Manager set: $ManagerUpn" -ForegroundColor Green
        } catch {
            Write-Warning "  Failed to set manager: $_"
        }
    }
}

function Assign-Licenses {
    param(
        [string]$UserId,
        [string[]]$SkuPartNumbers,
        [hashtable]$SkuMap
    )
    if (-not $SkuPartNumbers -or $SkuPartNumbers.Count -eq 0) { return }
    if (-not $SkuMap -or $SkuMap.Count -eq 0) {
        Write-Warning "  No SKU map available; skipping license assignment."
        return
    }

    $add = @()
    foreach ($sku in $SkuPartNumbers) {
        $sku = $sku.Trim()
        if ([string]::IsNullOrWhiteSpace($sku)) { continue }
        if ($SkuMap.ContainsKey($sku)) {
            $add += @{ SkuId = $SkuMap[$sku] }
        } else {
            Write-Warning "  SKU not found in tenant: '$sku' (skipping)"
        }
    }
    if ($add.Count -eq 0) { return }

    if ($PSCmdlet.ShouldProcess($UserId, "Assign licenses: $($SkuPartNumbers -join ', ')")) {
        try {
            # Using Add-MgUserLicense to add licenses; RemoveLicenses is empty here
            Add-MgUserLicense -UserId $UserId -AddLicenses $add -RemoveLicenses @() -ErrorAction Stop
            Write-Host "  Licenses assigned: $($SkuPartNumbers -join ', ')" -ForegroundColor Green
        } catch {
            Write-Warning "  Failed to assign licenses: $_"
        }
    }
}

# --- Main ---
Ensure-Graph

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$rows = Import-Csv -Path $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    throw "CSV has no rows."
}

$skuMap = Get-SkuMap
$results = New-Object System.Collections.Generic.List[object]

foreach ($r in $rows) {
    $upn = $r.UserPrincipalName
    if ([string]::IsNullOrWhiteSpace($upn)) {
        Write-Warning "Row missing UserPrincipalName. Skipping."
        continue
    }

    Write-Host "Processing: $upn" -ForegroundColor Cyan
    $existing = Get-UserByUpn -Upn $upn

    # Build properties
    $displayName  = $r.DisplayName
    $mailNickname = $r.MailNickname
    if ([string]::IsNullOrWhiteSpace($mailNickname) -and -not [string]::IsNullOrWhiteSpace($upn)) {
        $mailNickname = ($upn.Split('@')[0])
    }

    $usageLocation = if ($r.UsageLocation) { $r.UsageLocation } else { $DefaultUsageLocation }
    $password = if ($r.Password) { $r.Password } else { New-RandomSecurePassword -Length $GeneratePasswordLength }
    $forceChange = [System.Convert]::ToBoolean($r.ForcePasswordChange, [System.Globalization.CultureInfo]::InvariantCulture)
    $acctEnabled = if ($null -ne $r.AccountEnabled -and $r.AccountEnabled -ne "") {
        [System.Convert]::ToBoolean($r.AccountEnabled, [System.Globalization.CultureInfo]::InvariantCulture)
    } else { $true }

    $businessPhones = @()
    if ($r.OfficePhone) { $businessPhones = @($r.OfficePhone) }

    $createParams = @{
        AccountEnabled = $acctEnabled
        DisplayName    = $displayName
        MailNickname   = $mailNickname
        UserPrincipalName = $upn
        GivenName      = $r.GivenName
        Surname        = $r.Surname
        UsageLocation  = $usageLocation
        JobTitle       = $r.JobTitle
        Department     = $r.Department
        StreetAddress  = $r.StreetAddress
        City           = $r.City
        State          = $r.State
        PostalCode     = $r.PostalCode
        Country        = $r.Country
        MobilePhone    = $r.MobilePhone
        BusinessPhones = $businessPhones
        EmployeeId     = $r.EmployeeId
        PasswordProfile = @{
            Password = $password
            ForceChangePasswordNextSignIn = $forceChange
        }
    }

    # Remove null/empty keys (Graph can be picky)
    foreach ($k in @($createParams.Keys)) {
        if ($null -eq $createParams[$k] -or ($createParams[$k] -is [string] -and [string]::IsNullOrWhiteSpace($createParams[$k]))) {
            $createParams.Remove($k) | Out-Null
        }
    }

    $action = $null
    $userObj = $null
    $errorMsg = $null

    if ($existing -and $UpdateIfExists) {
        $action = "Update"
        if ($PSCmdlet.ShouldProcess($upn, "Update user")) {
            try {
                # For updates, remove password profile unless explicitly changing it
                $updateParams = $createParams.Clone()
                $updateParams.Remove("PasswordProfile") | Out-Null

                Update-MgUser -UserId $upn @updateParams -ErrorAction Stop
                $userObj = Get-UserByUpn -Upn $upn
                Write-Host "  Updated user." -ForegroundColor Green
            } catch {
                $errorMsg = $_.Exception.Message
                Write-Warning "  Failed to update user: $errorMsg"
            }
        }
    } elseif ($existing -and $SkipExisting) {
        $action = "SkipExisting"
        Write-Host "  User already exists; skipping (use -UpdateIfExists to update)." -ForegroundColor Yellow
        $userObj = $existing
    } elseif ($existing) {
        $action = "ExistsNoAction"
        Write-Host "  User already exists; no action (use -SkipExisting or -UpdateIfExists)." -ForegroundColor Yellow
        $userObj = $existing
    } else {
        $action = "Create"
        if ($PSCmdlet.ShouldProcess($upn, "Create user")) {
            try {
                $userObj = New-MgUser @createParams -ErrorAction Stop
                Write-Host "  Created user." -ForegroundColor Green
                Write-Host "  Temporary password: $password" -ForegroundColor Yellow
            } catch {
                $errorMsg = $_.Exception.Message
                Write-Warning "  Failed to create user: $errorMsg"
            }
        }
    }

    # Post-actions only if we have a user object and creation/update succeeded
    if ($userObj) {
        # Manager
        if ($r.ManagerUPN) {
            Set-ManagerIfProvided -UserId $userObj.Id -ManagerUpn $r.ManagerUPN
        }

        # Groups
        $groupIds = @()
        if ($r.GroupObjectIds) {
            $groupIds = $r.GroupObjectIds -split ';'
        }
        if ($groupIds.Count -gt 0) {
        }

        # Licenses
        $skus = @()
        if ($r.LicenseSkuPartNumbers) {
            $skus = $r.LicenseSkuPartNumbers -split ';'
        }
        if ($skus.Count -gt 0) {
            # Ensure UsageLocation present for license assignment
            if (-not $userObj.UsageLocation -and -not $usageLocation) {
                Write-Warning "  UsageLocation required for license assignment. Skipping licenses."
            } else {
                Assign-Licenses -UserId $userObj.Id -SkuPartNumbers $skus -SkuMap $skuMap
            }
        }
    }

    $results.Add([PSCustomObject]@{
        UserPrincipalName = $upn
        Action            = $action
        Success           = [string]::IsNullOrEmpty($errorMsg)
        Error             = $errorMsg
    })
}

# Output summary and write a CSV log next to input
$summary = $results | Group-Object Action | Select-Object Name,Count
$summary | Format-Table -AutoSize

$logPath = [System.IO.Path]::ChangeExtension((Resolve-Path $CsvPath).Path, ".results.csv")
$results | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "`nDetailed results written to: $logPath" -ForegroundColor Cyan
