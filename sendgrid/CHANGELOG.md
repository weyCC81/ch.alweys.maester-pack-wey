# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 1.1.0

- **EU regional accounts work again.** The pack uses SendGridTools **0.5.1**, which connects to
  `api.eu.sendgrid.com` (`Connect-SendGrid -Region EU`). Connect with `Region = 'EU'` (or
  `MAESTER_WEY_SENDGRID_API_REGION` = `EU`). The limit of 1.0.1 is gone.
- MP.WEY.SENDGRID.1004 checks the account itself again ("the account and its IPs are in the EU"), and reads every
  dedicated IP: the `MaximumIps` setting is removed. Remove it from your `maester-config.json` if you set it.
- The tests use the module's own commands, which read every page: `Get-SGAuthenticatedDomain`, `Get-SGApiKey`,
  `Get-SGEnforcedTls`, `Get-SGSubuser -IncludeRegion` and `Get-SGIPAddress -IncludeRegion`. The pack no longer
  uses the generic `Invoke-SGCommand`. SendGridTools 0.5.1 refuses HTTP redirects, so the API key is only sent to
  SendGrid.
- Names from SendGrid (domain, user, API key name) go into result titles and the User field as plain text, without
  the characters that make markdown links, images, HTML or tables. Found by a security audit; the HTML report was
  not affected.

## 1.0.1

- The pack reads SendGrid through the **SendGridTools** module (0.4.7, from the PowerShell Gallery) instead of its
  own requests: `Connect-SendGrid`, `Get-SGPermissionScopes`, `Get-SGApiKey`, and `Invoke-SGCommand` with GET for
  the paged lists, Enforced TLS and the regions. The pack still only reads.
- **Limit: global SendGrid API only.** SendGridTools 0.4.7 reaches only api.sendgrid.com, so EU regional accounts
  and subusers (api.eu.sendgrid.com) can no longer be checked. The connector refuses `Region = 'EU'` with a
  message, and `MAESTER_WEY_SENDGRID_API_REGION` is no longer used.
- MP.WEY.SENDGRID.1004 is now "subusers and dedicated IPs are in the EU": the connected account is always global
  and is listed for information only. Dedicated IPs are read in one page of up to `MaximumIps` (1000, a new
  setting).
- Uses: the module SendGridTools 0.4.7, and only api.sendgrid.com on the network. Install-MtPack rates the pack
  Medium risk (was Low), for the module.

## 1.0.0

- The first release, four checks of a Twilio SendGrid account:
  - MP.WEY.SENDGRID.1001: every authenticated domain is validated (DKIM and SPF records published), one result
    per domain, grouped by SendGrid user.
  - MP.WEY.SENDGRID.1002: API keys have least privilege (no Full Access, no scopes that manage access), one
    result per key.
  - MP.WEY.SENDGRID.1003: Enforced TLS is on, at TLS 1.2 or newer.
  - MP.WEY.SENDGRID.1004: the account, its subusers and its dedicated IPs are in the EU.
- The connector, `WEY.SENDGRID.Api`, connects with an API key to the global or the EU region. No PowerShell
  module: the pack sends GET requests to api.sendgrid.com or api.eu.sendgrid.com only.
