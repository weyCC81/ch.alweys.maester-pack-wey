function Connect-WeyDmarcPowerDmarcModule {
    <#
    .SYNOPSIS
    Connects the PowerDMARC module that is loaded now, from the settings Connect-WeyDmarcPowerDmarc kept.

    .DESCRIPTION
    Returns the connection settings (BaseUri, Mode, AccountId). Call it before any PowerDMARC command: the
    module keeps its connection inside the module, and the copy loaded for the tests may not be the one that
    was loaded when Connect-Maester ran. Connect-PowerDMARC sends no request, so this costs nothing.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $state = Get-MtConnectionState -Service WEY.POWERDMARC.Api
    if (-not $state) { throw 'Not connected to PowerDMARC. Run Connect-Maester -Service WEY.POWERDMARC.Api first.' }

    $connectParams = @{ ApiToken = $state.ApiToken; Mode = $state.Mode; BaseUri = $state.BaseUri; ShowBanner = $false }
    if ($state.Mode -eq 'Reseller' -and $state.AccountId -gt 0) { $connectParams['AccountId'] = $state.AccountId }
    Connect-PowerDMARC @connectParams
    $state
}
