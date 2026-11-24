Every domain of the Microsoft 365 tenant that sends mail should be onboarded in PowerDMARC, so that its DMARC
reports are collected and its DMARC, SPF and DKIM records are managed there. A domain that is missing goes
unwatched: nobody sees when it is spoofed or when a new sender fails authentication.

The test reads the tenant's domains from Microsoft Graph and the domains in PowerDMARC, and gives:

- **One result per tenant domain** that is verified and set up for Email (`supportedServices` contains `Email`).
  It passes when the domain is in PowerDMARC and fails when it is not. A subdomain that is not onboarded itself,
  while its parent domain is, needs investigation: the parent's DMARC record covers it through `sp=`, but
  PowerDMARC shows nothing of its own for it.
- **One result, `not-in-tenant`**, that lists the PowerDMARC domains the tenant does not have. It needs
  investigation when there are any (a domain of another customer, or one no longer in use) and passes otherwise.
  Subdomains of tenant domains are listed apart and do not count. In Reseller mode this result is given only
  when the domains come from one customer account.

The `*.onmicrosoft.com` domains are left out unless the setting `WEY.POWERDMARC.IncludeInitialDomains` is true.
Domains that are not verified or not set up for Email are always left out.

Each result's ID ends with the domain name, such as `MP.WEY.POWERDMARC.1002.contoso.com`, so a single domain can be
excluded in `maester-config.json`.

Connect to Microsoft Graph (the default `Connect-Maester` scopes include `Directory.Read.All`, which can read the
domains; `Domain.Read.All` is the least that is needed) and to PowerDMARC:

```powershell
Connect-Maester -Service Graph, WEY.POWERDMARC.Api -ServiceSetting @{ ApiToken = (Read-Host -AsSecureString 'PowerDMARC token') }
```

In Reseller mode the tenant usually belongs to one customer account. Name it per tenant in `maester-config.json`;
without it the connection's `AccountId` is used, and without that the domains of every customer account:

```json
{
  "GlobalSettings": {
    "WEY.POWERDMARC.TenantAccountId": 42,
    "WEY.POWERDMARC.IncludeInitialDomains": false
  }
}
```

#### Remediation action

1. In PowerDMARC, add each failing domain (in Reseller mode: in the customer account of this tenant).
2. Publish the DMARC record PowerDMARC shows for it, starting with `p=none` while you collect reports, and turn on
   Hosted SPF and DKIM monitoring as needed.
3. For a domain in the `not-in-tenant` list: remove it from PowerDMARC when it is no longer in use, move it to the
   right customer account, or add it to the tenant when it should send mail from Microsoft 365.

See [PowerDMARC](https://powerdmarc.com) and
[Domains in Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/setup/add-domain).

<!--- Results --->
%TestResult%
