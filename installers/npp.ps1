# Instalează Notepad++ (ultima versiune stabilă)
Invoke-WebRequest -Uri "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/latest/download/npp.8.6.8.Installer.x64.exe" -OutFile "C:\\npp_installer.exe"
Start-Process "C:\\npp_installer.exe" -ArgumentList "/S" -Wait
Remove-Item "C:\\npp_installer.exe"
