function Connect-WEYSendGridModule {
    <#
    .SYNOPSIS
    Connects the SendGridTools module that is loaded now, from the key and region Connect-WEYSendGrid kept.

    .DESCRIPTION
    SendGridTools keeps its connection inside the module, and the copy loaded for the tests may not be the one
    that was loaded when Connect-Maester ran. Call it once at the start of a test or instance source. It sends
    one GET request (/v3/scopes).
    #>
    [CmdletBinding()]
    param()

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    if (-not $state) { throw 'Not connected to SendGrid. Run Connect-Maester -Service WEY.SENDGRID.Api first.' }
    Connect-SendGrid -ApiKey $state.ApiKey -Region $state.Region -Force -Confirm:$false 4>$null
}

function Get-WEYSendGridSubuser {
    <#
    .SYNOPSIS
    Returns every subuser of the account with its region, page by page (Get-SGSubuser reads one page per call).
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 500)]
        [int] $PageSize = 100,

        # A guard against an endless loop.
        [int] $MaximumItems = 5000
    )

    $offset = 0
    do {
        $page = @(Get-SGSubuser -IncludeRegion -Limit $PageSize -Offset $offset | Where-Object { $null -ne $_ })
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

function ConvertTo-WEYSendGridPlainText {
    <#
    .SYNOPSIS
    Returns a name from SendGrid as plain text for a result title or field: without the characters that make
    markdown links, images, HTML, code or tables ([ ] ( ) < > ` |) and without line breaks.

    .DESCRIPTION
    Titles and fields are shown as text in the HTML report, but other outputs (the markdown export, Teams or
    email) may render them as markdown. API key names are free text; domain names never contain these characters.
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
