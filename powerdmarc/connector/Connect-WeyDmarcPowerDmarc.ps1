function Connect-WeyDmarcPowerDmarc {
    <#
    .SYNOPSIS
    Connects this pack to the PowerDMARC API: it keeps the token and settings for the tests of this pack.

    .DESCRIPTION
    Connect-Maester -Service WEY.DMARC.PowerDMARC calls it. Its parameters come from -ServiceSetting, from
    Connections.WEY.DMARC.PowerDMARC in maester-config.json, or from MAESTER_WEY_DMARC_POWERDMARC_<NAME>
    environment variables. Keep the token out of maester-config.json: pass it with -ServiceSetting or the
    MAESTER_WEY_DMARC_POWERDMARC_APITOKEN environment variable.

    Default mode (End User API) checks the domains of the token's own account. Reseller mode (MSSP API) checks
    the domains of one customer account (AccountId), or of every customer account when AccountId is not given.

    The PowerDMARC module keeps its connection inside the module, so a second copy of the module (one the user
    installed next to the one Maester pins) would not see it. The tests therefore connect the module that is
    loaded when they run (Connect-WeyDmarcPowerDmarcModule), from the settings kept here.

    .EXAMPLE
    Connect-Maester -Service WEY.DMARC.PowerDMARC -ServiceSetting @{ ApiToken = (Read-Host -AsSecureString 'PowerDMARC token') }

    .EXAMPLE
    Connect-Maester -Service WEY.DMARC.PowerDMARC -ServiceSetting @{ ApiToken = $token; Mode = 'Reseller'; BaseUri = 'reseller.powerdmarc.com'; AccountId = 42 }
    #>
    [CmdletBinding()]
    param(
        # The PowerDMARC Personal Access Token, as a SecureString or a string.
        [Parameter(Mandatory)]
        [object] $ApiToken,

        # Default (End User API) or Reseller (MSSP API).
        [ValidateSet('Default', 'Reseller')]
        [string] $Mode = 'Default',

        # The PowerDMARC host, such as app.powerdmarc.com or the reseller's own portal host. A name without a
        # domain, such as 'reseller', means reseller.powerdmarc.com.
        [string] $BaseUri = 'app.powerdmarc.com',

        # Reseller mode only: the customer account whose domains are checked. 0 checks every customer account.
        [int] $AccountId = 0
    )

    # Spaces or a line break around a pasted token make PowerDMARC answer 401, so they are removed.
    $plain = if ($ApiToken -is [securestring]) { [System.Net.NetworkCredential]::new('', $ApiToken).Password } else { [string]$ApiToken }
    $plain = $plain.Trim()
    if (-not $plain) { throw 'ApiToken is empty. Pass the PowerDMARC Personal Access Token.' }
    $secureToken = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $plain = $null

    # A portal name without a domain, such as 'reseller', is a PowerDMARC host: reseller.powerdmarc.com.
    $hostName = ($BaseUri.Trim() -replace '^https?://', '') -replace '[/:].*$', ''
    if (-not $hostName) { throw "BaseUri '$BaseUri' has no host name." }
    if ($hostName -notmatch '\.') {
        $BaseUri = $BaseUri.Trim() -replace [regex]::Escape($hostName), "$hostName.powerdmarc.com"
        $hostName = "$hostName.powerdmarc.com"
    }

    $account = if ($Mode -eq 'Reseller' -and $AccountId -gt 0) { "account $AccountId" } elseif ($Mode -eq 'Reseller') { 'all customer accounts' } else { 'own account' }
    # The token is kept as a SecureString in this session only; it is never written to a file or a report.
    Set-MtConnectionState -Value @{ ApiToken = $secureToken; BaseUri = $BaseUri; Mode = $Mode; AccountId = $AccountId } -Tenant $hostName -Account "$Mode ($account)"
}

function Test-WeyDmarcPowerDmarc {
    <#
    .SYNOPSIS
    Returns $true when Connect-WeyDmarcPowerDmarc has run in this session. Tests that need WEY.DMARC.PowerDMARC are skipped otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    [bool](Get-MtConnectionState)
}

function Disconnect-WeyDmarcPowerDmarc {
    <#
    .SYNOPSIS
    Forgets the PowerDMARC connection of this pack.
    #>
    [CmdletBinding()]
    param()

    Clear-MtConnectionState
}
