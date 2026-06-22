# uninstall-native-host.ps1

$HostName = "com.aetherdesk.ai"
$keys = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HostName"
)

foreach ($key in $keys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Force
        Write-Host "Removed: $key" -ForegroundColor Green
    }
}
