function Get-WEYFalconPreventionPolicyInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.FALCON.1001: one instance per enabled prevention policy in Falcon.

    .DESCRIPTION
    The instance ID is the policy ID. Disabled policies apply to no host and are left out. The field Platform
    names the policy's platform (Windows, Mac, Linux), which the report groups and filters by.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    Connect-WEYFalconModule
    # -Detailed reads the combined endpoint with every setting; -All reads every page.
    $read = Get-WEYFalconData -Command Get-FalconPreventionPolicy -Scope 'Prevention policies: Read' -Parameter @{ Detailed = $true; All = $true }
    if ($read.Skipped) { return }
    foreach ($p in ($read.Items | Where-Object { $_.id -and $_.enabled -eq $true } | Sort-Object platform_name, precedence, name)) {
        $id = [string]$p.id
        [pscustomobject]@{
            Id     = $(if ($id -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z') { $id } else { 'policy-' + ($id -replace '[^A-Za-z0-9._-]', '') })
            # Policy names are free text: the title and fields get them as plain text.
            Title  = "Falcon: prevention policy '$(ConvertTo-WEYFalconPlainText $p.name)' has the key protections on"
            Fields = @{ Platform = ConvertTo-WEYFalconPlainText $p.platform_name }
            Data   = $p
        }
    }
}

function Test-WEYFalconPreventionPolicy {
    <#
    .SYNOPSIS
    Checks that an enabled Falcon prevention policy shows the Falcon icon and blocks malware: Cloud-based
    anti-malware, Cloud anti-malware for Microsoft Office files and Sensor-based anti-malware prevent at the
    minimum level or higher.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.FALCON.1001',
        Title              = 'Falcon: prevention policies have the key protections on',
        Severity           = 'High',
        Product            = 'crowdstrike',
        Feature            = 'prevention-policy',
        Area               = 'endpoint-protection',
        ResourceType       = 'Policy',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1204',
        Service            = 'WEY.FALCON.Api',
        InstanceSource     = 'Get-WEYFalconPreventionPolicyInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The prevention policy to check, supplied by the engine.
        $Instance,

        # The lowest prevention level the anti-malware sliders may have.
        [ValidateSet('CAUTIOUS', 'MODERATE', 'AGGRESSIVE', 'EXTRA_AGGRESSIVE')]
        [string] $MinimumPreventionLevel = 'MODERATE',

        # Require the setting Show Falcon icon to be on.
        [bool] $RequireFalconIcon = $true
    )

    $policy = $Instance.Data
    $safeName = Get-MtSafeMarkdown -Text ([string]$policy.name)
    $levels = @('DISABLED', 'CAUTIOUS', 'MODERATE', 'AGGRESSIVE', 'EXTRA_AGGRESSIVE')
    $minimum = [array]::IndexOf($levels, $MinimumPreventionLevel)

    # Every setting of the policy, from all its categories.
    $settings = @(foreach ($category in @($policy.prevention_settings)) { @($category.settings) | Where-Object { $null -ne $_ } })

    # The settings to check, by the ID the Falcon API uses or by the name the console shows.
    $wanted = @(
        [pscustomobject]@{ Name = 'Cloud-based anti-malware'; Ids = @('CloudAntiMalware'); Names = @('Cloud-Based Anti-Malware'); Kind = 'slider' }
        [pscustomobject]@{ Name = 'Cloud anti-malware for Microsoft Office files'; Ids = @('CloudAntiMalwareForMicrosoftOfficeFiles'); Names = @('Cloud Anti-malware For Microsoft Office Files'); Kind = 'slider' }
        [pscustomobject]@{ Name = 'Sensor-based anti-malware'; Ids = @('OnSensorMLSlider'); Names = @('Sensor-Based Anti-Malware'); Kind = 'slider' }
    )
    if ($RequireFalconIcon) {
        $wanted += [pscustomobject]@{ Name = 'Show Falcon icon'; Ids = @(); Names = @('Show Falcon icon'); Kind = 'toggle' }
    }

    $checks = @(foreach ($w in $wanted) {
        $s = $settings | Where-Object { ([string]$_.id -in $w.Ids) -or (([string]$_.name).Trim() -in $w.Names) } | Select-Object -First 1
        if (-not $s) {
            # The platform has no such setting (Office files is Windows only, for example).
            [pscustomobject]@{ Setting = $w.Name; Value = 'not in this policy'; Expected = '-'; State = 'NotApplicable' }
            continue
        }
        if ($w.Kind -eq 'toggle') {
            $on = [bool]$s.value.enabled
            [pscustomobject]@{ Setting = $w.Name; Value = $(if ($on) { 'on' } else { 'off' }); Expected = 'on'; State = $(if ($on) { 'Pass' } else { 'Fail' }) }
        } else {
            $prevention = ([string]$s.value.prevention).ToUpperInvariant()
            if (-not $prevention) { $prevention = 'DISABLED' }
            $detection = ([string]$s.value.detection).ToUpperInvariant()
            $value = "prevention $prevention"
            if ($detection) { $value += ", detection $detection" }
            $ok = [array]::IndexOf($levels, $prevention) -ge $minimum
            [pscustomobject]@{ Setting = $w.Name; Value = $value; Expected = "prevention $MinimumPreventionLevel or higher"; State = $(if ($ok) { 'Pass' } else { 'Fail' }) }
        }
    })
    $failing = @($checks | Where-Object State -EQ 'Fail')
    $checked = @($checks | Where-Object State -NE 'NotApplicable')
    $passed = $failing.Count -eq 0 -and $checked.Count -gt 0

    $platform = Get-MtSafeMarkdown -Text ([string]$policy.platform_name)
    $summary = if ($passed) {
        "Well done. The $platform prevention policy $safeName has the key protections on."
    } elseif ($checked.Count -eq 0) {
        "The $platform prevention policy $safeName has none of the settings this test checks."
    } else {
        "The $platform prevention policy $safeName does not protect enough: $($failing.Setting -join ', ')."
    }
    $rows = foreach ($c in $checks) {
        $mark = switch ($c.State) { 'Pass' { '✅ Pass' } 'Fail' { '❌ Fail' } default { 'Not applicable' } }
        "| $($c.Setting) | $(Get-MtSafeMarkdown -Text $c.Value) | $($c.Expected) | $mark |"
    }
    $result = "$summary`n`n| Setting | Value | Expected | Result |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    $groups = @($policy.groups | Where-Object { $_ -and $_.name } | ForEach-Object { Get-MtSafeMarkdown -Text ([string]$_.name) })
    if ([string]$policy.name -eq 'platform_default') {
        $result += "`n`nThis is the default policy: it applies to every $platform host that no other policy covers."
    } elseif ($groups) {
        $result += "`n`nApplies to the host groups: $($groups -join ', ')."
    } else {
        $result += "`n`nThe policy is assigned to no host group, so it applies to no host."
    }

    Add-MtTestResultDetail -Result $result
    $passed
}
