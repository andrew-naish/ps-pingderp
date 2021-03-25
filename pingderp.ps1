function Set-Window {
    [cmdletbinding(DefaultParameterSetName='Name')]
    Param (
        [parameter(Mandatory=$False,
            ValueFromPipelineByPropertyName=$True, ParameterSetName='Name')]
        [string]$ProcessName='*',
        [parameter(Mandatory=$True,
            ValueFromPipeline=$False,              ParameterSetName='Id')]
        [int]$Id,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [switch]$Passthru
    )
    Begin {
        Try { 
            [void][Window]
        } 
        
        Catch {
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class Window {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool GetWindowRect(
                IntPtr hWnd, out RECT lpRect);
    
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public extern static bool MoveWindow( 
                IntPtr handle, int x, int y, int width, int height, bool redraw);
    
            [DllImport("user32.dll")] 
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool ShowWindow(
                IntPtr handle, int state);
            }
            public struct RECT
            {
            public int Left;        // x position of upper-left corner
            public int Top;         // y position of upper-left corner
            public int Right;       // x position of lower-right corner
            public int Bottom;      // y position of lower-right corner
            }
"@
        }
    }
    Process {
        $Rectangle = New-Object RECT
        If ( $PSBoundParameters.ContainsKey('Id') ) {
            $Processes = Get-Process -Id $Id -ErrorAction SilentlyContinue
        } else {
            $Processes = Get-Process -Name "$ProcessName" -ErrorAction SilentlyContinue
        }
        if ( $null -eq $Processes ) {
            If ( $PSBoundParameters['Passthru'] ) {
                Write-Warning 'No process match criteria specified'
            }
        } else {
            $Processes | ForEach-Object {
                $Handle = $_.MainWindowHandle
                Write-Verbose "$($_.ProcessName) `(Id=$($_.Id), Handle=$Handle`)"
                if ( $Handle -eq [System.IntPtr]::Zero ) { return }
                $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
                If (-NOT $PSBoundParameters.ContainsKey('X')) {
                    $X = $Rectangle.Left            
                }
                If (-NOT $PSBoundParameters.ContainsKey('Y')) {
                    $Y = $Rectangle.Top
                }
                If (-NOT $PSBoundParameters.ContainsKey('Width')) {
                    $Width = $Rectangle.Right - $Rectangle.Left
                }
                If (-NOT $PSBoundParameters.ContainsKey('Height')) {
                    $Height = $Rectangle.Bottom - $Rectangle.Top
                }
                If ( $Return ) {
                    $Return = [Window]::MoveWindow($Handle, $x, $y, $Width, $Height,$True)
                }
                If ( $PSBoundParameters['Passthru'] ) {
                    $Rectangle = New-Object RECT
                    $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
                    If ( $Return ) {
                        $Height      = $Rectangle.Bottom - $Rectangle.Top
                        $Width       = $Rectangle.Right  - $Rectangle.Left
                        $Size        = New-Object System.Management.Automation.Host.Size        -ArgumentList $Width, $Height
                        $TopLeft     = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left , $Rectangle.Top
                        $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                        If ($Rectangle.Top    -lt 0 -AND 
                            $Rectangle.Bottom -lt 0 -AND
                            $Rectangle.Left   -lt 0 -AND
                            $Rectangle.Right  -lt 0) {
                            Write-Warning "$($_.ProcessName) `($($_.Id)`) is minimized! Coordinates will not be accurate."
                        }
                        $Object = [PSCustomObject]@{
                            Id          = $_.Id
                            ProcessName = $_.ProcessName
                            Size        = $Size
                            TopLeft     = $TopLeft
                            BottomRight = $BottomRight
                        }
                        $Object
                    }
                }
            }
        }
    }
}

function Set-WindowTitle ($Id, $Title) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    
    public static class Win32 {
      [DllImport("User32.dll", EntryPoint="SetWindowText")]
      public static extern int SetWindowText(IntPtr hWnd, string strTitle);
    }
"@
    
    $handle = (Get-Process -Id $Id).mainWindowHandle
    [Win32]::SetWindowText($handle, "$Title") | Out-Null

}

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