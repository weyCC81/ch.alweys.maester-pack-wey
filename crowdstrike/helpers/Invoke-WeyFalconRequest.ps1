function Connect-WEYFalconModule {
    <#
    .SYNOPSIS
    Gives the PSFalcon module that is loaded now a token, from the API client Connect-WEYFalcon kept.

    .DESCRIPTION
    PSFalcon keeps its token inside the module ($Script:Falcon), and the copy loaded for the tests may not be the
    one that was loaded when Connect-Maester ran. Call it once at the start of a test or instance source. It
    requests a token (POST /oauth2/token) only when the loaded copy has no valid token for this client and cloud.
    #>
    [CmdletBinding()]
    param()

    $state = Get-MtConnectionState -Service WEY.FALCON.Api
    if (-not $state) { throw 'Not connected to CrowdStrike Falcon. Run Connect-Maester -Service WEY.FALCON.Api first.' }

    $token = Test-FalconToken -ErrorAction SilentlyContinue
    if ($token -and $token.Token -and $token.ClientId -eq $state.ClientId -and $token.Hostname -eq $state.Hostname -and
        [string]$token.MemberCid -eq [string]$state.MemberCid) { return }

    $tokenParams = @{
        ClientId     = $state.ClientId
        ClientSecret = [System.Net.NetworkCredential]::new('', $state.ClientSecret).Password
        Hostname     = $state.Hostname
    }
    if ($state.MemberCid) { $tokenParams['MemberCid'] = $state.MemberCid }
    try {
        Request-FalconToken @tokenParams -ErrorAction SilentlyContinue 4>$null
    } finally {
        $tokenParams = $null
    }
    if (-not (Test-FalconToken -ErrorAction SilentlyContinue).Token) {
        throw "Falcon did not issue a token for the API client $($state.ClientId). Run Connect-Maester -Service WEY.FALCON.Api again."
    }
}

function Get-WEYFalconData {
    <#
    .SYNOPSIS
    Runs a reading PSFalcon command and returns { Skipped; Items }. When the API client lacks the command's
    scope (Falcon answers 403), it skips the running test, names the scope and returns Skipped = $true.

    .DESCRIPTION
    PSFalcon writes API errors to the error stream instead of throwing them. They are collected here: a 403
    becomes a skip, any other error is thrown, so the test does not pass on a partial answer.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The PSFalcon command that reads.
        [Parameter(Mandatory)]
        [ValidateSet('Get-FalconPreventionPolicy', 'Get-FalconSensorUpdatePolicy', 'Get-FalconBuild')]
        [string] $Command,

        # The API scope the command needs, as the Falcon console names it.
        [Parameter(Mandatory)]
        [string] $Scope,

        # More parameters for the command.
        [hashtable] $Parameter = @{}
    )

    $falconErrors = @()
    $read = @{ ErrorAction = 'SilentlyContinue'; ErrorVariable = 'falconErrors' }
    # Only these reading commands; named literally so the pack calls no command by a computed name.
    $items = @(switch ($Command) {
            'Get-FalconPreventionPolicy' { Get-FalconPreventionPolicy @Parameter @read 4>$null }
            'Get-FalconSensorUpdatePolicy' { Get-FalconSensorUpdatePolicy @Parameter @read 4>$null }
            'Get-FalconBuild' { Get-FalconBuild @Parameter @read 4>$null }
        })
    if ($falconErrors.Count -gt 0) {
        $messages = @($falconErrors | ForEach-Object { [string]$_.Exception.Message })
        if ($messages -match '"code":\s*403' -or $messages -match 'access denied') {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The Falcon API client lacks the scope $Scope. Give the client read access to it (Support and resources > API clients and keys)."
            return [pscustomobject]@{ Skipped = $true; Items = @() }
        }
        throw "$Command failed: $($messages[0])"
    }
    [pscustomobject]@{ Skipped = $false; Items = @($items | Where-Object { $null -ne $_ }) }
}

function ConvertTo-WEYFalconPlainText {
    <#
    .SYNOPSIS
    Returns a name from Falcon as plain text for a result title or field: without the characters that make
    markdown links, images, HTML, code or tables ([ ] ( ) < > ` |) and without line breaks.

    .DESCRIPTION
    Titles and fields are shown as text in the HTML report, but other outputs (the markdown export, Teams or
    email) may render them as markdown. Policy names in Falcon are free text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Text
    )

    ([string]$Text -replace '[\[\]()<>`|]', '' -replace '\s+', ' ').Trim()
}
