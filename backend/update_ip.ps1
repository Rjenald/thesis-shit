# Points .vscode/launch.json at this PC's current LAN address.
#
# A laptop gets a new address from each network's DHCP, and the app's server
# address is baked in at build time, so a stale one shows up in the app as
# "could not reach the Huni server".
#
# Kept as its own .ps1 rather than inlined in the .bat: batch and PowerShell
# disagree about escaping, and quoting a whole script through `powershell
# -Command` is how the earlier versions of this broke.

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$launch = Join-Path $repo '.vscode\launch.json'

$ip = Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
      Select-Object -First 1 -ExpandProperty IPAddress

if (-not $ip) {
    Write-Host 'No network address found - are you connected to Wi-Fi?'
    exit 1
}
if (-not (Test-Path $launch)) {
    Write-Host "Not found: $launch"
    Write-Host 'Run the app from VS Code once so it creates the launch config.'
    exit 1
}

$json = Get-Content $launch -Raw | ConvertFrom-Json
foreach ($cfg in $json.configurations) {
    # Replace only the server address; the YouTube key lives here too.
    $kept = @($cfg.args | Where-Object { $_ -notlike '--dart-define=PITCH_SERVER_IP=*' })
    $cfg.args = $kept + "--dart-define=PITCH_SERVER_IP=$ip"
}
# Written via .NET rather than Set-Content: PowerShell 5.1's -Encoding UTF8
# prepends a byte-order mark, and a BOM makes this file fail strict JSON
# parsers.
[System.IO.File]::WriteAllText(
    $launch,
    ($json | ConvertTo-Json -Depth 10),
    (New-Object System.Text.UTF8Encoding $false))

Write-Host ''
Write-Host "launch.json now points at $ip"
foreach ($cfg in $json.configurations) {
    Write-Host ("  {0}" -f $cfg.name)
}

# Check the servers are actually up on that address, so a wrong address and
# a stopped server don't look the same from the app.
Write-Host ''
foreach ($port in 8001, 8000) {
    $name = if ($port -eq 8001) { 'auth ' } else { 'pitch' }
    try {
        $r = Invoke-WebRequest -Uri "http://${ip}:${port}/health" -TimeoutSec 4 -UseBasicParsing
        Write-Host "  $name $port : up"
    } catch {
        try {
            $r = Invoke-WebRequest -Uri "http://${ip}:${port}/auth/health" -TimeoutSec 4 -UseBasicParsing
            Write-Host "  $name $port : up"
        } catch {
            Write-Host "  $name $port : NOT RESPONDING - run START_SERVERS.bat"
        }
    }
}
