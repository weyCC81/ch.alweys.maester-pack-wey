# Changelog

Every release of the pack, newest first. Install-MtPack shows the version; Update-MtPack moves to a newer one.

## 1.0.2

- **Disconnecting revokes the token.** `Disconnect-Maester` now calls `Revoke-FalconToken`: Falcon ends the
  token at once instead of after 30 minutes, and PSFalcon forgets the client ID and the secret it kept in memory.
  A token of another API client in the same PowerShell session is left alone. Nothing in the tenant changes.

## 1.0.1

- **The tests say what they check.** MP.WEY.FALCON.1001 is now "prevention policies block malware, not only detect
  it", and MP.WEY.FALCON.1002 "sensor update policies keep the sensor up to date and uninstall-protected". Each
  result names its platform, and a platform's default policy shows as "default" instead of `platform_default`.
- **Show Falcon icon is no longer checked.** It is a setting of the System tray policies, which neither the Falcon
  API nor PSFalcon 2.2.9 can read, so 1001 listed it as not applicable on every policy. The setting
  `RequireFalconIcon` is removed; remove it from your `maester-config.json` if you set it.
- **Only Windows, Mac and Linux policies are checked.** Mobile (Android, iOS) prevention policies and K8S sensor
  update policies have none of these settings and failed before; they are now left out.
- 1001 also finds the anti-malware sliders by the names the console shows today ("Cloud Anti-malware", "Sensor
  Anti-malware"), in case Falcon ever changes their API IDs.

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
