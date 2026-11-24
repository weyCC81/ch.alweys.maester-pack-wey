function Get-WEYDmarcTenantDomainInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.POWERDMARC.1002: one instance per verified email domain of the Microsoft 365
    tenant, and one (not-in-tenant) for the PowerDMARC domains the tenant does not have.

    .DESCRIPTION
    Reads the tenant's domains from Microsoft Graph (GET /domains) and the PowerDMARC domains once, compares
    them here and gives each instance the outcome in Data, so the test itself sends no request.

    The domains compared are the verified tenant domains whose supportedServices contain Email. The
    *.onmicrosoft.com domains are left out unless the setting WEY.POWERDMARC.IncludeInitialDomains is true.
    In Reseller mode the PowerDMARC domains are those of the setting WEY.POWERDMARC.TenantAccountId, else of
    the connection's AccountId, else of every customer account. The not-in-tenant instance is made only when
    the domains come from one account (or in Default mode): with every customer account it would list the
    domains of all other customers.

    The instance ID is the domain name, so it stays the same from run to run and can be excluded in
    maester-config.json. A name the engine cannot use as an ID falls back to domain-<n>.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $includeInitial = [bool](Get-MtSetting -Name 'WEY.POWERDMARC.IncludeInitialDomains' -Default $false)
    $tenantAccountId = [int](Get-MtSetting -Name 'WEY.POWERDMARC.TenantAccountId' -Default 0)

    # Tenant domains: read-only, Domain.Read.All (or Directory.Read.All, which Connect-Maester asks for).
    $graphDomains = @(Invoke-MtGraphRequest -RelativeUri 'domains' -Select 'id', 'isVerified', 'isInitial', 'supportedServices', 'authenticationType' -ErrorAction Stop)
    $tenantDomains = @(
        foreach ($d in $graphDomains) {
            if ($null -eq $d -or -not $d.id) { continue }
            $name = ([string]$d.id).Trim().TrimEnd('.').ToLowerInvariant()
            $isInitial = [bool]$d.isInitial -or $name -like '*.onmicrosoft.com'
            [pscustomobject]@{
                Name               = $name
                IsVerified         = [bool]$d.isVerified
                IsInitial          = $isInitial
                SendsMail          = @($d.supportedServices) -contains 'Email'
                AuthenticationType = [string]$d.authenticationType
            }
        }
    ) | Sort-Object Name -Unique
    $checked = @($tenantDomains | Where-Object { $_.IsVerified -and $_.SendsMail -and ($includeInitial -or -not $_.IsInitial) })
    $tenantNames = @($tenantDomains | ForEach-Object Name)

    # PowerDMARC domains in scope, and in words for the report.
    $state = Get-MtConnectionState -Service WEY.POWERDMARC.Api
    $isReseller = $state.Mode -eq 'Reseller'
    $accountId = if (-not $isReseller) { 0 } elseif ($tenantAccountId -gt 0) { $tenantAccountId } else { [int]$state.AccountId }
    $pdDomains = @(Get-WEYDmarcDomain -AccountId $accountId)
    $accountName = if ($accountId -gt 0) {
        $named = @($pdDomains | Where-Object AccountName | Select-Object -First 1)
        if ($named) { [string]$named[0].AccountName } else { "Account $accountId" }
    } else { $null }
    $scope = if (-not $isReseller) { 'PowerDMARC' } elseif ($accountId -gt 0) { "the PowerDMARC customer account '$(ConvertTo-WEYDmarcPlainText $accountName)'" } else { 'any PowerDMARC customer account' }

    foreach ($domain in $checked) {
        $found = @($pdDomains | Where-Object Name -EQ $domain.Name)
        # A subdomain whose parent domain is onboarded: the parent's DMARC policy (sp=) covers it.
        $parents = @(
            if ($found.Count -eq 0) {
                $pdDomains | Where-Object { $domain.Name.EndsWith(".$($_.Name)") } | Sort-Object { $_.Name.Length } -Descending
            }
        )
        $suffix = if ($domain.Name -match '^[a-z0-9][a-z0-9._-]{0,127}\z') { $domain.Name } else { "domain-$([array]::IndexOf($tenantNames, $domain.Name) + 1)" }
        $plainName = ConvertTo-WEYDmarcPlainText $domain.Name
        $instance = [ordered]@{
            Id    = $suffix
            Title = "PowerDMARC: tenant domain '$plainName' is onboarded"
            Data  = [pscustomobject]@{ Kind = 'Domain'; Domain = $domain; Found = $found; Parents = $parents; Scope = $scope; AllAccounts = $isReseller -and $accountId -eq 0 }
        }
        $accounts = if ($accountName) { @($accountName) } else { @($found + $parents | Where-Object AccountName | ForEach-Object AccountName | Select-Object -Unique) }
        if ($accounts) { $instance['Fields'] = @{ Account = ConvertTo-WEYDmarcPlainText ($accounts -join ', ') } }
        [pscustomobject]$instance
    }

    if (-not $isReseller -or $accountId -gt 0) {
        $outside = @($pdDomains | Where-Object Name -NotIn $tenantNames | Sort-Object Name -Unique)
        # Subdomains of a tenant domain belong to the tenant's organisation (another sender, say).
        $subdomains = @($outside | Where-Object { $n = $_.Name; $tenantNames | Where-Object { $n.EndsWith(".$_") } })
        $instance = [ordered]@{
            Id    = 'not-in-tenant'
            Title = 'PowerDMARC: every domain in PowerDMARC is a domain of the tenant'
            Data  = [pscustomobject]@{ Kind = 'NotInTenant'; Outside = @($outside | Where-Object Name -NotIn @($subdomains | ForEach-Object Name)); Subdomains = $subdomains; Scope = $scope }
        }
        if ($accountName) { $instance['Fields'] = @{ Account = ConvertTo-WEYDmarcPlainText $accountName } }
        [pscustomobject]$instance
    }
}

