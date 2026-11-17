function Invoke-WEYSendGridRequest {
    <#
    .SYNOPSIS
    Sends one GET request to the SendGrid API, global or EU, and returns the response.

    .DESCRIPTION
    Only GET: the pack reads and never changes anything. The host is one of the two literal hosts that
    Uses.Network declares. Without -ApiKey and -Region it uses the connection of Connect-WEYSendGrid.
    #>
    [CmdletBinding()]
    param(
        # The API path with its query, starting with /v3/.
        [Parameter(Mandatory)]
        [ValidatePattern('^/v3/[A-Za-z0-9_./{}?&=,-]*$')]
        [string] $Path,

        [securestring] $ApiKey,

        [ValidateSet('Global', 'EU')]
        [string] $Region
    )

    if (-not $ApiKey) {
        $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
        if (-not $state) { throw 'Not connected to SendGrid. Run Connect-Maester -Service WEY.SENDGRID.Api first.' }
        $ApiKey = $state.ApiKey
        $Region = $state.Region
    }

    $headers = @{ Authorization = 'Bearer ' + [System.Net.NetworkCredential]::new('', $ApiKey).Password; Accept = 'application/json' }
    # The host is written out before the first variable, so the pack's content check can see where requests go.
    $rest = $Path.Substring('/v3/'.Length)
    if ($Region -eq 'EU') {
        Invoke-RestMethod -Uri "https://api.eu.sendgrid.com/v3/$rest" -Headers $headers -Method Get -ErrorAction Stop
    } else {
        Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/$rest" -Headers $headers -Method Get -ErrorAction Stop
    }
}

function Get-WEYSendGridPage {
    <#
    .SYNOPSIS
    Reads every page of a SendGrid list that pages with limit and offset, and returns the items.
    #>
    [CmdletBinding()]
    param(
        # The API path, with any query except limit and offset.
        [Parameter(Mandatory)]
        [string] $Path,

        [ValidateRange(1, 500)]
        [int] $PageSize = 100,

        # A guard against an endless loop.
        [int] $MaximumItems = 5000
    )

    $separator = if ($Path.Contains('?')) { '&' } else { '?' }
    $offset = 0
    do {
        $page = @(Invoke-WEYSendGridRequest -Path "$Path$($separator)limit=$PageSize&offset=$offset" | ForEach-Object { $_ })
        $page
        $offset += $PageSize
    } while ($page.Count -eq $PageSize -and $offset -lt $MaximumItems)
}

function Test-WEYSendGridScope {
    <#
    .SYNOPSIS
    Returns $true when the connected API key has every scope named; otherwise skips the running test and says
    which scopes to add, and returns $false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Scope
    )

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    $missing = @($Scope | Where-Object { $_ -notin @($state.Scopes) })
    if ($missing.Count -eq 0) { return $true }
    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The SendGrid API key lacks the scope $($missing -join ', '). Give the key read access to it (Settings > API Keys > Restricted Access)."
    $false
}
