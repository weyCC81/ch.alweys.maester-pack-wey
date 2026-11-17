Each domain authenticated in Twilio SendGrid (Domain Authentication) should be **validated**: its DNS publishes
the records SendGrid gives for it, a DKIM key and the return path (SPF). Only then does mail that SendGrid sends
for the domain pass DKIM and align with the domain's DMARC policy. An unvalidated domain is signed with SendGrid's
own domain, so receivers with a DMARC policy of `quarantine` or `reject` put the mail in spam or refuse it.

The test gives one result per authenticated domain and lists each DNS record with whether SendGrid found it.
Results carry the field **User**, the SendGrid user or subuser the domain belongs to. Needs the API key scope
`whitelabel.read`.

#### Remediation action

1. In SendGrid, open **Settings > Sender Authentication** and the domain.
2. Publish each record that is missing or wrong at your DNS provider, exactly as SendGrid shows it.
3. Click **Verify** in SendGrid once the records resolve.
4. Prefer **automated security** (CNAME records): SendGrid then rotates the DKIM keys for you.
5. Delete authenticated domains you no longer send from.

See [How to set up domain authentication](https://www.twilio.com/docs/sendgrid/ui/account-and-settings/how-to-set-up-domain-authentication).

<!--- Results --->
%TestResult%
