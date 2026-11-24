function Test-WEYSendGridEuRegion {
    <#
    .SYNOPSIS
    Checks that the SendGrid account, its subusers and its dedicated IPs are in the EU region, so mail and its
    data are processed and stored in the EU.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.SENDGRID.1004',
        Title              = 'SendGrid: the account and its IPs are in the EU',
        Severity           = 'Medium',
        Product            = 'sendgrid',
        Feature            = 'data-residency',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        UserImpact         = 'Medium',
        ImplementationCost = 'High',
        Mitre              = 'None',
        Service            = 'WEY.SENDGRID.Api'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    $scopes = @($state.Scopes)
    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    $notChecked = @()

    # The account: an EU regional account or subuser answers only on api.eu.sendgrid.com.
    $rows.Add([pscustomobject]@{ Object = 'Connected account'; Kind = 'account'; Region = $(if ($state.Region -eq 'EU') { 'eu' } else { 'global (US)' }); InEu = $state.Region -eq 'EU' })

    if ('subusers.read' -in $scopes -or 'ips.read' -in $scopes) { Connect-WEYSendGridModule }

    # Subusers, with their region.
    if ('subusers.read' -in $scopes) {
        foreach ($s in @(Get-WEYSendGridSubuser | Where-Object { $_ -and $_.Username })) {
            $region = if ($s.Region) { [string]$s.Region } else { 'unknown' }
            $rows.Add([pscustomobject]@{ Object = [string]$s.Username; Kind = 'subuser'; Region = $region; InEu = $region -eq 'eu' })
        }
    } else { $notChecked += 'subusers (scope subusers.read)' }

    # Dedicated sending IPs, with their region: Get-SGIPAddress -IncludeRegion reads every page.
    if ('ips.read' -in $scopes) {
        foreach ($ip in @(Get-SGIPAddress -IncludeRegion | Where-Object { $_ -and $_.Ip })) {
            $region = if ($ip.Region) { [string]$ip.Region } else { 'unknown' }
            $rows.Add([pscustomobject]@{ Object = [string]$ip.Ip; Kind = 'IP'; Region = $region; InEu = $region -eq 'eu' })
        }
    } else { $notChecked += 'dedicated IPs (scope ips.read)' }

    $outside = @($rows | Where-Object { -not $_.InEu })
    $passed = $outside.Count -eq 0

    $summary = if ($passed) {
        "Well done. The account and its $($rows.Count - 1) subusers and IPs are in the EU."
    } else {
        "$($outside.Count) of $($rows.Count) are outside the EU: mail sent through them is processed and stored in the US."
    }
    $table = foreach ($r in $rows) {
        $mark = if ($r.InEu) { '✅ EU' } else { '❌ Outside the EU' }
        "| $(Get-MtSafeMarkdown -Text $r.Object) | $($r.Kind) | $(Get-MtSafeMarkdown -Text $r.Region) | $mark |"
    }
    $result = "$summary`n`n| Object | Kind | Region | Result |`n| --- | --- | --- | --- |`n" + ($table -join "`n")
    if ($notChecked) { $result += "`n`nNot checked, because the API key lacks the scope: $($notChecked -join ', ')." }

    Add-MtTestResultDetail -Result $result
    $passed
}
