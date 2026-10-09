# Patches flutter_blue_plus_android to bypass CCCD descriptor write on ESP32 (0xFF01)
$path = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_blue_plus_android-7.0.4\android\src\main\java\com\lib\flutter_blue_plus\FlutterBluePlusPlugin.java"
if (Test-Path $path) {
    $content = Get-Content $path -Raw
    $target = 'BluetoothGattDescriptor cccd = getDescriptorFromArray(CCCD, characteristic.getDescriptors());'
    $hook = 'if (characteristic.getUuid().toString().toLowerCase().contains("ff01")) {'
    if (-not $content.Contains($hook) -and $content.Contains($target)) {
        $replacement = @"
if (characteristic.getUuid().toString().toLowerCase().contains("ff01")) {
                        log(LogLevel.INFO, "Skipping CCCD descriptor write for 0xFF01 (ESP32 notifications enabled locally)");
                        result.success(false);
                        return;
                    }

                    BluetoothGattDescriptor cccd = getDescriptorFromArray(CCCD, characteristic.getDescriptors());
"@
        $newContent = $content.Replace($target, $replacement)
        Set-Content -Path $path -Value $newContent -NoNewline
        Write-Host "[Patch] flutter_blue_plus_android patched successfully for ESP32!"
    } else {
        Write-Host "[Patch] Already patched."
    }
}
