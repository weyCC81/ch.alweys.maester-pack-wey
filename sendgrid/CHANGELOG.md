# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

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
