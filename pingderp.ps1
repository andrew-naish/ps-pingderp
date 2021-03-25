. .\functions.ps1

# config
$config = [xml](Get-Content .\config.xml)
[int]$pos_x = $config.ConfigFile.General.PosX
[int]$pos_y_starting = $config.ConfigFile.General.PosY

# itterate derplings
$last_size = 0; $pos_y = $pos_y_starting
$derplings = $config.ConfigFile.PingDerplings
$derplings.derp | ForEach-Object {

    # spawn a derpling
    $spawned_process = Start-Process "cmd.exe" -PassThru -ArgumentList "/T:$($_.concol) /K mode con: cols=50 lines=$([int]($_.conlines)+1) & ping -t $($_.host)"
    $spawned_process_pid = $spawned_process.Id
    
    # have a nap, let windows catch up
    Start-Sleep -Milliseconds 200

    # size calculations and move the derpling into position
    $pos_y = $pos_y + $last_size
    $window = Set-Window -Id $spawned_process_pid -X $pos_x -Y $pos_y -Passthru
    $last_size = [int]($window.size -split ',')[1] -7 # -8 leaves no space at all, I think a little 1px space looks better though.

    # set name
    Set-WindowTitle -Id $spawned_process_pid -Title "Pingderp: $($_.name)"

}