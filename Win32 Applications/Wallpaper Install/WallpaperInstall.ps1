#Copy the PS1 File
# Variables
$Target = "C:\Temp\Scripts"
$Script = "DesktopBackround.ps1"

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force }

Copy-Item "DesktopBackground.ps1" -Destination "C:\Temp\Scripts" -Force

#copy your background
Copy-Item "Background.jpg" -Destination "C:\Temp\" -Force

#Load Default User Profile
reg load HKU\DEFAULT_USER C:\Users\Default\NTUSER.DAT
#Set Default Background using a run once that calls the ps1 script you just copied.
reg.exe add "HKU\DEFAULT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "DefaultBackground" /t REG_SZ /d "powershell.exe -executionpolicy Bypass -Windowstyle Hidden -file C:\Temp\Scripts\DesktopBackground.ps1" /f | Out-Host
#Unload Default User Profile
reg unload HKU\DEFAULT_USER
exit 0
