Twilio SendGrid should deliver mail only over TLS. Without **Enforced TLS**, SendGrid falls back to clear text when
the receiving server does not offer TLS, so anyone on the path can read or change the mail. With it, SendGrid
drops such a message instead (a block event with the reason).

The test checks that **Require TLS** is on and that the minimum TLS version is at least `MinimumVersion` (1.2).
**Require a valid certificate** is recommended but only required when `RequireValidCertificate` is set, because
some receivers still use self-signed certificates. Needs the API key scope `user.settings.enforced_tls.read`.

```json
{
  "TestSettings": [
    { "Id": "MP.WEY.SENDGRID.1003", "Parameters": { "RequireValidCertificate": true, "MinimumVersion": "1.2" } }
  ]
}
```

#### Remediation action

Turn on Enforced TLS with the API (there is no setting for it in the SendGrid web app), with a key that has the
scope `user.settings.enforced_tls.update`:

```http
PATCH https://api.sendgrid.com/v3/user/settings/enforced_tls
{ "require_tls": true, "require_valid_cert": true, "version": 1.2 }
```

Use `api.eu.sendgrid.com` for an EU regional account. Watch the block events for a few days afterwards: they show
receivers that cannot take mail over TLS.

See [Enforced TLS](https://www.twilio.com/docs/sendgrid/ui/sending-email/enforced-tls).

<!--- Results --->
%TestResult%
