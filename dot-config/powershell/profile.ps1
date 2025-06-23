# Vi-mode and other PSReadLine settings
function OnViModeChange {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block.
        Write-Host -NoNewline "`e[1 q"
    } else {
        # Set the cursor to a blinking line.
        Write-Host -NoNewline "`e[5 q"
    }
}

$PSReadLineOptions = @{
    EditMode            = 'Vi'
    PredictionSource    = 'None'
    ViModeIndicator     = 'Script'
    ViModeChangeHandler = $Function:OnViModeChange
    HistoryNoDuplicates = $true
}
Set-PSReadLineOption @PSReadLineOptions

Set-PSReadLineKeyHandler -Key Tab -Function Complete

# Better prompt
function Prompt {
    # Original prompt for referencing purposes
    $OgPrompt = {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
    }

    # Prompt before more modifications
    $BasePrompt = $OgPrompt

    # Replace user folder with a ~
    $NewPrompt = (& $BasePrompt).Replace($HOME, '~')

    $NewPrompt
}

$PSDefaultParameterValues['*-AD*:Server'] = 'uark.edu'

# Base64 Conversions
function ConvertFrom-Base64 {
    param (
        [string]$tmp
    )
    [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($tmp))
}

function ConvertTo-Base64 {
    param (
        [string]$tmp
    )
    [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($tmp))
}

# Intune base64-encoded install commands
function ConvertTo-IntuneInstallCommand {
    param(
        $tmp
    )

    $IntuneCommand = @(
        'PowerShell.exe -NoProfile -NonInteractive -EncodedCommand'
        ConvertTo-Base64 $tmp
    ) -Join ' '
    If ($IntuneCommand.Length -gt 1024) {
        Write-Error "Encoded command version length ($( $IntuneCommand.Length )) exceeds field limits (1024)."
    } Else {
        $IntuneCommand
    }
}

# Command to run in psexec test environment to try to emulate Intune
function ConvertTo-IntuneInstallPsExecTest {
    param(
        $tmp
    )

    $IntuneCommand = ConvertTo-IntuneInstallCommand $tmp

    $TestCommand = 'PsExec.exe -w "$PWD" -s --%'
    # Explanation:
    # -w "$PWD" to make the current directory the working dir
    # -s to install under the SYSTEM account
    # --% to stop PowerShell from parsing anything afterwords

    $TestCommand = @(
        $TestCommand
        $IntuneCommand
    ) -join ' '

    $TestCommand
}

# Read in ini file as hashtables
function ConvertFrom-IniFile ($filePath) {
    $ini = @{}

    switch -Regex -File $filePath {
        # Section
        '^\[(.+)\]' {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }

        # Comment
        '^(;.*)$' {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = 'Comment' + $CommentCount
            $ini[$section][$name] = $value
        }

        # Key
        '(.+?)\s*=(.*)' {
            $name, $value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }

    return $ini
}

function Out-IniFile($InputObject, $FilePath) {
    $outFile = New-Item -ItemType file -Path $Filepath
    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq 'Hashtable')) {
            #No Sections
            Add-Content -Path $outFile -Value “$i=$($InputObject[$i])”
        } else {
            #Sections
            Add-Content -Path $outFile -Value “[$i]”
            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match '^Comment[\d]+') {
                    Add-Content -Path $outFile -Value “$($InputObject[$i][$j])”
                } else {
                    Add-Content -Path $outFile -Value “$j=$($InputObject[$i][$j])”
                }

            }
            Add-Content -Path $outFile -Value ''
        }
    }
}

function Convert-AzureAdObjectIdToSid {
<#
.SYNOPSIS
Convert an Azure AD Object ID to SID

.DESCRIPTION
Converts an Azure AD Object ID to a SID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.

.PARAMETER ObjectID
The Object ID to convert
#>

    param([String] $ObjectId)

    $bytes = [Guid]::Parse($ObjectId).ToByteArray()
    $array = New-Object 'UInt32[]' 4

    [Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
    $sid = "S-1-12-1-$array".Replace(' ', '-')

    return $sid
}

function Convert-AzureAdSidToObjectId {
<#
.SYNOPSIS
Convert a Azure AD SID to Object ID

.DESCRIPTION
Converts an Azure AD SID to Object ID.
Author: Oliver Kieselbach (oliverkieselbach.com)
The script is provided "AS IS" with no warranties.

.PARAMETER ObjectID
The SID to convert
#>

    param([String] $Sid)

    $text = $sid.Replace('S-1-12-1-', '')
    $array = [UInt32[]]$text.Split('-')

    $bytes = New-Object 'Byte[]' 16
    [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
    [Guid]$guid = $bytes

    return $guid
}

# Keep last; fixes vi mode indicator stuff
Write-Host -NoNewline "`e[5 q"

$CompanyPortalStatusKeys = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\StatusServiceReports'
