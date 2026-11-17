function Get-WEYDmarcHostedSpfInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.POWERDMARC.1001: one instance per PowerDMARC domain, grouped by customer account.

    .DESCRIPTION
    The instance ID is the domain name, so it stays the same from run to run and can be excluded in
    maester-config.json. A domain that two customer accounts hold gets the account ID after its name, and a
    name the engine cannot use as an ID falls back to the domain ID. In Reseller mode each instance has the
    field Account (the customer account's name), which the report groups and filters by.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # The same domain listed twice in one account is checked once.
    $domains = @(Get-WEYDmarcDomain | Sort-Object Name, AccountName, Id | Sort-Object AccountId, Id -Unique | Sort-Object Name, AccountName)
    $shared = @($domains | Group-Object Name | Where-Object Count -GT 1 | ForEach-Object Name)

    foreach ($domain in $domains) {
        $suffix = if ($domain.Name -in $shared -and $domain.AccountId) { "$($domain.Name).$($domain.AccountId)" } else { $domain.Name }
        if ($suffix -notmatch '^[a-z0-9][a-z0-9._-]{0,127}\z') { $suffix = "domain-$($domain.Id)" }
        $title = "PowerDMARC: Hosted SPF of '$($domain.Name)' is healthy"
        if ($domain.Name -in $shared -and $domain.AccountName) { $title += " ($($domain.AccountName))" }

        $instance = [ordered]@{ Id = $suffix; Title = $title; Data = $domain }
        if ($domain.AccountName) { $instance['Fields'] = @{ Account = [string]$domain.AccountName } }
        [pscustomobject]$instance
    }
}

function Test-WEYDmarcHostedSpf {
    <#
    .SYNOPSIS
    Checks the Hosted SPF (PowerSPF) record of each PowerDMARC domain: DNS lookups, void lookups, errors and the all mechanism.
    #>
    [MaesterTest(
        Id             = 'MP.WEY.POWERDMARC.1001',
        Title          = 'PowerDMARC: Hosted SPF of every domain is healthy',
        Severity       = 'High',
        # The fix is made in PowerDMARC. Exchange Online is related: its admins look for SPF checks there.
        Product            = 'PowerDMARC',
        RelatedProduct     = 'exchange',
        Feature            = 'email-authentication',
        Area               = 'email-protection',
        ResourceType       = 'Domain',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1566',
        Service        = 'WEY.POWERDMARC.Api',
        InstanceSource = 'Get-WEYDmarcHostedSpfInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The domain to check, supplied by the engine.
        $Instance,

        # The most DNS lookups the SPF record may need. RFC 7208 allows 10.
        [ValidateRange(1, 10)]
        [int] $MaximumLookups = 10,

        # The most lookups that may return nothing (void lookups). RFC 7208 recommends 2.
        [ValidateRange(0, 10)]
        [int] $MaximumVoidLookups = 2,

        # Accept only '-all' (hard fail). By default '~all' (soft fail) passes too.
        [bool] $RequireHardFail = $false
    )

    $domain = $Instance.Data
    $safeName = Get-MtSafeMarkdown -Text $domain.Name
    $null = Connect-WEYDmarcPowerDmarcModule
    $record = @(Get-PDHostedSPF -DomainId $domain.Id -ErrorAction Stop) | Select-Object -First 1

    if (-not $record) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Hosted SPF (PowerSPF) is not set up for $safeName."
        return $null
    }
    if (-not $record.is_enabled) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Hosted SPF (PowerSPF) is turned off for $safeName."
        return $null
    }

    $labels = if ($record.spf_labels -and $record.spf_labels.value) { $record.spf_labels.value } else { $null }
    $lookups = if ($null -ne $record.lookup_count) { [int]$record.lookup_count } elseif ($labels) { [int]$labels.lookups } else { 0 }
    $voidLookups = if ($labels -and $null -ne $labels.void_lookups) { [int]$labels.void_lookups } else { 0 }
    $errors = @(@($(if ($labels) { $labels.allErrors; $labels.errors })) | Where-Object { $_ } | ForEach-Object { if ($_ -is [string]) { $_ } else { $_ | ConvertTo-Json -Compress -Depth 5 } } | Sort-Object -Unique)
    $warnings = @(@($(if ($labels) { $labels.allWarnings; $labels.warnings })) | Where-Object { $_ } | ForEach-Object { if ($_ -is [string]) { $_ } else { $_ | ConvertTo-Json -Compress -Depth 5 } } | Sort-Object -Unique)
    $prefix = if ($record.all_mechanism_prefix) { [string]$record.all_mechanism_prefix } elseif ($labels -and $labels.prefix) { [string]$labels.prefix } else { '' }
    $allowedPrefixes = if ($RequireHardFail) { @('-') } else { @('-', '~') }
    $allText = if ($prefix) { "$($prefix)all" } else { 'no all mechanism' }
    $allExpected = if ($RequireHardFail) { '-all' } else { '-all or ~all' }

    $checks = @(
        [pscustomobject]@{ Check = 'DNS lookups'; Value = "$lookups"; Expected = "at most $MaximumLookups"; Passed = $lookups -le $MaximumLookups }
        [pscustomobject]@{ Check = 'Void lookups'; Value = "$voidLookups"; Expected = "at most $MaximumVoidLookups"; Passed = $voidLookups -le $MaximumVoidLookups }
        [pscustomobject]@{ Check = 'Errors'; Value = "$($errors.Count)"; Expected = 'none'; Passed = $errors.Count -eq 0 }
        [pscustomobject]@{ Check = 'All mechanism'; Value = $allText; Expected = $allExpected; Passed = $prefix -in $allowedPrefixes }
    )
    $failing = @($checks | Where-Object { -not $_.Passed })
    $passed = $failing.Count -eq 0

    $summary = if ($passed) {
        "Well done. The Hosted SPF record of $safeName passes every check."
    } else {
        "The Hosted SPF record of $safeName fails $($failing.Count) of $($checks.Count) checks: $($failing.Check -join ', ')."
    }
    $rows = foreach ($c in $checks) {
        $mark = if ($c.Passed) { '✅ Pass' } else { '❌ Fail' }
        "| $($c.Check) | $(Get-MtSafeMarkdown -Text $c.Value) | $($c.Expected) | $mark |"
    }
    $result = "$summary`n`n| Check | Value | Expected | Result |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    if ($record.spf_record) {
        $result += "`n`nPublished SPF record: ``$(([string]$record.spf_record) -replace '`', "'")``"
    }
    if ($errors.Count -gt 0) {
        $result += "`n`n**Errors**`n`n" + (($errors | ForEach-Object { "- $(Get-MtSafeMarkdown -Text $_)" }) -join "`n")
    }
    if ($warnings.Count -gt 0) {
        $result += "`n`n**Warnings** (they do not fail the test)`n`n" + (($warnings | ForEach-Object { "- $(Get-MtSafeMarkdown -Text $_)" }) -join "`n")
    }

    Add-MtTestResultDetail -Result $result
    $passed
}
