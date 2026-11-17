function Connect-WEYSendGrid {
    <#
    .SYNOPSIS
    Connects this pack to the Twilio SendGrid API with an API key, through the SendGridTools module.

    .DESCRIPTION
    Connect-Maester -Service WEY.SENDGRID.Api calls it. Its parameters come from -ServiceSetting, from
    Connections.WEY.SENDGRID.Api in maester-config.json, or from MAESTER_WEY_SENDGRID_API_<NAME> environment
    variables. Keep the key out of maester-config.json: pass it with -ServiceSetting or the
    MAESTER_WEY_SENDGRID_API_APIKEY environment variable.

    Use a key with read-only scopes (Restricted Access): whitelabel.read, api_keys.read,
    user.settings.enforced_tls.read, subusers.read and ips.read. A test whose scope the key lacks is skipped and
    says which scope to add.

    SendGridTools 0.4.7 reaches only the global host, api.sendgrid.com. An EU regional account or subuser
    (api.eu.sendgrid.com) cannot be checked with it, so Region 'EU' is refused here.

    .EXAMPLE
    Connect-Maester -Service WEY.SENDGRID.Api -ServiceSetting @{ ApiKey = (Read-Host -AsSecureString 'SendGrid API key') }
    #>
    [CmdletBinding()]
    param(
        # The SendGrid API key, as a SecureString or a string.
        [Parameter(Mandatory)]
        [object] $ApiKey,

        # Only Global: SendGridTools 0.4.7 cannot reach api.eu.sendgrid.com.
        [string] $Region = 'Global'
    )

    if ($Region -ne 'Global') {
        throw "Region '$Region' is not supported: SendGridTools 0.4.7 reaches only api.sendgrid.com, so an EU regional SendGrid account cannot be checked with this pack."
    }

    # Spaces or a line break around a pasted key make SendGrid answer 401, so they are removed.
    $plain = if ($ApiKey -is [securestring]) { [System.Net.NetworkCredential]::new('', $ApiKey).Password } else { [string]$ApiKey }
    $plain = $plain.Trim()
    if (-not $plain) { throw 'ApiKey is empty. Pass a SendGrid API key.' }
    $secureKey = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $plain = $null

    # Connect-SendGrid checks the key (GET /v3/scopes); a wrong key fails here.
    Connect-SendGrid -Credential ([pscredential]::new('apikey', $secureKey)) -Force -Confirm:$false 4>$null
    $scopes = @((Get-SGPermissionScopes).Scopes)

    # The key is kept as a SecureString in this session only; it is never written to a file or a report.
    Set-MtConnectionState -Value @{ ApiKey = $secureKey; Scopes = $scopes } -Tenant 'api.sendgrid.com' -Account "Global region, $($scopes.Count) scopes"
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
