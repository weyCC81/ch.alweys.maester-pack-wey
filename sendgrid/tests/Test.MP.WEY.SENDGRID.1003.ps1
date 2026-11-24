function Test-WEYSendGridEnforcedTls {
    <#
    .SYNOPSIS
    Checks that SendGrid delivers mail only over TLS (Enforced TLS), at a minimum TLS version.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.SENDGRID.1003',
        Title              = 'SendGrid: Enforced TLS is on',
        Severity           = 'Medium',
        Product            = 'sendgrid',
        Feature            = 'mail-flow',
        Area               = 'email-protection',
        ResourceType       = 'Tenant',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1557',
        Service            = 'WEY.SENDGRID.Api'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Also require a valid certificate from the receiving server. Off by default: some receivers use self-signed certificates.
        [bool] $RequireValidCertificate = $false,

        # The lowest TLS version SendGrid may use.
        [ValidateSet('1.1', '1.2', '1.3')]
        [string] $MinimumVersion = '1.2'
    )

    if (-not (Test-WEYSendGridScope -Scope 'user.settings.enforced_tls.read')) { return $null }

    Connect-WEYSendGridModule
    $tls = Get-SGEnforcedTls
    $version = if ($null -ne $tls.Version) { [string]$tls.Version } else { '' }
    $versionOk = -not $version -or ([version]$version -ge [version]$MinimumVersion)

    $checks = @(
        [pscustomobject]@{ Check = 'Require TLS'; Value = $(if ($tls.RequireTls) { 'on' } else { 'off' }); Expected = 'on'; Passed = [bool]$tls.RequireTls }
        [pscustomobject]@{ Check = 'Require a valid certificate'; Value = $(if ($tls.RequireValidCert) { 'on' } else { 'off' }); Expected = $(if ($RequireValidCertificate) { 'on' } else { 'on (recommended)' }); Passed = [bool]$tls.RequireValidCert -or -not $RequireValidCertificate }
        [pscustomobject]@{ Check = 'Minimum TLS version'; Value = $(if ($version) { $version } else { 'not set' }); Expected = "$MinimumVersion or newer"; Passed = $versionOk }
    )
    $failing = @($checks | Where-Object { -not $_.Passed })
    $passed = $failing.Count -eq 0

    $summary = if ($passed) {
        'Well done. SendGrid delivers mail only over TLS.'
    } elseif (-not $tls.RequireTls) {
        'SendGrid does not enforce TLS: when a receiving server does not offer TLS, mail is delivered in clear text.'
    } else {
        "Enforced TLS does not meet the settings: $($failing.Check -join ', ')."
    }
    $rows = foreach ($c in $checks) {
        $mark = if ($c.Passed) { '✅ Pass' } else { '❌ Fail' }
        "| $($c.Check) | $($c.Value) | $($c.Expected) | $mark |"
    }
    Add-MtTestResultDetail -Result ("$summary`n`n| Setting | Value | Expected | Result |`n| --- | --- | --- | --- |`n" + ($rows -join "`n"))
    $passed
}
