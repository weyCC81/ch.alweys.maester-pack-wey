Each enabled CrowdStrike Falcon **sensor update policy** should keep its sensors current and hard to remove:

- **Sensor version updates** are on, to an automatic release (latest, n-1 or n-2) or to a pinned build that is
  no older than the n-2 release. Old sensors miss detections and fixes, and CrowdStrike supports a build for a
  limited time only.
- **Uninstall protection** is on (Windows and Mac): removing the sensor needs a maintenance token, so an attacker
  or a user with local admin rights cannot simply uninstall it.

The test gives one result per enabled sensor update policy, including each platform's default policy, and compares
a pinned build with the released builds Falcon lists for the platform. Results carry the field **Platform**.
Disabled policies apply to no host and are left out, and so are policies of platforms other than Windows, Mac
and Linux (such as K8S). Needs the API client scope **Sensor update policies: Read**.

#### Remediation action

1. In the Falcon console, open **Host setup and management > Deploy > Sensor update policies** and the policy.
2. Set **Sensor version** to **Auto - N-1** (or N-2 for a slower ring), or pin a build no older than n-2 and
   move it forward with each release.
3. Turn on **Uninstall and maintenance protection**.
4. Save the policy.

Allow fewer releases behind with the test setting `MaximumReleasesBehind` (0 to 2).

See **Sensor update policies** in the Falcon documentation (Falcon console, **Support and resources >
Documentation**).

<!--- Results --->
%TestResult%
