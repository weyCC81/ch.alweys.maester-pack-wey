function Get-WEYDmarcDomain {
    <#
    .SYNOPSIS
    Returns the PowerDMARC domains in scope of the connection, each with its ID, name and customer account.

    .DESCRIPTION
    Default mode: the domains of the token's own account (AccountId and AccountName are empty). Reseller mode:
    the domains of the connected customer account, or of every customer account when the connection has no
    AccountId. The domains are listed per account, so each one knows the account it belongs to; a domain
    that two accounts hold is returned once for each.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = Connect-WEYDmarcPowerDmarcModule

    if ($state.Mode -ne 'Reseller') {
        Get-PDDomain -ErrorAction Stop | ConvertTo-WEYDmarcDomain
        return
    }

    $accounts = if ($state.AccountId -gt 0) {
        # The name is only for the report: a token that may list domains but not read the account still works.
        $account = try { Get-PDAccount -AccountId $state.AccountId -ErrorAction Stop } catch { $null }
        @([pscustomobject]@{ id = $state.AccountId; name = $(if ($account -and $account.name) { $account.name } else { "Account $($state.AccountId)" }) })
    } else {
        @(Get-PDAccount -DateFrom ([datetime]'2000-01-01') -DateTo (Get-Date) -ErrorAction Stop)
    }

    foreach ($account in $accounts) {
        if ($null -eq $account) { continue }
        $accountName = if ($account.name) { [string]$account.name } else { "Account $($account.id)" }
        Get-PDDomain -AccountId ([int]$account.id) -ErrorAction Stop | ConvertTo-WEYDmarcDomain -AccountId ([int]$account.id) -AccountName $accountName
    }
}

function ConvertTo-WEYDmarcDomain {
    <#
    .SYNOPSIS
    Turns a PowerDMARC domain object into the Id, Name, AccountId and AccountName that the tests use.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $Domain,

        [Nullable[int]] $AccountId = $null,

        [string] $AccountName = $null
    )

    process {
        if ($null -eq $Domain) { return }
        $name = if ($Domain.PSObject.Properties['domain'] -and $Domain.domain) { [string]$Domain.domain } else { [string]$Domain.name }
        [pscustomobject]@{
            Id          = [int]$Domain.id
            Name        = $name.Trim().TrimEnd('.').ToLowerInvariant()
            AccountId   = $AccountId
            AccountName = $(if ($AccountName) { $AccountName } else { $null })
        }
    }
}
