Each Twilio SendGrid API key should have only the scopes its application needs. An application that sends mail
needs only `mail.send`. A leaked key with **Full Access**, or with scopes that create, change or delete API keys,
teammates, subusers, IP access rules, SSO or the account's own sign-in, lets an attacker take over the account:
create keys of their own, add teammates, lift the IP allow list and send phishing as your domains.

The test gives one result per API key. A key fails when it has Full Access, any scope that manages access to the
account, or more scopes than `MaximumScopes` (60 by default). Needs the API key scope `api_keys.read`. The key
Maester connects with is checked too, so give it read scopes only.

Set the limit in `maester-config.json`, or leave out a key you accept by its ID:

```json
{
  "TestSettings": [
    { "Id": "MP.WEY.SENDGRID.1002", "Parameters": { "MaximumScopes": 20 } },
    { "Id": "MP.WEY.SENDGRID.1002.<api key ID>", "Enabled": false }
  ]
}
```

#### Remediation action

1. In SendGrid, open **Settings > API Keys** and the key.
2. Change it to **Restricted Access** and give it only what its application uses, for example **Mail Send**.
3. If the key is not used any more, delete it. If it may have leaked, delete it and create a new one.
4. Keep Full Access keys for none or one break-glass purpose, stored in a vault.

See [API keys](https://www.twilio.com/docs/sendgrid/ui/account-and-settings/api-keys) and
[API key permissions](https://www.twilio.com/docs/sendgrid/api-reference/how-to-use-the-sendgrid-v3-api/authorization).

<!--- Results --->
%TestResult%
