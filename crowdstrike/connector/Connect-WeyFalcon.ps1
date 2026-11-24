function Connect-WEYFalcon {
    <#
    .SYNOPSIS
    Connects this pack to the CrowdStrike Falcon API with an API client, through the PSFalcon module.

    .DESCRIPTION
    Connect-Maester -Service WEY.FALCON.Api calls it. Its parameters come from -ServiceSetting, from
    Connections.WEY.FALCON.Api in maester-config.json, or from MAESTER_WEY_FALCON_API_<NAME> environment variables.
    Keep the secret out of maester-config.json: pass it with -ServiceSetting or the
    MAESTER_WEY_FALCON_API_CLIENTSECRET environment variable.

    Create the API client in the Falcon console (Support and resources > API clients and keys) with read scopes
    only: Prevention policies: Read and Sensor update policies: Read. A test whose scope the client lacks is
    skipped and says which scope to add.

    .EXAMPLE
    Connect-Maester -Service WEY.FALCON.Api -ServiceSetting @{ ClientId = '<client id>'; ClientSecret = (Read-Host -AsSecureString 'Falcon client secret'); Cloud = 'eu-1' }

    .EXAMPLE
    Connect-Maester -Service WEY.FALCON.Api -ServiceSetting @{ ClientId = $id; ClientSecret = $secret; Cloud = 'us-1'; MemberCid = '<child CID>' }
    #>
    [CmdletBinding()]
    param(
        # The API client ID (32 hexadecimal characters).
        [Parameter(Mandatory)]
        [string] $ClientId,

        # The API client secret, as a SecureString or a string.
        [Parameter(Mandatory)]
        [object] $ClientSecret,

        # The Falcon cloud of the CID.
        [ValidateSet('us-1', 'us-2', 'eu-1', 'us-gov-1', 'us-gov-2')]
        [string] $Cloud = 'us-1',

        # A child CID to check in a Flight Control (multi-CID) environment.
        [string] $MemberCid
    )

    # Spaces or a line break around a pasted value make the token request fail, so they are removed.
    $ClientId = $ClientId.Trim()
    if ($ClientId -notmatch '^[a-fA-F0-9]{32}$') { throw 'ClientId must be the 32 hexadecimal characters of a Falcon API client ID.' }
    $plain = if ($ClientSecret -is [securestring]) { [System.Net.NetworkCredential]::new('', $ClientSecret).Password } else { [string]$ClientSecret }
    $plain = $plain.Trim()
    if ($plain -notmatch '^\w{40}$') { $plain = $null; throw 'ClientSecret must be the 40 characters of a Falcon API client secret.' }
    $secureSecret = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $MemberCid = ([string]$MemberCid).Trim()
    if ($MemberCid -and $MemberCid -notmatch '^[a-fA-F0-9]{32}(-\w{2})?$') { $plain = $null; throw 'MemberCid must be a Falcon CID (32 hexadecimal characters, optionally with a -xx checksum).' }

    $hostName = switch ($Cloud) {
        'us-1' { 'https://api.crowdstrike.com' }
        'us-2' { 'https://api.us-2.crowdstrike.com' }
        'eu-1' { 'https://api.eu-1.crowdstrike.com' }
        'us-gov-1' { 'https://api.laggar.gcw.crowdstrike.com' }
        'us-gov-2' { 'https://api.us-gov-2.crowdstrike.mil' }
    }

    # Request-FalconToken checks the client (POST /oauth2/token); a wrong client, secret or cloud fails here.
    $tokenParams = @{ ClientId = $ClientId; ClientSecret = $plain; Hostname = $hostName }
    if ($MemberCid) { $tokenParams['MemberCid'] = $MemberCid }
    try {
        Request-FalconToken @tokenParams -ErrorAction SilentlyContinue -ErrorVariable tokenErrors 4>$null
    } catch {
        $tokenErrors = @($_)
    } finally {
        $plain = $null
        $tokenParams = $null
    }
    $token = Test-FalconToken -ErrorAction SilentlyContinue
    if (-not ($token -and $token.Token)) {
        $why = @($tokenErrors | ForEach-Object { $_.Exception.Message } | Select-Object -First 1)
        throw "Falcon did not issue a token for the API client $ClientId on $Cloud. Check the client ID, secret and cloud. $why".Trim()
    }

    # Falcon may answer from another cloud (X-Cs-Region); PSFalcon then moves to that host.
    $hostName = [string]$token.Hostname
    $cloudName = switch ($hostName) {
        'https://api.crowdstrike.com' { 'us-1' }
        'https://api.us-2.crowdstrike.com' { 'us-2' }
        'https://api.eu-1.crowdstrike.com' { 'eu-1' }
        'https://api.laggar.gcw.crowdstrike.com' { 'us-gov-1' }
        'https://api.us-gov-2.crowdstrike.mil' { 'us-gov-2' }
        default { $Cloud }
    }

    # The secret is kept as a SecureString in this session only; it is never written to a file or a report.
    $state = @{ ClientId = $ClientId; ClientSecret = $secureSecret; Cloud = $cloudName; Hostname = $hostName; MemberCid = $MemberCid }
    $account = "API client $ClientId"
    if ($MemberCid) { $account += ", member CID $MemberCid" }
    Set-MtConnectionState -Value $state -Tenant ([uri]$hostName).Host -Account $account
}

function Test-WEYFalcon {
    <#
    .SYNOPSIS
    Returns $true when Connect-WEYFalcon has run in this session. Tests that need WEY.FALCON.Api are skipped otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    [bool](Get-MtConnectionState)
}

function Disconnect-WEYFalcon {
    <#
    .SYNOPSIS
    Forgets the Falcon connection of this pack. The token PSFalcon holds expires on its own (after 30 minutes).
    #>
    [CmdletBinding()]
    param()

    Clear-MtConnectionState
}
