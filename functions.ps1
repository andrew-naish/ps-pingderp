function Set-Window {
    [cmdletbinding(DefaultParameterSetName='Name')]
    param (
        [parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$True, ParameterSetName='Name')]
        [string]$ProcessName='*',

        [parameter(Mandatory=$True,ValueFromPipeline=$False, ParameterSetName='Id')]
        [int]$Id,

        [int]$X, [int]$Y, [int]$Width, [int]$Height, [switch]$Passthru
    )
    begin {
        try { 
            [void][Window]
        } 
        
        catch {
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

    process {
        $rectangle_struct = New-Object RECT
        
        if ( $PSBoundParameters.ContainsKey('Id') ) {
            $processes = Get-Process -Id $Id -ErrorAction SilentlyContinue
        } 
        else {
            $processes = Get-Process -Name "$ProcessName" -ErrorAction SilentlyContinue
        }
        if ( $null -eq $processes ) {
            if ( $PSBoundParameters['Passthru'] ) {
                Write-Warning 'No process match criteria specified'
            }
        } 
        else {
            $processes | ForEach-Object {
                $window_handle = $_.MainWindowHandle
                Write-Verbose "$($_.ProcessName) `(Id=$($_.Id), Handle=$window_handle`)"

                if ( $window_handle -eq [System.IntPtr]::Zero ) { return }
                [Window]::GetWindowRect($window_handle,[ref]$rectangle_struct) | Out-Null

                if (-NOT $PSBoundParameters.ContainsKey('X')) {
                    $X = $rectangle_struct.Left            
                }
                if (-NOT $PSBoundParameters.ContainsKey('Y')) {
                    $Y = $rectangle_struct.Top
                }
                if (-NOT $PSBoundParameters.ContainsKey('Width')) {
                    $Width = $rectangle_struct.Right - $rectangle_struct.Left
                }
                if (-NOT $PSBoundParameters.ContainsKey('Height')) {
                    $Height = $rectangle_struct.Bottom - $rectangle_struct.Top
                }

                [Window]::MoveWindow($window_handle, $x, $y, $Width, $Height,$True) | Out-Null

                if ( $PSBoundParameters['Passthru'] ) {
                    $rectangle_struct = New-Object RECT
                    [Window]::GetWindowRect($window_handle, [ref]$rectangle_struct) | Out-Null
                    
                    $Height = $rectangle_struct.Bottom - $rectangle_struct.Top
                    $Width = $rectangle_struct.Right  - $rectangle_struct.Left
                    $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                    $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $rectangle_struct.Left , $rectangle_struct.Top
                    $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $rectangle_struct.Right, $rectangle_struct.Bottom
                    
                    if ($rectangle_struct.Top -lt 0 -AND $rectangle_struct.Bottom -lt 0 -AND $rectangle_struct.Left -lt 0 -AND $rectangle_struct.Right -lt 0) 
                    { Write-Warning "$($_.ProcessName) `($($_.Id)`) is minimized! Coordinates will not be accurate." }

                    return [PSCustomObject] @{
                        Id = $_.Id
                        ProcessName = $_.ProcessName
                        Size = $Size
                        TopLeft = $TopLeft
                        BottomRight = $BottomRight
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
    
    $window_handle = (Get-Process -Id $Id).mainWindowHandle
    [Win32]::SetWindowText($window_handle, "$Title") | Out-Null

}
