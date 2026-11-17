function Connect-WEYSendGridModule {
    <#
    .SYNOPSIS
    Connects the SendGridTools module that is loaded now, from the key Connect-WEYSendGrid kept.

    .DESCRIPTION
    SendGridTools keeps its connection inside the module, and the copy loaded for the tests may not be the one
    that was loaded when Connect-Maester ran. Call it once at the start of a test or instance source. It sends
    one GET request (/v3/scopes).
    #>
    [CmdletBinding()]
    param()

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    if (-not $state) { throw 'Not connected to SendGrid. Run Connect-Maester -Service WEY.SENDGRID.Api first.' }
    Connect-SendGrid -Credential ([pscredential]::new('apikey', $state.ApiKey)) -Force -Confirm:$false 4>$null
}

function Get-WEYSendGridPage {
    <#
    .SYNOPSIS
    Reads every page of a SendGrid list that pages with limit and offset, through Invoke-SGCommand (GET).

    .DESCRIPTION
    The dedicated SendGridTools commands (Get-SGAuthenticatedDomain, Get-SGSubuser) read only SendGrid's
    default first page, so the lists are read here, page by page.
    #>
    [CmdletBinding()]
    param(
        # The API path without /v3/, such as 'whitelabel/domains'.
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z_/]+$')]
        [string] $Namespace,

        # More query parameters, such as 'include_region=true'.
        [string[]] $Query = @(),

        [ValidateRange(1, 500)]
        [int] $PageSize = 100,

        # A guard against an endless loop.
        [int] $MaximumItems = 5000
    )

    $offset = 0
    do {
        $parameters = [System.Collections.Generic.List[string]]::new()
        foreach ($q in $Query) { $parameters.Add($q) }
        $parameters.Add("limit=$PageSize")
        $parameters.Add("offset=$offset")
        $page = @(Invoke-SGCommand -WebMethod Get -Namespace $Namespace -QueryParameters $parameters | Where-Object { $null -ne $_ })
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
