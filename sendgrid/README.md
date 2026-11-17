![SendGrid Maester pack by Alweys C//oud](assets/banner.png)

# SendGrid Maester pack

**by [Alweys C//oud](https://www.alweys.ch): ensure that your cloud is always oriented the right way.**

A [Maester Pack](https://maester.dev/docs/next/packs) that checks the security of a
[Twilio SendGrid](https://sendgrid.com) account. It reads the SendGrid API, global or EU, with a read-only API key
and changes nothing. It needs no PowerShell module.

Not made by or affiliated with Twilio or SendGrid.

## Try it

```powershell
Install-MtPack weyCC81/ch.alweys.maester-pack-wey/sendgrid
```

In SendGrid, create an API key under **Settings > API Keys > Create API Key > Restricted Access** with **read**
access to Domain Authentication (`whitelabel.read`), API Keys (`api_keys.read`), Enforced TLS
(`user.settings.enforced_tls.read`), Subusers (`subusers.read`) and IP Addresses (`ips.read`). Then connect and run:

```powershell
# Global account
Connect-Maester -Service WEY.SENDGRID.Api -ServiceSetting @{ ApiKey = (Read-Host -AsSecureString 'SendGrid API key') }

# EU regional account or subuser
Connect-Maester -Service WEY.SENDGRID.Api -ServiceSetting @{ ApiKey = (Read-Host -AsSecureString 'SendGrid API key'); Region = 'EU' }

Invoke-Maester -Pack WEY.SENDGRID -SkipBuiltIn
```

For unattended runs, put the key in the `MAESTER_WEY_SENDGRID_API_APIKEY` environment variable (and
`MAESTER_WEY_SENDGRID_API_REGION` = `EU` for an EU account). Keep it out of `maester-config.json`. Without a
connection the tests are skipped; a test whose scope the key lacks is skipped and names the scope.

## Tests

| ID | What it checks |
| --- | --- |
| MP.WEY.SENDGRID.1001 | One result per authenticated domain: SendGrid has validated its DKIM and SPF records, so mail passes DKIM and aligns with DMARC |
| MP.WEY.SENDGRID.1002 | One result per API key: no Full Access, no scopes that manage access to the account, at most 60 scopes |
| MP.WEY.SENDGRID.1003 | Enforced TLS is on, at TLS 1.2 or newer (a valid certificate is optional) |
| MP.WEY.SENDGRID.1004 | The account, its subusers and its dedicated IPs are in the EU region |

Change the settings in your `maester-config.json`, or leave out a domain or key:

```json
{
  "TestSettings": [
    { "Id": "MP.WEY.SENDGRID.1002", "Parameters": { "MaximumScopes": 20 } },
    { "Id": "MP.WEY.SENDGRID.1003", "Parameters": { "RequireValidCertificate": true, "MinimumVersion": "1.2" } },
    { "Id": "MP.WEY.SENDGRID.1004", "Enabled": false }
  ]
}
```

Turn off MP.WEY.SENDGRID.1004 if your organisation does not need its mail data in the EU.

## What the pack reaches

`Uses` in [maester-pack.json](maester-pack.json) declares it, and Install-MtPack shows it before installing:

- **Service**: `WEY.SENDGRID.Api`, the pack's own connector ([connector/Connect-WeySendGrid.ps1](connector/Connect-WeySendGrid.ps1)).
- **Network**: `api.sendgrid.com` and `api.eu.sendgrid.com`, with `GET` requests only
  ([helpers/Invoke-WeySendGridRequest.ps1](helpers/Invoke-WeySendGridRequest.ps1)).
- **Modules, tenant writes and Graph scopes**: none.

## Develop

```powershell
Test-MtPack .
Invoke-MtTest -Path .
```

Write what changed under `## Unreleased` in [CHANGELOG.md](CHANGELOG.md) and raise `Version` in
`maester-pack.json`. A test is a Maester native test: see
[Writing native tests](https://maester.dev/docs/next/writing-tests/) and
[Writing a pack](https://maester.dev/docs/next/packs/writing-a-pack).

## Files

| Path | What it is |
| --- | --- |
| `maester-pack.json` | The manifest: ID, code, version, the suite, helpers, the connector and what the pack uses |
| `maester-pack.guide.json` | How to install, connect and run, for the pack's page on packs.maester.cloud |
| `tests/` | The suite: `suite.json`, and one `Test.<ID>.ps1` and `Test.<ID>.md` per test |
| `helpers/` | `Invoke-WEYSendGridRequest` (GET only), paging and the scope check |
| `connector/` | `Connect-`, `Test-` and `Disconnect-WEYSendGrid` |
| `assets/banner.png` | The image the pack index shows when it features the pack |

Security issues: see the [security policy](../SECURITY.md).

## About

Made by Stefan Wey, trainer and solution engineer at [Alweys C//oud](https://www.alweys.ch), who writes there about
Microsoft 365 mail security, identity and collaboration.
