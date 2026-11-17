# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 1.0.0

- The first release: MP.WEY.DMARC.1001 checks the Hosted SPF (PowerSPF) record of every PowerDMARC domain (DNS
  lookups, void lookups, errors and the all mechanism), one result per domain. In Reseller mode the results carry
  the field Account, so the report groups them by customer account.
- The pack's connector, `WEY.DMARC.PowerDMARC`, connects with the PowerDMARC module (0.1.1, from the PowerShell
  Gallery) in Default (End User) or Reseller (MSSP) mode.
- Replaces the content of the Maester demo pack this pack started from.
