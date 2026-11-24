# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 1.0.0

- The first release, two checks of a CrowdStrike Falcon tenant:
  - MP.WEY.FALCON.1001: prevention policies have the key protections on (Cloud-based anti-malware, Cloud
    anti-malware for Microsoft Office files and Sensor-based anti-malware prevent at Moderate or higher; Show
    Falcon icon is on), one result per enabled policy, grouped by platform.
  - MP.WEY.FALCON.1002: sensor update policies keep sensors at n-2 or newer and have uninstall protection on,
    one result per enabled policy, grouped by platform.
- The connector, `WEY.FALCON.Api`, connects with a Falcon API client (client ID and secret) to the cloud of the
  CID (us-1, us-2, eu-1, us-gov-1, us-gov-2), optionally to a child CID (Flight Control). It reads through the
  PSFalcon module 2.2.9.
