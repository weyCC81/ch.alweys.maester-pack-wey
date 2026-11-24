function Get-WEYFalconSensorUpdatePolicyInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.FALCON.1002: one instance per enabled sensor update policy in Falcon, with the
    sensor builds Falcon offers for the policy's platform.

    .DESCRIPTION
    The instance ID is the policy ID. Disabled policies apply to no host and are left out, and so are policies of
    platforms other than Windows, Mac and Linux (such as K8S). The field Platform names the policy's platform,
    which the report groups and filters by.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    Connect-WEYFalconModule
    $scope = 'Sensor update policies: Read'
    $read = Get-WEYFalconData -Command Get-FalconSensorUpdatePolicy -Scope $scope -Parameter @{ Detailed = $true; All = $true }
    if ($read.Skipped) { return }
    # Only the desktop and server sensors have builds and uninstall protection; other platforms (K8S) are left out.
    $policies = @($read.Items | Where-Object { $_.id -and $_.enabled -eq $true -and [string]$_.platform_name -in 'Windows', 'Mac', 'Linux' } | Sort-Object platform_name, precedence, name)

    # The released (prod) builds per platform, read once; the tagged ones are the latest (n), n-1 and n-2.
    $builds = @{}
    foreach ($platform in @($policies.platform_name | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object -Unique)) {
        if ($platform -notin 'windows', 'mac', 'linux') { continue }
        $b = Get-WEYFalconData -Command Get-FalconBuild -Scope $scope -Parameter @{ Platform = $platform; Stage = 'prod' }
        if ($b.Skipped) { return }
        $builds[$platform] = $b.Items
    }

    foreach ($p in $policies) {
        $id = [string]$p.id
        [pscustomobject]@{
            Id     = $(if ($id -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z') { $id } else { 'policy-' + ($id -replace '[^A-Za-z0-9._-]', '') })
            # Policy names are free text: the title and fields get them as plain text.
            Title  = "Falcon: $(ConvertTo-WEYFalconPlainText $p.platform_name) $(if ([string]$p.name -eq 'platform_default') { 'default sensor update policy' } else { "sensor update policy '$(ConvertTo-WEYFalconPlainText $p.name)'" }) keeps the sensor up to date and uninstall-protected"
            Fields = @{ Platform = ConvertTo-WEYFalconPlainText $p.platform_name }
            Data   = [pscustomobject]@{ Policy = $p; Builds = @($builds[([string]$p.platform_name).ToLowerInvariant()]) }
        }
    }
}

function Test-WEYFalconSensorUpdatePolicy {
    <#
    .SYNOPSIS
    Checks that an enabled Falcon sensor update policy updates its sensors (to an automatic release or a build
    no older than n-2) and has uninstall protection on (Windows and Mac).
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.FALCON.1002',
        Title              = 'Falcon: sensor update policies keep the sensor up to date and uninstall-protected',
        Severity           = 'High',
        Product            = 'crowdstrike',
        Feature            = 'sensor-update-policy',
        Area               = 'endpoint-protection',
        ResourceType       = 'Policy',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1562.001',
        Service            = 'WEY.FALCON.Api',
        InstanceSource     = 'Get-WEYFalconSensorUpdatePolicyInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The sensor update policy to check, supplied by the engine.
        $Instance,

        # How many releases the sensor version may be behind the latest (n): 2 allows n-1 and n-2.
        [ValidateRange(0, 2)]
        [int] $MaximumReleasesBehind = 2
    )

    $policy = $Instance.Data.Policy
    $builds = @($Instance.Data.Builds | Where-Object { $_ -and $_.build })
    $safeName = Get-MtSafeMarkdown -Text ([string]$policy.name)
    $platform = [string]$policy.platform_name
    $safePlatform = Get-MtSafeMarkdown -Text $platform
    $settings = $policy.settings
    $build = ([string]$settings.build).Trim()

    # The build number of each tagged release: n = 0, n-1 = 1, n-2 = 2.
    $tagged = @{}
    foreach ($b in $builds) {
        if ([string]$b.build -match '^(\d+)\|n(?:-(\d))?\|') {
            $tagged[[int]$(if ($Matches[2]) { $Matches[2] } else { 0 })] = [long]$Matches[1]
        }
    }

    # Sensor version: off, automatic (a tagged release), or pinned to one build.
    $versionCheck = if (-not $build) {
        [pscustomobject]@{ Check = 'Sensor version updates'; Value = 'off'; Expected = "on, n-$MaximumReleasesBehind or newer"; State = 'Fail' }
    } elseif ($build -match '\|n(?:-(\d))?\|') {
        $behind = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
        $label = if ($behind -eq 0) { 'automatic, latest (n)' } else { "automatic, n-$behind" }
        [pscustomobject]@{ Check = 'Sensor version'; Value = $label; Expected = "n-$MaximumReleasesBehind or newer"; State = $(if ($behind -le $MaximumReleasesBehind) { 'Pass' } else { 'Fail' }) }
    } elseif ($build -match '\|auto') {
        [pscustomobject]@{ Check = 'Sensor version'; Value = 'automatic'; Expected = "n-$MaximumReleasesBehind or newer"; State = 'Pass' }
    } elseif ($build -match '^(\d+)') {
        $pinned = [long]$Matches[1]
        $version = if ($settings.sensor_version) { " (sensor $([string]$settings.sensor_version))" } else { '' }
        $oldest = $tagged[$MaximumReleasesBehind]
        if (-not $oldest -and $tagged.Count -gt 0) { $oldest = ($tagged.Values | Measure-Object -Minimum).Minimum }
        if ($oldest) {
            $newer = @($tagged.Values | Where-Object { $_ -gt $pinned }).Count
            $value = "pinned to build $pinned$version, $(if ($newer -eq 0) { 'current' } else { "$newer newer release(s)" })"
            [pscustomobject]@{ Check = 'Sensor version'; Value = $value; Expected = "build $oldest (n-$MaximumReleasesBehind) or newer"; State = $(if ($pinned -ge $oldest) { 'Pass' } else { 'Fail' }) }
        } else {
            [pscustomobject]@{ Check = 'Sensor version'; Value = "pinned to build $pinned$version"; Expected = "n-$MaximumReleasesBehind or newer"; State = 'Unknown' }
        }
    } else {
        [pscustomobject]@{ Check = 'Sensor version'; Value = $build; Expected = "n-$MaximumReleasesBehind or newer"; State = 'Unknown' }
    }

    # Uninstall protection: a maintenance token is needed to remove the sensor. Not offered for Linux.
    $uninstall = ([string]$settings.uninstall_protection).ToUpperInvariant()
    $uninstallCheck = if ($platform -eq 'Linux') {
        [pscustomobject]@{ Check = 'Uninstall protection'; Value = $(if ($uninstall) { $uninstall } else { '-' }); Expected = '-'; State = 'NotApplicable' }
    } else {
        [pscustomobject]@{ Check = 'Uninstall protection'; Value = $(if ($uninstall) { $uninstall } else { 'not set' }); Expected = 'ENABLED'; State = $(if ($uninstall -eq 'ENABLED') { 'Pass' } else { 'Fail' }) }
    }

    $checks = @($versionCheck, $uninstallCheck)
    $failing = @($checks | Where-Object State -EQ 'Fail')
    $passed = $failing.Count -eq 0

    $summary = if ($passed) {
        "Well done. The $safePlatform sensor update policy $safeName keeps its sensors up to date and uninstall-protected."
    } else {
        "The $safePlatform sensor update policy $safeName does not keep its sensors up to date and uninstall-protected: $($failing.Check -join ', ')."
    }
    $rows = foreach ($c in $checks) {
        $mark = switch ($c.State) { 'Pass' { '✅ Pass' } 'Fail' { '❌ Fail' } 'Unknown' { 'Not compared' } default { 'Not applicable' } }
        "| $($c.Check) | $(Get-MtSafeMarkdown -Text $c.Value) | $($c.Expected) | $mark |"
    }
    $result = "$summary`n`n| Check | Value | Expected | Result |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    if ($checks.State -contains 'Unknown') {
        $result += "`n`nFalcon listed no released build for $safePlatform to compare the sensor version with."
    }
    if ([string]$policy.name -eq 'platform_default') {
        $result += "`n`nThis is the default policy: it applies to every $safePlatform host that no other policy covers."
    }

    Add-MtTestResultDetail -Result $result
    $passed
}
