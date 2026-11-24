# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 2.1.0

- **New test MP.WEY.POWERDMARC.1002**: every email domain of the Microsoft 365 tenant is onboarded in PowerDMARC.
  It reads the tenant's domains from Microsoft Graph (`GET /domains`, read-only) and gives one result per verified
  domain set up for Email: Passed when PowerDMARC has it, Failed when not, Investigate for a subdomain whose parent
  domain is onboarded. The result `MP.WEY.POWERDMARC.1002.not-in-tenant` lists the PowerDMARC domains the tenant
  does not have (Investigate).
- The pack now also uses **Microsoft Graph**, with the scope `Domain.Read.All` (the default `Connect-Maester`
  scopes include `Directory.Read.All`, which covers it). MP.WEY.POWERDMARC.1001 still needs only PowerDMARC.
- Two settings for `GlobalSettings` in `maester-config.json`: `WEY.POWERDMARC.TenantAccountId`, the customer
  account of this tenant in Reseller mode (0: the connection's AccountId, else every account), and
  `WEY.POWERDMARC.IncludeInitialDomains`, to check the `*.onmicrosoft.com` domains too.
- `Get-WEYDmarcDomain` takes `-AccountId` to list another customer account than the connection's.

## 2.0.1

- Names from PowerDMARC (domain and account) go into result titles and the Account field as plain text, without
  the characters that make markdown links, images, HTML or tables. The published SPF record cannot end its code
  span early. Found by a security audit; the HTML report was not affected.

## 2.0.0

- **The code is now `WEY.POWERDMARC`** (was `WEY.DMARC`), with a new Guid, so Maester sees a new pack:
  - The test is now **MP.WEY.POWERDMARC.1001** (was MP.WEY.DMARC.1001). Change its ID in your
    `maester-config.json`.
  - The service is now **`WEY.POWERDMARC.Api`** (was `WEY.DMARC.PowerDMARC`), and its environment variables
    `MAESTER_WEY_POWERDMARC_API_<NAME>` (was `MAESTER_WEY_DMARC_POWERDMARC_<NAME>`).
  - Run it with `Invoke-Maester -Pack WEY.POWERDMARC`.
  - To move from 1.0.0: `Uninstall-MtPack weycc81.powerdmarc`, then `Install-MtPack` again.
- MP.WEY.POWERDMARC.1001 has Product `PowerDMARC`, RelatedProduct `exchange`, Feature `email-authentication`,
  Area `email-protection`, UserImpact and ImplementationCost Low, and MITRE ATT&CK T1566 (phishing).
- A guide (`maester-pack.guide.json`) for the pack's page on packs.maester.cloud: prerequisites, connect, run,
  settings and unattended runs.
- Alweys C//oud branding: a new banner with the soft orange glow of the first one, the header bar and mark of
  [alweys.ch](https://www.alweys.ch) and a card of what the test checks, and an About section in the README.

## 1.0.0

- The first release: MP.WEY.DMARC.1001 checks the Hosted SPF (PowerSPF) record of every PowerDMARC domain (DNS
  lookups, void lookups, errors and the all mechanism), one result per domain. In Reseller mode the results carry
  the field Account, so the report groups them by customer account.
- The pack's connector, `WEY.DMARC.PowerDMARC`, connects with the PowerDMARC module (0.1.1, from the PowerShell
  Gallery) in Default (End User) or Reseller (MSSP) mode.
- Replaces the content of the Maester demo pack this pack started from.
- The pack Id is `weycc81.powerdmarc`, after the GitHub owner that publishes it, as the pack index requires.
