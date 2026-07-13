param(
  [string]$DeviceId = "",
  [switch]$BuildOnly,
  [switch]$Debug
)

$ErrorActionPreference = "Stop"

$FlutterBin = "C:\Users\user\my_sdk_flutter\flutter\bin"
$Flutter = Join-Path $FlutterBin "flutter.bat"
$JdkRoot = "C:\Users\user\dev-tools\jdk-17"
$SdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb = Join-Path $SdkRoot "platform-tools\adb.exe"
$PackageName = "com.example.sweettime"

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

if (-not (Test-Path $Flutter)) {
  throw "Flutter was not found at $Flutter"
}

if (-not (Test-Path $Adb)) {
  throw "ADB was not found at $Adb"
}

& $Flutter config --jdk-dir="$JdkRoot" | Out-Null

$mode = if ($Debug) { "debug" } else { "release" }
& $Flutter build apk "--$mode"
if ($LASTEXITCODE -ne 0) {
  throw "Flutter APK build failed."
}

$apkName = if ($Debug) { "app-debug.apk" } else { "app-release.apk" }
$apkPath = Join-Path (Get-Location) "build\app\outputs\flutter-apk\$apkName"

if (-not (Test-Path $apkPath)) {
  throw "APK was not created at $apkPath"
}

Write-Host "APK ready: $apkPath"

if ($BuildOnly) {
  exit 0
}

$adbLines = & $Adb devices -l
$readyDevices = @()
$unauthorizedDevices = @()

foreach ($line in $adbLines) {
  if ($line -match "^(\S+)\s+(device|unauthorized|offline)\b") {
    $id = $Matches[1]
    $state = $Matches[2]

    if ($id.StartsWith("emulator-")) {
      continue
    }

    if ($state -eq "device") {
      $readyDevices += $id
    } elseif ($state -eq "unauthorized") {
      $unauthorizedDevices += $id
    }
  }
}

if ($unauthorizedDevices.Count -gt 0) {
  throw "Phone is connected but not authorized. Unlock the phone and tap Allow USB debugging, then run this script again."
}

if ($DeviceId) {
  if ($readyDevices -notcontains $DeviceId) {
    throw "Device $DeviceId is not available. Connected physical devices: $($readyDevices -join ', ')"
  }
  $targetDevice = $DeviceId
} else {
  if ($readyDevices.Count -eq 0) {
    throw "No USB phone found. Enable Developer options + USB debugging, connect the phone by USB, accept the prompt, then run this script again."
  }

  if ($readyDevices.Count -gt 1) {
    throw "Multiple USB phones found: $($readyDevices -join ', '). Re-run with -DeviceId <id>."
  }

  $targetDevice = $readyDevices[0]
}

$installOutput = & $Adb -s $targetDevice install -r $apkPath 2>&1
$installExitCode = $LASTEXITCODE
$installOutput | ForEach-Object { Write-Host $_ }

if ($installExitCode -ne 0) {
  $message = ($installOutput | Out-String)
  if ($message -match "INSTALL_FAILED_USER_RESTRICTED|Install canceled by user") {
    throw "Phone blocked USB install. On the phone enable Developer options > Install via USB and accept any install prompt, then run this script again."
  }

  throw "ADB install failed."
}

& $Adb -s $targetDevice shell monkey -p $PackageName 1
if ($LASTEXITCODE -ne 0) {
  throw "App was installed, but Android did not launch it automatically. Open SweetTime manually from the app drawer."
}

Write-Host "SweetTime preview installed and opened on $targetDevice."
