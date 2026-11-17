# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 1.0.1

- Alweys C//oud branding: a new banner with the soft orange glow of the first one, the header bar and mark of
  [alweys.ch](https://www.alweys.ch) and a card of what the test checks,
  and an About section in the README.
- MP.WEY.DMARC.1001 now uses Maester's taxonomy: Product `exchange`, Feature `email-authentication`, Area
  `email-protection`, with UserImpact, ImplementationCost and MITRE ATT&CK T1566 (phishing). Its results sit next to
  Maester's own Exchange Online email checks, and the pack is listed under Exchange Online on packs.maester.cloud.
- A guide (`maester-pack.guide.json`) for the pack's page on packs.maester.cloud: prerequisites, connect, run,
  settings and unattended runs.

## 1.0.0

- The first release: MP.WEY.DMARC.1001 checks the Hosted SPF (PowerSPF) record of every PowerDMARC domain (DNS
  lookups, void lookups, errors and the all mechanism), one result per domain. In Reseller mode the results carry
  the field Account, so the report groups them by customer account.
- The pack's connector, `WEY.DMARC.PowerDMARC`, connects with the PowerDMARC module (0.1.1, from the PowerShell
  Gallery) in Default (End User) or Reseller (MSSP) mode.
- Replaces the content of the Maester demo pack this pack started from.
- The pack Id is `weycc81.powerdmarc`, after the GitHub owner that publishes it, as the pack index requires.
