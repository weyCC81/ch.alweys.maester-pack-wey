function Connect-WEYSendGrid {
    <#
    .SYNOPSIS
    Connects this pack to the Twilio SendGrid API with an API key, global or EU, through the SendGridTools module.

    .DESCRIPTION
    Connect-Maester -Service WEY.SENDGRID.Api calls it. Its parameters come from -ServiceSetting, from
    Connections.WEY.SENDGRID.Api in maester-config.json, or from MAESTER_WEY_SENDGRID_API_<NAME> environment
    variables. Keep the key out of maester-config.json: pass it with -ServiceSetting or the
    MAESTER_WEY_SENDGRID_API_APIKEY environment variable.

    Use a key with read-only scopes (Restricted Access): whitelabel.read, api_keys.read,
    user.settings.enforced_tls.read, subusers.read and ips.read. A test whose scope the key lacks is skipped and
    says which scope to add.

    .EXAMPLE
    Connect-Maester -Service WEY.SENDGRID.Api -ServiceSetting @{ ApiKey = (Read-Host -AsSecureString 'SendGrid API key') }

    .EXAMPLE
    Connect-Maester -Service WEY.SENDGRID.Api -ServiceSetting @{ ApiKey = $key; Region = 'EU' }
    #>
    [CmdletBinding()]
    param(
        # The SendGrid API key, as a SecureString or a string.
        [Parameter(Mandatory)]
        [object] $ApiKey,

        # Global (api.sendgrid.com) or EU (api.eu.sendgrid.com, for EU regional accounts and subusers).
        [ValidateSet('Global', 'EU')]
        [string] $Region = 'Global'
    )

    # Spaces or a line break around a pasted key make SendGrid answer 401, so they are removed.
    $plain = if ($ApiKey -is [securestring]) { [System.Net.NetworkCredential]::new('', $ApiKey).Password } else { [string]$ApiKey }
    $plain = $plain.Trim()
    if (-not $plain) { throw 'ApiKey is empty. Pass a SendGrid API key.' }
    $secureKey = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $plain = $null

    # Connect-SendGrid checks the key (GET /v3/scopes) on the region's host; a wrong key or region fails here.
    Connect-SendGrid -ApiKey $secureKey -Region $Region -Force -Confirm:$false 4>$null
    $scopes = @((Get-SGPermissionScopes).Scopes)
    $hostName = if ($Region -eq 'EU') { 'api.eu.sendgrid.com' } else { 'api.sendgrid.com' }

    # The key is kept as a SecureString in this session only; it is never written to a file or a report.
    Set-MtConnectionState -Value @{ ApiKey = $secureKey; Region = $Region; Scopes = $scopes } -Tenant $hostName -Account "$Region region, $($scopes.Count) scopes"
}

function Test-WEYSendGrid {
    <#
    .SYNOPSIS
    Returns $true when Connect-WEYSendGrid has run in this session. Tests that need WEY.SENDGRID.Api are skipped otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    [bool](Get-MtConnectionState)
}

function Disconnect-WEYSendGrid {
    <#
    .SYNOPSIS
    Forgets the SendGrid connection of this pack.
    #>
    [CmdletBinding()]
    param()

    Clear-MtConnectionState
}
