For organisations that must keep mail data in the EU, Twilio SendGrid should process and store it in its **EU
region**. EU regional accounts and subusers are reached at `api.eu.sendgrid.com`, and their dedicated IPs are in
the EU. Everything else is in the global region, which is the US.

The test checks, for the connected (global) account:

- **Subusers**: each subuser's region (`eu` or `global`). Needs the scope `subusers.read`.
- **Dedicated IPs**: each sending IP's region (`eu` or `us`), up to `MaximumIps` (1000). Needs the scope `ips.read`.

A part the key has no scope for is not checked, and the result says so.

**Limit:** the pack reads SendGrid through SendGridTools 0.4.7, which reaches only the global API
(`api.sendgrid.com`). The connected account is therefore always a global one and is listed for information only,
and an EU regional account or subuser (`api.eu.sendgrid.com`) cannot be checked at all.

#### Remediation action

SendGrid cannot move an account, subuser or IP to another region.

1. Create an **EU regional subuser** (Settings > Subuser Management, region EU), or ask SendGrid for an EU
   account.
2. Authenticate your domains again for the EU subuser and add EU dedicated IPs if you use dedicated IPs.
3. Move your applications to API keys of the EU subuser and to `api.eu.sendgrid.com`.
4. Retire the global subusers and IPs once nothing sends through them.

See [EU data residency](https://www.twilio.com/docs/sendgrid/for-developers/sending-email/eu-data-residency).

<!--- Results --->
%TestResult%
