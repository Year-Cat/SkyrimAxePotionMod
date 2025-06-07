#Requires -Version 5

# args
param (
    [Parameter(Mandatory)][ValidateSet('COPY', 'SOURCEGEN', 'DISTRIBUTE')][string]$Mode,
    [string]$Version,
    [string]$Path,
    [string]$Project
)


$ErrorActionPreference = "Stop"

$Folder = $PSScriptRoot | Split-Path -Leaf
$SourceExt = @('.asm', '.c', '.cc', '.cpp', '.cxx', '.def', '.h', '.hpp', '.hxx', 'inc', '.inl', '.ixx')
$ConfigExt = @('.ini', '.json', '.toml', '.xml')
$DocsExt = @('.md')

function Resolve-Files {
    param (
        [Parameter(ValueFromPipeline)][string]$a_parent = $PSScriptRoot,
        [string[]]$a_directory = @('include', 'src', 'test')
    )
    
    process {
        Push-Location $PSScriptRoot
        $_generated = [System.Collections.ArrayList]::new()

        try {
            foreach ($directory in $a_directory) {
                if (!$env:RebuildInvoke) {
                    Write-Host "`t[$a_parent/$directory]"
                }

                Get-ChildItem "$a_parent/$directory" -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    ($_.Extension -in ($SourceExt + $DocsExt)) -and 
                    ($_.Name -notmatch 'Plugin.h|Version.h')
                } | Resolve-Path -Relative | ForEach-Object {
                    if (!$env:RebuildInvoke) {
                        Write-Host "`t`t<$_>"
                    }
                    $_generated.Add("`n`t`"$($_.Substring(2) -replace '\\', '/')`"") | Out-Null
                }
            }               
            
            Get-ChildItem "$a_parent" -File -ErrorAction SilentlyContinue | Where-Object {
                ($_.Extension -in ($ConfigExt + $DocsExt)) -and 
                ($_.Name -notmatch 'cmake|vcpkg')
            } | Resolve-Path -Relative | ForEach-Object {
                if (!$env:RebuildInvoke) {
                    Write-Host "`t`t<$_>"
                }
                $_generated.Add("`n`t`"$($_.Substring(2) -replace '\\', '/')`"") | Out-Null
            }
        }
        finally {
            Pop-Location
        }

        return $_generated
    }
}


Write-Host "`n`t<$Folder> [$Mode]"


# @@COPY
if ($Mode -eq 'COPY') {
    # process newly added files
    $BuildFolder = Get-ChildItem (Get-Item $Path).Parent.Parent.FullName "$Project.sln" -Depth 2 -File -Exclude ('*CMakeFiles*', '*CLib*')
    $NewFiles = Get-ChildItem $BuildFolder.DirectoryName -File | Where-Object { $_.Extension -in $SourceExt }
    if ($NewFiles) {
        # trigger ZERO_CHECK
        $NewFiles | Move-Item -Destination "$PSScriptRoot/src" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
        [IO.File]::WriteAllText("$PSScriptRoot/CMakeLists.txt", [IO.File]::ReadAllText("$PSScriptRoot/CMakeLists.txt"))
    }

    # Build Target
    Write-Host "`t$Folder $Version"
    $vcpkg = [IO.File]::ReadAllText("$PSScriptRoot/vcpkg.json") | ConvertFrom-Json
    $Install = $vcpkg.'features'.'mo2-install'.'description'
    $ProjectCMake = [IO.File]::ReadAllText("$PSScriptRoot/CMakeLists.txt")
    $OldVersion = [regex]::match($ProjectCMake, '(?s)(?:(?<=\sVERSION\s)(.*?)(?=\s+))').Groups[1].Value


    Add-Type -AssemblyName Microsoft.VisualBasic
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $MsgBox = New-Object System.Windows.Forms.Form -Property @{
        TopLevel        = $true
        ClientSize      = '350, 305'
        Text            = $Project
        StartPosition   = 'CenterScreen'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        Font            = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    }
    
    $Message = New-Object System.Windows.Forms.ListBox -Property @{
        ClientSize = '225, 150'
        Location   = New-Object System.Drawing.Point(20, 20)
    }
    
    function Log {
        param (
            [Parameter(ValueFromPipeline)][string]$a_log
        )

        process {
            $Message.Items.Add($a_log)
            $Message.SelectedIndex = $Message.Items.Count - 1;
            $Message.SelectedIndex = -1;
        }
    }
    
    function Copy-Mod {
        param (
            $Data
        )

        New-Item -Type Directory "$Data/SKSE/Plugins" -Force | Out-Null

        # binary
        Copy-Item "$Path/$Project.dll" "$Data/SKSE/Plugins/$Project.dll" -Force
        "- Binary files copied" | Log

        # pdb
        Copy-Item "$Path/$Project.pdb" "$Data/SKSE/Plugins/$Project.pdb" -Force
        "- PDB files copied" | Log

        # configs
        Get-ChildItem $PSScriptRoot | Where-Object {
            ($_.Extension -in $ConfigExt) -and 
            ($_.Name -notmatch 'CMake|vcpkg')
        } | ForEach-Object {
            Copy-Item $_.FullName "$Data/SKSE/Plugins/$($_.Name)" -Force
            "- Configuration files copied" | Log
        }

        # shockwave
        if (Test-Path "$PSScriptRoot/Interface/*.swf" -PathType Leaf) {
            New-Item -Type Directory "$Data/Interface" -Force | Out-Null
            Copy-Item "$PSScriptRoot/Interface" "$Data" -Recurse -Force
            "- Shockwave files copied" | Log
        }

        # papyrus
        if (Test-Path "$PSScriptRoot/Scripts/*.pex" -PathType Leaf) {
            New-Item -Type Directory "$Data/Scripts" -Force | Out-Null
            xcopy.exe "$PSScriptRoot/Scripts" "$Data/Scripts" /C /I /S /E /Y
            "- Papyrus scripts copied" | Log
        }
        if (Test-Path "$PSScriptRoot/Scripts/Source/*.psc" -PathType Leaf) {
            New-Item -Type Directory "$Data/Scripts/Source" -Force | Out-Null
            xcopy.exe "$PSScriptRoot/Scripts/Source" "$Data/Scripts/Source" /C /I /S /E /Y
            "- Papyrus scripts copied" | Log
        }
    }

    $BtnCopyMO2 = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Copy to MO2'
        Location   = New-Object System.Drawing.Point(260, 19)
        BackColor  = 'Cyan'
        Add_Click  = {
            foreach ($runtime in @("$($env:MO2SkyrimAEPath)/mods", "$($env:MO2SkyrimSEPath)/mods", "$($env:MO2SkyrimVRPath)/mods")) {
                if (Test-Path $runtime -PathType Container) {
                    Copy-Mod "$runtime/$Install"
                }
            }
            "- Copied to MO2." | Log
        }
    }
    
    $BtnCopyData = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Copy to Data'
        Location   = New-Object System.Drawing.Point(260, 74)
        Add_Click  = {
            foreach ($runtime in @("$($env:SkyrimAEPath)/data", "$($env:SkyrimSEPath)/data", "$($env:SkyrimVRPath)/data")) {
                if (Test-Path $runtime -PathType Container) {
                    Copy-Mod "$runtime"
                }
            }
            "- Copied to game data." | Log
        }
    }
    
    $BtnRemoveData = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Remove in Data'
        Location   = New-Object System.Drawing.Point(260, 129)
        Add_Click  = {
            foreach ($runtime in @("$($env:SkyrimAEPath)/data", "$($env:SkyrimSEPath)/data", "$($env:SkyrimVRPath)/data")) {
                if (Test-Path "$runtime/SKSE/Plugins/$Project.dll" -PathType Leaf) {
                    Remove-Item "$runtime/SKSE/Plugins/$Project.dll" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
                }
            }
            "- Removed from game data." | Log
        }
    }
    
    $BtnOpenFolder = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Show in Explorer'
        Location   = New-Object System.Drawing.Point(260, 185)
        BackColor  = 'Yellow'
        Add_Click  = {
            Invoke-Item $Path
        }
    }
    
    $BtnLaunchSKSEAE = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'SKSE (AE)'
        Location   = New-Object System.Drawing.Point(20, 185)
        Add_Click  = {
            Push-Location $env:SkyrimAEPath
            Start-Process ./SKSE64_loader.exe
            Pop-Location

            "- SKSE (AE) Launched." | Log
        }
    }
    if (!(Test-Path "$env:SkyrimAEPath/skse64_loader.exe" -PathType Leaf)) {
        $BtnLaunchSKSEAE.Enabled = $false
    }

    $BtnLaunchSKSESE = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'SKSE (SE)'
        Location   = New-Object System.Drawing.Point(100, 185)
        Add_Click  = {
            Push-Location $env:SkyrimSEPath
            Start-Process ./SKSE64_loader.exe
            Pop-Location

            "- SKSE (SE) Launched." | Log
        }
    }
    if (!(Test-Path "$env:SkyrimSEPath/skse64_loader.exe" -PathType Leaf)) {
        $BtnLaunchSKSESE.Enabled = $false
    }
 
    $BtnLaunchSKSEVR = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'SKSE (VR)'
        Location   = New-Object System.Drawing.Point(180, 185)
        Add_Click  = {
            Push-Location $env:SkyrimVRPath
            Start-Process ./SKSE64_loader.exe
            Pop-Location

            "- SKSE (VR) Launched." | Log
        }
    }
    if (!(Test-Path "$env:SkyrimVRPath/skse64_loader.exe" -PathType Leaf)) {
        $BtnLaunchSKSEVR.Enabled = $false
    }
    
    $BtnBuildPapyrus = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Build Papyrus'
        Location   = New-Object System.Drawing.Point(20, 240)
        Add_Click  = {
            $BtnBuildPapyrus.Text = 'Compiling...'
            
            $Invocation = "`"$($env:SkyrimSEPath)/Papyrus Compiler/PapyrusCompiler.exe`" `"$PSScriptRoot/Scripts/Source`" -f=`"$env:SkyrimSEPath/Papyrus Compiler/TESV_Papyrus_Flags.flg`" -i=`"$env:SkyrimSEPath/Data/Scripts/Source;$PSScriptRoot/Scripts;$PSScriptRoot/Scripts/Source`" -o=`"$PSScriptRoot/Scripts`" -a -op -enablecache -t=`"4`""
            Start-Process cmd.exe -ArgumentList "/k $Invocation && pause && exit"
            
            $BtnBuildPapyrus.Text = 'Build Papyrus'
        }
    }
    
    $BtnChangeVersion = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Version'
        Location   = New-Object System.Drawing.Point(100, 240)
        Add_Click  = {
            $NewVersion = $null
            while ($OldVersion -and !$NewVersion) {
                $NewVersion = [Microsoft.VisualBasic.Interaction]::InputBox("Input the new versioning for $Project", 'Versioning', $OldVersion)
            }
            $ProjectCMake = $ProjectCMake -replace "VERSION\s$OldVersion", "VERSION $NewVersion"
            $vcpkg.'version-string' = $NewVersion

            [IO.File]::WriteAllText("$PSScriptRoot/CMakeLists.txt", $ProjectCMake)
            $vcpkg = $vcpkg | ConvertTo-Json -Depth 9
            [IO.File]::WriteAllText("$PSScriptRoot/vcpkg.json", $vcpkg)


            "- Version changed $OldVersion -> $NewVersion" | Log
            $OldVersion = $NewVersion
        }
    }
    
    $BtnPublish = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Publish Mod'
        Location   = New-Object System.Drawing.Point(180, 240)
        Add_Click  = {
            $BtnPublish.Text = 'Zipping...'

            Copy-Mod "$PSScriptRoot/Tmp/Data"
            Compress-Archive "$PSScriptRoot/Tmp/Data/*" "$Path/$($Project)-$(($OldVersion).Replace('.', '-'))" -Force
            Remove-Item "$PSScriptRoot/Tmp" -Recurse -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
            Invoke-Item $Path

            "- Mod files zipped & ready to go." | Log
            $BtnPublish.Text = 'Publish Mod'
        }
    }
    
    
    $BtnExit = New-Object System.Windows.Forms.Button -Property @{
        ClientSize = '70, 50'
        Text       = 'Exit'
        Location   = New-Object System.Drawing.Point(260, 240)
        Add_Click  = {
            $MsgBox.Close()
        }
    }
                
    $MsgBox.Controls.Add($Message)
    $MsgBox.Controls.Add($BtnCopyData)
    $MsgBox.Controls.Add($BtnCopyMO2)
    $MsgBox.Controls.Add($BtnRemoveData)
    $MsgBox.Controls.Add($BtnOpenFolder)
    $MsgBox.Controls.Add($BtnExit)
    $MsgBox.Controls.Add($BtnBuildPapyrus)
    $MsgBox.Controls.Add($BtnChangeVersion)
    $MsgBox.Controls.Add($BtnPublish)
    $MsgBox.Controls.Add($BtnLaunchSKSEAE)
    $MsgBox.Controls.Add($BtnLaunchSKSESE)
    $MsgBox.Controls.Add($BtnLaunchSKSEVR)
    
    "- [$Project - $OldVersion] has been built." | Log
    $MsgBox.ShowDialog() | Out-Null
    Exit
}


