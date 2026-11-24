function Get-WEYDmarcDomain {
    <#
    .SYNOPSIS
    Returns the PowerDMARC domains in scope of the connection, each with its ID, name and customer account.

    .DESCRIPTION
    Default mode: the domains of the token's own account (AccountId and AccountName are empty). Reseller mode:
    the domains of the connected customer account, or of every customer account when the connection has no
    AccountId. The domains are listed per account, so each one knows the account it belongs to; a domain
    that two accounts hold is returned once for each.

    AccountId (Reseller mode) lists the domains of that customer account instead of the connection's.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Reseller mode: the customer account to list. 0 uses the connection's AccountId (every account when
        # the connection has none).
        [int] $AccountId = 0
    )

    $state = Connect-WEYDmarcPowerDmarcModule

    if ($state.Mode -ne 'Reseller') {
        Get-PDDomain -ErrorAction Stop | ConvertTo-WEYDmarcDomain
        return
    }

    $accountId = if ($AccountId -gt 0) { $AccountId } else { [int]$state.AccountId }
    $accounts = if ($accountId -gt 0) {
        # The name is only for the report: a token that may list domains but not read the account still works.
        $account = try { Get-PDAccount -AccountId $accountId -ErrorAction Stop } catch { $null }
        @([pscustomobject]@{ id = $accountId; name = $(if ($account -and $account.name) { $account.name } else { "Account $accountId" }) })
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

function ConvertTo-WEYDmarcPlainText {
    <#
    .SYNOPSIS
    Returns a name from PowerDMARC as plain text for a result title or field: without the characters that make
    markdown links, images, HTML, code or tables ([ ] ( ) < > ` |) and without line breaks.

    .DESCRIPTION
    Titles and fields are shown as text in the HTML report, but other outputs (the markdown export, Teams or
    email) may render them as markdown. Domain names never contain these characters; account names keep their
    readable text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Text
    )

    ([string]$Text -replace '[\[\]()<>`|]', '' -replace '\s+', ' ').Trim()
}
