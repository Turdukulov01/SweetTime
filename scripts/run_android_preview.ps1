param(
  [switch]$NoResident
)

$ErrorActionPreference = "Stop"

$FlutterBin = "C:\Users\user\my_sdk_flutter\flutter\bin"
$Flutter = Join-Path $FlutterBin "flutter.bat"
$JdkRoot = "C:\Users\user\dev-tools\jdk-17"
$SdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb = Join-Path $SdkRoot "platform-tools\adb.exe"
$AvdName = "sweettime_pixel_36"

$env:JAVA_HOME = $JdkRoot
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:Path = @(
  $FlutterBin,
  (Join-Path $JdkRoot "bin"),
  (Join-Path $SdkRoot "cmdline-tools\latest\bin"),
  (Join-Path $SdkRoot "platform-tools"),
  (Join-Path $SdkRoot "emulator"),
  $env:Path
) -join ";"

function Get-ReadyAndroidDevice {
  if (-not (Test-Path $Adb)) {
    return $null
  }

  $lines = & $Adb devices
  foreach ($line in $lines) {
    if ($line -match "^(\S+)\s+device$") {
      return $Matches[1]
    }
  }

  return $null
}

$deviceId = Get-ReadyAndroidDevice
if (-not $deviceId) {
  & $Flutter emulators --launch $AvdName

  $deadline = (Get-Date).AddMinutes(5)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $deviceId = Get-ReadyAndroidDevice
    if ($deviceId) {
      break
    }
  }
}

if (-not $deviceId) {
  throw "Android emulator did not become available. Try closing old emulator windows and run this script again."
}

$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  $bootCompleted = (& $Adb -s $deviceId shell getprop sys.boot_completed 2>$null | Out-String).Trim()
  if ($bootCompleted -eq "1") {
    break
  }
  Start-Sleep -Seconds 5
}

$runArgs = @("run", "-d", $deviceId)
if ($NoResident) {
  $runArgs += "--no-resident"
}

& $Flutter @runArgs