# @@SOURCEGEN
if ($Mode -eq 'SOURCEGEN') {
    Write-Host "`tGenerating CMake sourcelist..."
    Remove-Item "$Path/sourcelist.cmake" -Force -Confirm:$false -ErrorAction Ignore

    $generated = 'set(SOURCES'
    $generated += $PSScriptRoot | Resolve-Files
    if ($Path) {
        $generated += $Path | Resolve-Files
    }
    $generated += "`n)"
    [IO.File]::WriteAllText("$Path/sourcelist.cmake", $generated)
}


# @@DISTRIBUTE
if ($Mode -eq 'DISTRIBUTE') {
    # update script to every project
    Get-ChildItem "$PSScriptRoot/*/*" -Directory | Where-Object {
        $_.Name -notin @('vcpkg', 'Build', '.git', '.vs') -and
        (Test-Path "$_/CMakeLists.txt" -PathType Leaf)
    } | ForEach-Object {
        Write-Host "`tUpdated <$_>"
        Robocopy.exe "$PSScriptRoot" "$_" '!Update.ps1' /MT /NJS /NFL /NDL /NJH | Out-Null
    }
}

# SIG # Begin signature block
# MIIblwYJKoZIhvcNAQcCoIIbiDCCG4QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeNnMpcw8dAQ7RLeEjMVRxS8n
# pd2gghYNMIIDBjCCAe6gAwIBAgIQXGgCIEYNyZFAhXU7PixYOTANBgkqhkiG9w0B
# AQsFADAbMRkwFwYDVQQDDBBES1NjcmlwdFNlbGZDZXJ0MB4XDTI1MDUxMDEyMzgw
# NloXDTI2MDUxMDEyNTgwNlowGzEZMBcGA1UEAwwQREtTY3JpcHRTZWxmQ2VydDCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM8pulIVEoKVXE+2XQNgKCW8
# KKj7qpvWArHCWXXfqN352QmkeIJ7cCYcxAHx2dYsIBxwaLzE27zEnzXM0wC2Nc2E
# ciaG+gaPf5Z3zvlseIRWuV13ckZKebz32uHbITmQtWCzoshxJ39GVP/IZw798Lh/
# 9qOcWP03fwhcM7NcTGWgcz/Os85Mpf5iKmgZZarNmplt6RtZG+T78xMwecbgyexr
# qFfhHm8br2d+fBAJ/P6J/MOMXsbMl6d6MBwC7Q1lFKiPFvYgzU3De9kzefMTJFZV
# IqEeVSuCilDurv5EfPT8/LyAQ+NQPA8g6bzEE5W5dO8gMxUPjaNNJfqn0srV5xkC
# AwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0G
# A1UdDgQWBBQUuPyHnp1R+6MC+iwDzBQVohb/lzANBgkqhkiG9w0BAQsFAAOCAQEA
# uOZW+2r8yYMPP6GoAu6EeVI4gbbkxG+yrPc/oFDp1UzsRxDhandfsQDoToAubuQg
# ye8tqaVyOH7iDEgg3FrIC378o+9ixapD9PPhYzQN5kP7ENOTifMej1yrRZDWf0bt
# S3Ss1+LApRUYx+UukiPG88YL7zlrZAryUqdyAwXmVvCARjfLIbKPya8OCT8JReCd
# t/LrOy0PzzaiAk9oaXZnGsYJIVjn2DiJCtiyF4bZr7CoHukbiv6aQtZJOPasSuv1
# RtnOeWeOeexe3M00/hoEPkTgrAgeMzmM+sW1yieIfokv5pubFSqY4TLgjrU1PLY+
# lEm2ATwWKCTcfZUOaryvozCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFow
# DQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNl
# cnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIz
# NTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3Rl
# ZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2je
# u+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bG
# l20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBE
# EC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/N
# rDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A
# 2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8
# IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfB
# aYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaa
# RBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZi
# fvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXe
# eqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g
# /KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB
# /wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQY
# MBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEF
# BQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBD
# BggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1Ud
# IAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22
# Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih
# 9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYD
# E3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c
# 2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88n
# q2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5
# lDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAw
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290
# IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBU
# cnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh
# 1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+Feo
# An39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1
# decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxnd
# X7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6
# Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPj
# Q2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlREr
# WHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JM
# q++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh
# 3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8j
# u2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnS
# DmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1Ud
# DgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzf
# Lmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgw
# dwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAG
# A1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOC
# AgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp
# /GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40B
# IiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2d
# fNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibB
# t94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7
# T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZA
# myEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdB
# eHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnK
# cPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/
# pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yY
# lvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwgga8MIIEpKADAgEC
# AhALrma8Wrp/lYfG+ekE4zMEMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1
# c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjQwOTI2
# MDAwMDAwWhcNMzUxMTI1MjM1OTU5WjBCMQswCQYDVQQGEwJVUzERMA8GA1UEChMI
# RGlnaUNlcnQxIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDI0MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvmpzn/aVIauWMLpbbeZZo7Xo/ZEf
# GMSIO2qZ46XB/QowIEMSvgjEdEZ3v4vrrTHleW1JWGErrjOL0J4L0HqVR1czSzvU
# Q5xF7z4IQmn7dHY7yijvoQ7ujm0u6yXF2v1CrzZopykD07/9fpAT4BxpT9vJoJqA
# sP8YuhRvflJ9YeHjes4fduksTHulntq9WelRWY++TFPxzZrbILRYynyEy7rS1lHQ
# KFpXvo2GePfsMRhNf1F41nyEg5h7iOXv+vjX0K8RhUisfqw3TTLHj1uhS66YX2LZ
# PxS4oaf33rp9HlfqSBePejlYeEdU740GKQM7SaVSH3TbBL8R6HwX9QVpGnXPlKdE
# 4fBIn5BBFnV+KwPxRNUNK6lYk2y1WSKour4hJN0SMkoaNV8hyyADiX1xuTxKaXN1
# 2HgR+8WulU2d6zhzXomJ2PleI9V2yfmfXSPGYanGgxzqI+ShoOGLomMd3mJt92nm
# 7Mheng/TBeSA2z4I78JpwGpTRHiT7yHqBiV2ngUIyCtd0pZ8zg3S7bk4QC4RrcnK
# J3FbjyPAGogmoiZ33c1HG93Vp6lJ415ERcC7bFQMRbxqrMVANiav1k425zYyFMyL
# NyE1QulQSgDpW9rtvVcIH7WvG9sqYup9j8z9J1XqbBZPJ5XLln8mS8wWmdDLnBHX
# gYly/p1DhoQo5fkCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57I
# bzAdBgNVHQ4EFgQUn1csA3cOKBWQZqVjXu5Pkh92oFswWgYDVR0fBFMwUTBPoE2g
# S4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNB
# NDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcw
# AoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOC
# AgEAPa0eH3aZW+M4hBJH2UOR9hHbm04IHdEoT8/T3HuBSyZeq3jSi5GXeWP7xCKh
# VireKCnCs+8GZl2uVYFvQe+pPTScVJeCZSsMo1JCoZN2mMew/L4tpqVNbSpWO9QG
# FwfMEy60HofN6V51sMLMXNTLfhVqs+e8haupWiArSozyAmGH/6oMQAh078qRh6wv
# JNU6gnh5OruCP1QUAvVSu4kqVOcJVozZR5RRb/zPd++PGE3qF1P3xWvYViUJLsxt
# vge/mzA75oBfFZSbdakHJe2BVDGIGVNVjOp8sNt70+kEoMF+T6tptMUNlehSR7vM
# +C13v9+9ZOUKzfRUAYSyyEmYtsnpltD/GWX8eM70ls1V6QG/ZOB6b6Yum1HvIiul
# qJ1Elesj5TMHq8CWT/xrW7twipXTJ5/i5pkU5E16RSBAdOp12aw8IQhhA/vEbFkE
# iF2abhuFixUDobZaA0VhqAsMHOmaT3XThZDNi5U2zHKhUs5uHHdG6BoQau75KiNb
# h0c+hatSF+02kULkftARjsyEpHKsF7u5zKRbt5oK5YGwFvgc4pEVUNytmB3BpIio
# wOIIuDgP5M9WArHYSAR16gc0dP2XdkMEP5eBsX7bf/MGN4K3HP50v/01ZHo/Z5lG
# LvNwQ7XHBx1yomzLP8lx4Q1zZKDyHcp4VQJLu2kWTsKsOqQxggT0MIIE8AIBATAv
# MBsxGTAXBgNVBAMMEERLU2NyaXB0U2VsZkNlcnQCEFxoAiBGDcmRQIV1Oz4sWDkw
# CQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# IwYJKoZIhvcNAQkEMRYEFM7EWLmszAlgyst1sXEnnkTeG+qCMA0GCSqGSIb3DQEB
# AQUABIIBAEzppkpm/89zbFM19tDM4AqEnoBI9Ia4zibb9ma6osL9JiQkpJdsEAml
# acoX4eUNXNWiSASQFTEkX5YDw/+WFMEt2EYI348Yslcc7f+pIHTI9Y5fWAzg773j
# 3BAP+3/oOcD3kD9uKa3f6eMDpOOJ9r4HUTXxDaZk8AQuSTuBnztETxEMhlyMxp6w
# 41vE5VqF33KJU+9UPK40kNf7OVmobICry4sDMG17FanpXIywyzMxgzZRvG/AYgla
# b2rLevdpzlJV1484NIXGUo2NmPzDPN+f6N3woT8apmbVD+waEqUMZ4ijnbQcJufw
# +eZGG/QYLuE9fvFIXrec1YJ5DdsZyNqhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCC
# AwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# OzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGlt
# ZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE4zMEMA0GCWCGSAFlAwQCAQUAoGkw
# GAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUwNTEw
# MTI0ODA5WjAvBgkqhkiG9w0BCQQxIgQg+ARTaXYWBjubx3EpuySXKMATCs/ChesW
# 1Pt+3SEllAwwDQYJKoZIhvcNAQEBBQAEggIAV2ThBAsm+hSX0SZsOg/uvaumEfLB
# 8z1WP9VOIsERCS6qXEHNBjU9UsU09NVxaB9UE+qZ0I8oz70QxS7yN5ZzHRFvHNNm
# mDYOoJIL/KFmSHFN4gaRaW2qXJ3F9BNc6Kqa4S80aQZdAzbG/NX8Dvqvayg6v+GK
# AQprwOjfG/oTUspFxAd34rZNOd4mLV4r5bZNwlZ/hVdE9BaL22HekTsY3pvYu9zE
# wBJENRmja1Hgfe0W89435gf3NRK2ECQ24RSC9SrrwNnyxz+gKQVZVZKsSxhxptpJ
# 2j+pLzIMFVPhmpK7cHt4mhJGTkxMP0oB7Ktt22qoFQ67AW7mr+iw52a5Yk+B2HLa
# 2UyRySxMhM3poTODMgFEIfHS5sTQqkt9lGblImB6ApQorEOgJM48rSyIMGPCmmsx
# pfxJH8J0FaV3fKz7eSyd4/FoYsroDERHzY8/7kw3drJDn6S4y84DtoNo3Ky9qQnV
# bCtqpgTr074mP22oMHzwFDzoDAdPHQxAtfCZiFxMgRE0+n2xqIRuTcEtbnKv98FE
# hquq03X4kp9nYH0IyA6EoSrw8KGZmDcoekNlx6y42DQO29faIWBCqR2s2FH+0hlM
# xr7PTV1nd/h8ldthXgXTee0EHamfG3O8AQLw3Ny1Rr4osbxTDJ/tGmWGuMCDpjfl
# kIHJCf4xyRLuQJ4=
# SIG # End signature block
