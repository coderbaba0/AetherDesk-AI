# system-health.ps1
# Safe Windows Wi-Fi, Bluetooth and System Health collector

function Get-WifiStatus {
    $wifiText = ""

    try {
        $wifiText += "=== WIFI STATUS ===`n"
        $wifiText += (netsh wlan show interfaces | Out-String)
    }
    catch {
        $wifiText += "Wi-Fi status read failed: $($_.Exception.Message)`n"
    }

    try {
        $wifiText += "`n=== NETWORK ADAPTERS ===`n"
        $wifiText += (Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed | Out-String)
    }
    catch {
        $wifiText += "Network adapter read failed: $($_.Exception.Message)`n"
    }

    try {
        $wifiText += "`n=== IP CONFIGURATION ===`n"
        $wifiText += (Get-NetIPConfiguration | Out-String)
    }
    catch {
        $wifiText += "IP config read failed: $($_.Exception.Message)`n"
    }

    try {
        $wifiText += "`n=== INTERNET TEST ===`n"
        $internet = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet
        $dns = Test-Connection -ComputerName google.com -Count 2 -Quiet

        $wifiText += "Ping 8.8.8.8: $internet`n"
        $wifiText += "DNS google.com: $dns`n"
    }
    catch {
        $wifiText += "Internet test failed: $($_.Exception.Message)`n"
    }

    return $wifiText
}

function Get-BluetoothStatus {
    $btText = ""

    $btText += "=== BLUETOOTH DEVICES ===`n"

    try {
        $btDevices = Get-PnpDevice -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FriendlyName -like "*Bluetooth*" -or
                $_.Name -like "*Bluetooth*" -or
                $_.InstanceId -like "*BTH*"
            } |
            Select-Object Status, Class, FriendlyName, InstanceId

        if ($btDevices) {
            $btText += ($btDevices | Out-String)
        }
        else {
            $btText += "No Bluetooth device found by PnP search.`n"
        }
    }
    catch {
        $btText += "Bluetooth device read failed: $($_.Exception.Message)`n"
    }

    try {
        $btText += "`n=== BLUETOOTH SERVICES ===`n"

        $btServices = Get-Service -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "*bth*" -or
                $_.Name -like "*Bluetooth*" -or
                $_.DisplayName -like "*Bluetooth*"
            } |
            Select-Object Name, DisplayName, Status, StartType

        if ($btServices) {
            $btText += ($btServices | Out-String)
        }
        else {
            $btText += "No Bluetooth service found.`n"
        }
    }
    catch {
        $btText += "Bluetooth service read failed: $($_.Exception.Message)`n"
    }

    return $btText
}

function Get-SystemHealthStatus {
    $sysText = ""

    try {
        $sysText += "=== SYSTEM INFO ===`n"
        $os = Get-CimInstance Win32_OperatingSystem
        $computer = Get-CimInstance Win32_ComputerSystem

        $totalRamGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        $freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRamGB = [math]::Round($totalRamGB - $freeRamGB, 2)
        $uptime = (Get-Date) - $os.LastBootUpTime

        $sysText += "Computer Name: $env:COMPUTERNAME`n"
        $sysText += "Windows: $($os.Caption)`n"
        $sysText += "Version: $($os.Version)`n"
        $sysText += "Total RAM GB: $totalRamGB`n"
        $sysText += "Used RAM GB: $usedRamGB`n"
        $sysText += "Free RAM GB: $freeRamGB`n"
        $sysText += "Uptime: $([math]::Round($uptime.TotalHours, 2)) hours`n"
    }
    catch {
        $sysText += "System info read failed: $($_.Exception.Message)`n"
    }

    try {
        $sysText += "`n=== CPU ===`n"
        $cpu = Get-CimInstance Win32_Processor |
            Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, LoadPercentage

        $sysText += ($cpu | Out-String)
    }
    catch {
        $sysText += "CPU read failed: $($_.Exception.Message)`n"
    }

    try {
        $sysText += "`n=== DISK SPACE ===`n"

        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,
                VolumeName,
                @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},
                @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}},
                @{Name="FreePercent";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}

        $sysText += ($disks | Out-String)
    }
    catch {
        $sysText += "Disk read failed: $($_.Exception.Message)`n"
    }

    try {
        $sysText += "`n=== BATTERY ===`n"

        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue |
            Select-Object Name, BatteryStatus, EstimatedChargeRemaining, EstimatedRunTime

        if ($battery) {
            $sysText += ($battery | Out-String)
        }
        else {
            $sysText += "No battery found. Probably desktop system.`n"
        }
    }
    catch {
        $sysText += "Battery read failed: $($_.Exception.Message)`n"
    }

    try {
        $sysText += "`n=== TOP MEMORY PROCESSES ===`n"

        $processes = Get-Process |
            Sort-Object WorkingSet -Descending |
            Select-Object -First 10 ProcessName, Id, @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet/1MB,2)}}

        $sysText += ($processes | Out-String)
    }
    catch {
        $sysText += "Process read failed: $($_.Exception.Message)`n"
    }

    return $sysText
}

function Get-FullSystemHealthContext {
    $report = ""
    $report += Get-WifiStatus
    $report += "`n`n"
    $report += Get-BluetoothStatus
    $report += "`n`n"
    $report += Get-SystemHealthStatus
    return $report
}
