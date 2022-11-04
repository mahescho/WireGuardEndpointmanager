<#
.DESCRIPTION
        WireGuard INIT script for use with MS endpointmanager

.NOTES
        Author: Matthias Henze, mahescho

        https://github.com/mahescho/WireGuardEndpointmanager

        License: BSD 3
#>


param ([string]$msi, [string]$tunnelname, [string]$webpath, [string]$webuser)

# parameters
# $msi = wireguar-2.3.1.msi
# $tunnelname = 'SITENAME'
# $webpath = "https://webserver.com/sitename/wg"
# $webuser = "user:password"

# constants
$tpath = $(Join-Path -Path $env:ProgramData -ChildPath "WireGuard")
$appname = "wginit"
$lfile = $(Join-Path -Path $env:temp -ChildPath "$appname.log")
$wgexe = "C:\Program Files\WireGuard\wireguard.exe"
$tunnelconffile = "$tpath\$tunnelname.conf"

Start-Transcript $lfile -Force

if (!(Test-Path -Path $tpath -ErrorAction SilentlyContinue)) {
    New-Item -Path $tpath -ItemType Directory -Force | Out-Null
}

try {
    # install MSI without GUI (DO_NOT_LAUNCH=1)

    $msiargs = @(
        "/i"
        "`"$msi`""
        "DO_NOT_LAUNCH=1"      
        "/qn"
    )
    start-process msiexec.exe -ArgumentList $msiargs -wait -PassThru -NoNewWindow

 
    # create start script userd by task
    
    $usrpw = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$webuser"))
    $wgstartscript = "$tpath\WGstart.ps1"
    New-Item -path $wgstartscript -ItemType File

    Set-Content $wgstartscript @"
`$H = @{ Authorization = "$usrpw" }
Invoke-WebRequest -Uri "$webpath/`$env:computername.conf" -OutFile "$tunnelconffile" -Headers `$H
Start-Process "$wgexe" -ArgumentList "/installtunnelservice", "$tunnelconffile" -Wait -NoNewWindow -PassThru
Start-Process sc.exe -ArgumentList "config", "WireGuardTunnel`$$tunnelname", "start=delayed-auto" -Wait -NoNewWindow -PassThru
Start-Service -Name WireGuardTunnel`$$tunnelname -ErrorAction SilentlyContinue
"@

    # auto update task
    schtasks /create /f /ru SYSTEM /sc ONSTART /tn "WireGuard Update" /tr "$wgexe /update"

    # start task for user (GUI replacement)

    $schtaskName = "WireGuard start"
    $schtaskDescription = "Tunnel starten"
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -Id "Author"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy Bypass -File $wgstartscript"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    $null = Register-ScheduledTask -TaskName $schtaskName -Action $action  -Principal $principal -Settings $settings -Description $schtaskDescription -Force

    $scheduler = New-Object -ComObject "Schedule.Service"
    $scheduler.Connect()
    $task = $scheduler.GetFolder("").GetTask($schtaskName)
    $scheduler = New-Object -ComObject "Schedule.Service"
    $scheduler.Connect()
    $task = $scheduler.GetFolder("").GetTask($schtaskName)
    $sec = $task.GetSecurityDescriptor(0xF)
    $sec = $sec + "(A;;GRGX;;;AU)"
    $task.SetSecurityDescriptor($sec, 0)

    # sopt task for user (GUI replacement)

    $schtaskName = "WireGuard stop"
    $schtaskDescription = "Tunnel stoppen"
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -Id "Author"
    $action = New-ScheduledTaskAction -Execute $wgexe -Argument "/uninstalltunnelservice $tunnelname"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    $null = Register-ScheduledTask -TaskName $schtaskName -Action $action  -Principal $principal -Settings $settings -Description $schtaskDescription -Force
    
    $scheduler = New-Object -ComObject "Schedule.Service"
    $scheduler.Connect()
    $task = $scheduler.GetFolder("").GetTask($schtaskName)
    $scheduler = New-Object -ComObject "Schedule.Service"
    $scheduler.Connect()
    $task = $scheduler.GetFolder("").GetTask($schtaskName)
    $sec = $task.GetSecurityDescriptor(0xF)
    $sec = $sec + "(A;;GRGX;;;AU)"
    $task.SetSecurityDescriptor($sec, 0)

    # create batchfiles as task triggers

    $f = "$tpath\WGstart.cmd"
    New-Item -path $f -ItemType File
    Set-Content $f 'schtasks /run /tn "WireGuard start"'

    $f = "$tpath\WGstop.cmd"
    New-Item -path $f -ItemType File
    Set-Content $f 'schtasks /run /tn "WireGuard stop"'

    # creat shortcuts on public desktop

    $WshShell = New-Object -comObject WScript.Shell

    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Start $tunnelname VPN.lnk")
    $Shortcut.TargetPath = "$tpath\WGstart.cmd"
    $Shortcut.IconLocation = "C:\windows\System32\SHELL32.dll, 296"
    $Shortcut.Save()
    
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Stop $tunnelname VPN.lnk")
    $Shortcut.TargetPath = "$tpath\WGstop.cmd"
    $Shortcut.IconLocation = "C:\windows\System32\SHELL32.dll, 131"
    $Shortcut.Save()

    Stop-Transcript
    exit 0
}
catch {
    $errorVar = $_.exception.messaage
    Write-Host $errorVar
    Stop-Transcript
    throw $errorVar
}

