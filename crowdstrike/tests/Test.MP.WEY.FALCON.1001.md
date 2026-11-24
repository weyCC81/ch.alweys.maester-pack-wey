Each enabled CrowdStrike Falcon **prevention policy** should block malware, not only detect it, and show users
that Falcon protects the device:

- **Cloud-based anti-malware**, **Cloud anti-malware for Microsoft Office files** (Windows only) and
  **Sensor-based anti-malware** prevent at **Moderate** or higher. A slider set to detect only reports the
  malware and lets it run.
- **Show Falcon icon** is on, so users see that the sensor is installed and working.

The test gives one result per enabled prevention policy, including each platform's default policy, and lists
every setting with its level. A setting the policy's platform does not have is shown as not applicable. Results
carry the field **Platform**. Disabled policies apply to no host and are left out. Needs the API client scope
**Prevention policies: Read**.

#### Remediation action

1. In the Falcon console, open **Endpoint security > Configure > Prevention policies** and the policy.
2. Under **Next-Gen Antivirus**, move the **Prevention** slider of Cloud-based anti-malware, Cloud anti-malware for
   Microsoft Office files and Sensor-based anti-malware to **Moderate** or higher. Test **Aggressive** on a pilot
   group first.
3. Turn on **Show Falcon icon**.
4. Save the policy. Hosts pick up the change within minutes.

Change the minimum level with the test setting `MinimumPreventionLevel`, or leave out the icon with
`RequireFalconIcon` = `false`.

See **Prevention policies** in the Falcon documentation (Falcon console, **Support and resources >
Documentation**).

<!--- Results --->
%TestResult%
