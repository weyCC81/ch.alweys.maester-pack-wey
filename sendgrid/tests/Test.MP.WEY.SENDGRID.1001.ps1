function Get-WEYSendGridDomainInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.SENDGRID.1001: one instance per authenticated domain in SendGrid.

    .DESCRIPTION
    The instance ID is the domain name; a domain authenticated more than once (for the parent and a subuser,
    or with two subdomains) gets its SendGrid ID after the name. The field User names the SendGrid user or
    subuser the domain belongs to, which the report groups and filters by.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    if ($state -and 'whitelabel.read' -notin @($state.Scopes)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The SendGrid API key lacks the scope whitelabel.read. Give the key read access to Domain Authentication (Settings > API Keys > Restricted Access).'
        return
    }

    Connect-WEYSendGridModule
    # Get-SGAuthenticatedDomain reads every page; -ShowDNS keeps the DNS records.
    $domains = @(Get-SGAuthenticatedDomain -ShowDNS | Where-Object { $_ -and $_.Domain })
    $shared = @($domains | Group-Object { ([string]$_.domain).ToLowerInvariant() } | Where-Object Count -GT 1 | ForEach-Object Name)
    foreach ($d in ($domains | Sort-Object domain, id)) {
        $name = ([string]$d.domain).Trim().TrimEnd('.').ToLowerInvariant()
        $suffix = if ($name -in $shared) { "$name.$($d.id)" } else { $name }
        if ($suffix -notmatch '^[a-z0-9][a-z0-9._-]{0,127}\z') { $suffix = "domain-$($d.id)" }
        $fqdn = if ($d.subdomain) { "$($d.subdomain).$name" } else { $name }
        # Names come from SendGrid; titles and Fields get them as plain text (see ConvertTo-WEYSendGridPlainText).
        $title = "SendGrid: authenticated domain '$(ConvertTo-WEYSendGridPlainText $name)' is validated"
        if ($name -in $shared) { $title += " ($(ConvertTo-WEYSendGridPlainText $fqdn))" }
        $instance = [ordered]@{ Id = $suffix; Title = $title; Data = $d }
        if ($d.username) { $instance['Fields'] = @{ User = ConvertTo-WEYSendGridPlainText $d.username } }
        [pscustomobject]$instance
    }
}

function Test-WEYSendGridDomainValidated {
    <#
    .SYNOPSIS
    Checks that an authenticated domain in SendGrid is validated: its DKIM and SPF (return path) DNS records
    are published, so mail SendGrid sends for it passes DKIM and aligns with DMARC.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.SENDGRID.1001',
        Title              = 'SendGrid: every authenticated domain is validated',
        Severity           = 'High',
        Product            = 'sendgrid',
        Feature            = 'email-authentication',
        Area               = 'email-protection',
        ResourceType       = 'Domain',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1566',
        Service            = 'WEY.SENDGRID.Api',
        InstanceSource     = 'Get-WEYSendGridDomainInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The authenticated domain to check, supplied by the engine.
        $Instance
    )

    $d = $Instance.Data
    $safeName = Get-MtSafeMarkdown -Text ([string]$d.domain)
    $passed = [bool]$d.valid

    $rows = foreach ($p in @($d.dns.PSObject.Properties)) {
        $r = $p.Value
        if ($null -eq $r -or -not $r.PSObject.Properties['host']) { continue }
        $mark = if ($r.valid) { '✅ Published' } else { '❌ Missing or wrong' }
        "| $(Get-MtSafeMarkdown -Text $p.Name) | $(Get-MtSafeMarkdown -Text ([string]$r.type).ToUpperInvariant()) | $(Get-MtSafeMarkdown -Text ([string]$r.host)) | $(Get-MtSafeMarkdown -Text ([string]$r.data)) | $mark |"
    }
    # SendGridTools returns the fields in PascalCase (AutomaticSecurity); Dns keeps SendGrid's own records.
    $security = if ($d.AutomaticSecurity) { 'Automated security (CNAME records), so SendGrid rotates the DKIM keys.' } else { 'Manual security (TXT and MX records): rotate the DKIM key yourself.' }
    $lastCheck = if ($d.LastValidationAttemptAt) { ' SendGrid last checked the records on ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$d.LastValidationAttemptAt).UtcDateTime.ToString('yyyy-MM-dd HH:mm') + ' UTC.' } else { '' }

    $summary = if ($passed) {
        "Well done. SendGrid has validated ${safeName}: its DKIM and SPF records are published."
    } else {
        "SendGrid has not validated ${safeName}: mail it sends for this domain fails DKIM and DMARC alignment until the records below are published.$lastCheck"
    }
    $result = $summary
    if ($rows) { $result += "`n`n| Record | Type | Host | Value | DNS |`n| --- | --- | --- | --- | --- |`n" + ($rows -join "`n") }
    $result += "`n`n$security"
    if ($d.username) { $result += " Belongs to the SendGrid user $(Get-MtSafeMarkdown -Text ([string]$d.username))." }

    Add-MtTestResultDetail -Result $result
    $passed
}
