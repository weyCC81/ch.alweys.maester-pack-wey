function Test-WeySendGridEuRegion {
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

    # The account: an EU regional account or subuser answers only on api.eu.sendgrid.com.
    $rows.Add([pscustomobject]@{ Object = 'Connected account'; Kind = 'account'; Region = $(if ($state.Region -eq 'EU') { 'eu' } else { 'global (US)' }); InEu = $state.Region -eq 'EU' })

    # Subusers, with their region.
    $notChecked = @()
    if ('subusers.read' -in $scopes) {
        foreach ($s in @(Get-WeySendGridPage -Path '/v3/subusers?include_region=true' | Where-Object { $_ -and $_.username })) {
            $region = if ($s.region) { [string]$s.region } else { 'unknown' }
            $rows.Add([pscustomobject]@{ Object = [string]$s.username; Kind = 'subuser'; Region = $region; InEu = $region -eq 'eu' })
        }
    } else { $notChecked += 'subusers (scope subusers.read)' }

    # Dedicated sending IPs, with their region.
    if ('ips.read' -in $scopes) {
        $after = $null
        do {
            $path = '/v3/send_ips/ips?include_region=true&limit=100' + $(if ($after) { "&after_key=$after" } else { '' })
            $page = Invoke-WeySendGridRequest -Path $path
            foreach ($ip in @($page.result | Where-Object { $_ -and $_.ip })) {
                $region = if ($ip.region) { [string]$ip.region } else { 'unknown' }
                $rows.Add([pscustomobject]@{ Object = [string]$ip.ip; Kind = 'IP'; Region = $region; InEu = $region -eq 'eu' })
            }
            $after = if ($page._metadata -and $page._metadata.next_params) { [string]$page._metadata.next_params.after_key } else { $null }
        } while ($after -match '^\d+$')
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
