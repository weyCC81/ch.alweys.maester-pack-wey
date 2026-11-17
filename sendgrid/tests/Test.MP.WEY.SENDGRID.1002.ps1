function Get-WeySendGridApiKeyInstance {
    <#
    .SYNOPSIS
    Instance source of MP.WEY.SENDGRID.1002: one instance per API key of the SendGrid account, with its scopes.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = Get-MtConnectionState -Service WEY.SENDGRID.Api
    if ($state -and 'api_keys.read' -notin @($state.Scopes)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The SendGrid API key lacks the scope api_keys.read. Give the key read access to API Keys (Settings > API Keys > Restricted Access).'
        return
    }

    $keys = @((Invoke-WeySendGridRequest -Path '/v3/api_keys?limit=500').result | Where-Object { $_ -and $_.api_key_id })
    foreach ($k in ($keys | Sort-Object name, api_key_id)) {
        $detail = @((Invoke-WeySendGridRequest -Path "/v3/api_keys/$($k.api_key_id)").result) | Select-Object -First 1
        $id = [string]$k.api_key_id
        [pscustomobject]@{
            # The key ID is stable, so a key can be excluded in maester-config.json; it is not the secret.
            Id    = $(if ($id -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z') { $id } else { 'key-' + ($id -replace '[^A-Za-z0-9._-]', '') })
            Title = "SendGrid: API key '$($k.name)' has least privilege"
            Data  = [pscustomobject]@{ Id = $id; Name = [string]$k.name; Scopes = @($(if ($detail) { $detail.scopes })) }
        }
    }
}

function Test-WeySendGridApiKeyPrivilege {
    <#
    .SYNOPSIS
    Checks that a SendGrid API key cannot manage access to the account: no Full Access, and no scope that
    creates, changes or deletes API keys, teammates, subusers, IP access, SSO or the account's own sign-in.
    #>
    [MaesterTest(
        Id                 = 'MP.WEY.SENDGRID.1002',
        Title              = 'SendGrid: API keys have least privilege',
        Severity           = 'High',
        Product            = 'sendgrid',
        Feature            = 'api-keys',
        Area               = 'privileged-access',
        ResourceType       = 'Permission',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1098',
        Service            = 'WEY.SENDGRID.Api',
        InstanceSource     = 'Get-WeySendGridApiKeyInstance'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The API key to check, supplied by the engine.
        $Instance,

        # The most scopes a key may have. A Full Access key has well over 100.
        [ValidateRange(1, 1000)]
        [int] $MaximumScopes = 60
    )

    $key = $Instance.Data
    $safeName = Get-MtSafeMarkdown -Text $key.Name
    $scopes = @($key.Scopes | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    # Scopes that manage who and what can reach the account.
    $adminPattern = '^(api_keys|teammates|subusers|access_settings|sso|credentials|user\.(password|email|username|multifactor_authentication|webhooks))(\.[a-z_]+)*\.(create|update|delete)$'
    $admin = @($scopes | Where-Object { $_ -match $adminPattern })
    $fullAccess = $scopes -contains 'api_keys.create' -and $scopes -contains 'teammates.create'
    $sendOnly = $scopes.Count -gt 0 -and @($scopes | Where-Object { $_ -notmatch '^(mail\.send|sender_verification_eligible|2fa_required|2fa_exempt)$' }).Count -eq 0

    $checks = @(
        [pscustomobject]@{ Check = 'Full Access'; Value = $(if ($fullAccess) { 'yes' } else { 'no' }); Expected = 'no'; Passed = -not $fullAccess }
        [pscustomobject]@{ Check = 'Scopes that manage access'; Value = "$($admin.Count)"; Expected = 'none'; Passed = $admin.Count -eq 0 }
        [pscustomobject]@{ Check = 'Scopes'; Value = "$($scopes.Count)"; Expected = "at most $MaximumScopes"; Passed = $scopes.Count -le $MaximumScopes }
    )
    $failing = @($checks | Where-Object { -not $_.Passed })
    $passed = $failing.Count -eq 0

    $summary = if ($passed -and $sendOnly) {
        "Well done. The API key $safeName can only send mail."
    } elseif ($passed) {
        "Well done. The API key $safeName has $($scopes.Count) scopes and none that manage access to the account."
    } else {
        "The API key $safeName has more privilege than it should: $($failing.Check -join ', ')."
    }
    $rows = foreach ($c in $checks) {
        $mark = if ($c.Passed) { '✅ Pass' } else { '❌ Fail' }
        "| $($c.Check) | $($c.Value) | $($c.Expected) | $mark |"
    }
    $result = "$summary`n`n| Check | Value | Expected | Result |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    if ($admin.Count -gt 0) {
        $shown = @($admin | Select-Object -First 25)
        $result += "`n`n**Scopes that manage access**`n`n" + (($shown | ForEach-Object { "- ``$_``" }) -join "`n")
        if ($admin.Count -gt $shown.Count) { $result += "`n- and $($admin.Count - $shown.Count) more" }
    }

    Add-MtTestResultDetail -Result $result
    $passed
}
