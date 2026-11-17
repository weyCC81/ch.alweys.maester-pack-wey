function Test-WEYSendGridEuRegion {
    <#
    .SYNOPSIS
    Checks that the subusers and dedicated IPs of the SendGrid account are in the EU region, so mail sent
    through them and its data are processed and stored in the EU.

    .DESCRIPTION
    SendGridTools 0.4.7 reaches only the global host (api.sendgrid.com), so the connected account itself is
    always a global one and an EU regional account cannot be checked. The account is listed for information;
    the result depends on its subusers and dedicated IPs.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.SENDGRID.1004',
        Title              = 'SendGrid: subusers and dedicated IPs are in the EU',
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
    param(
        # The most dedicated IPs read. SendGridTools does not return the paging marker of /v3/send_ips/ips, so
        # they are read in one page.
        [ValidateRange(1, 5000)]
        [int] $MaximumIps = 1000
    )

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    $scopes = @($state.Scopes)
    if ('subusers.read' -notin $scopes -and 'ips.read' -notin $scopes) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The SendGrid API key lacks the scopes subusers.read and ips.read. Give the key read access to Subusers and IP Addresses (Settings > API Keys > Restricted Access).'
        return $null
    }
    Connect-WEYSendGridModule
    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    $notChecked = @()

    # Subusers, with their region (Get-SGSubuser does not ask for it, so Invoke-SGCommand does).
    if ('subusers.read' -in $scopes) {
        foreach ($s in @(Get-WEYSendGridPage -Namespace 'subusers' -Query 'include_region=true' | Where-Object { $_ -and $_.Username })) {
            $region = if ($s.Region) { [string]$s.Region } else { 'unknown' }
            $rows.Add([pscustomobject]@{ Object = [string]$s.Username; Kind = 'subuser'; Region = $region; InEu = $region -eq 'eu' })
        }
    } else { $notChecked += 'subusers (scope subusers.read)' }

    # Dedicated sending IPs, with their region (Get-SGIPAddress uses /v3/ips, which has no region).
    if ('ips.read' -in $scopes) {
        foreach ($ip in @(Invoke-SGCommand -WebMethod Get -Namespace 'send_ips/ips' -QueryParameters @('include_region=true', "limit=$MaximumIps") | Where-Object { $_ -and $_.Ip })) {
            $region = if ($ip.Region) { [string]$ip.Region } else { 'unknown' }
            $rows.Add([pscustomobject]@{ Object = [string]$ip.Ip; Kind = 'IP'; Region = $region; InEu = $region -eq 'eu' })
        }
    } else { $notChecked += 'dedicated IPs (scope ips.read)' }

    $outside = @($rows | Where-Object { -not $_.InEu })
    $passed = $outside.Count -eq 0

    $summary = if ($rows.Count -eq 0) {
        'The account has no subusers or dedicated IPs to check.'
    } elseif ($passed) {
        "Well done. All $($rows.Count) subusers and dedicated IPs are in the EU."
    } else {
        "$($outside.Count) of $($rows.Count) subusers and dedicated IPs are outside the EU: mail sent through them is processed and stored in the US."
    }
    $table = @('| Connected account | account | global (api.sendgrid.com) | ℹ️ Not counted: SendGridTools reaches only the global API |')
    $table += foreach ($r in $rows) {
        $mark = if ($r.InEu) { '✅ EU' } else { '❌ Outside the EU' }
        "| $(Get-MtSafeMarkdown -Text $r.Object) | $($r.Kind) | $(Get-MtSafeMarkdown -Text $r.Region) | $mark |"
    }
    $result = "$summary`n`n| Object | Kind | Region | Result |`n| --- | --- | --- | --- |`n" + ($table -join "`n")
    if ($notChecked) { $result += "`n`nNot checked, because the API key lacks the scope: $($notChecked -join ', ')." }
    $result += "`n`n**Limit:** an EU regional account or subuser (api.eu.sendgrid.com) cannot be checked by this pack, because SendGridTools 0.4.7 reaches only api.sendgrid.com."

    Add-MtTestResultDetail -Result $result
    $passed
}