function Test-WEYDmarcTenantDomain {
    <#
    .SYNOPSIS
    Checks that every verified email domain of the Microsoft 365 tenant is onboarded in PowerDMARC, and lists
    the PowerDMARC domains that the tenant does not have.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.POWERDMARC.1002',
        Title              = 'PowerDMARC: every email domain of the Microsoft 365 tenant is onboarded',
        Severity           = 'Medium',
        # The fix is made in PowerDMARC. Exchange Online is related: its admins look for domain checks there.
        Product            = 'PowerDMARC',
        RelatedProduct     = 'exchange',
        Feature            = 'email-authentication',
        Area               = 'email-protection',
        ResourceType       = 'Domain',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1566',
        Service            = ('Graph', 'WEY.POWERDMARC.Api'),
        Permission         = 'Graph:Scope:Domain.Read.All|Graph:Scope:Directory.Read.All',
        InstanceSource     = 'Get-WEYDmarcTenantDomainInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The tenant domain, or the not-in-tenant list, supplied by the engine.
        $Instance
    )

    $data = $Instance.Data

    if ($data.Kind -eq 'NotInTenant') {
        $outside = @($data.Outside)
        $subdomains = @($data.Subdomains)
        if ($outside.Count -eq 0) {
            $result = "Well done. Every domain in $($data.Scope) is a domain of the Microsoft 365 tenant."
        } else {
            $result = "$($outside.Count) domain(s) in $($data.Scope) are not domains of the Microsoft 365 tenant. Check that they belong to this customer: remove a domain that is no longer used, or add it to the tenant when it should send mail from Microsoft 365.`n`n" +
                (($outside | ForEach-Object { "- $(Get-MtSafeMarkdown -Text $_.Name)" }) -join "`n")
        }
        if ($subdomains.Count -gt 0) {
            $result += "`n`n**Subdomains of tenant domains** (not counted: they belong to the tenant's organisation, for example another sender)`n`n" +
                (($subdomains | ForEach-Object { "- $(Get-MtSafeMarkdown -Text $_.Name)" }) -join "`n")
        }
        # Only a person can tell whether such a domain belongs to this customer: Investigate, not Failed.
        Add-MtTestResultDetail -Result $result -Investigate:($outside.Count -gt 0)
        return $true
    }

    $domain = $data.Domain
    $safeName = Get-MtSafeMarkdown -Text $domain.Name
    $found = @($data.Found)
    $parents = @($data.Parents)
    $kind = if ($domain.IsInitial) { 'onmicrosoft.com' } elseif ($domain.AuthenticationType) { $domain.AuthenticationType.ToLowerInvariant() } else { 'verified' }

    if ($found.Count -gt 0) {
        # Compared with every customer account: name the one(s) that hold the domain.
        $where = if ($data.AllAccounts -and @($found | Where-Object AccountName).Count -gt 0) {
            ' (customer account: ' + ((@($found | ForEach-Object AccountName | Select-Object -Unique) | ForEach-Object { Get-MtSafeMarkdown -Text $_ }) -join ', ') + ')'
        } else { '' }
        $inScope = if ($data.AllAccounts) { 'PowerDMARC' } else { $data.Scope }
        Add-MtTestResultDetail -Result "Well done. The $kind tenant domain $safeName is onboarded in $inScope$where, so its DMARC reports are collected and its records can be managed there."
        return $true
    }

    if ($parents.Count -gt 0) {
        $parent = $parents[0]
        $safeParent = Get-MtSafeMarkdown -Text $parent.Name
        Add-MtTestResultDetail -Investigate -Result ("The $kind tenant domain $safeName is not onboarded in $($data.Scope), but its parent domain $safeParent is. " +
            "The parent's DMARC record covers it through its subdomain policy (sp=), but PowerDMARC shows no reports or Hosted SPF of its own for it. " +
            "Onboard $safeName when it sends mail from its own servers or services.")
        return $true
    }

    Add-MtTestResultDetail -Result ("The $kind tenant domain $safeName sends mail from Microsoft 365 but is not onboarded in $($data.Scope). " +
        "Without it, PowerDMARC collects no DMARC reports for the domain and does not manage its DMARC, SPF or DKIM records, so spoofing of it goes unnoticed.`n`n" +
        "Add $safeName in PowerDMARC and publish the DMARC record it shows.")
    $false
}
