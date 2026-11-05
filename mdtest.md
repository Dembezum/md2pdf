# Markdown Rendering Test

This document is designed to test:

- Headings
- Tables
- Code blocks
- Syntax highlighting
- Blockquotes
- Lists
- Images
- Horizontal rules
- Inline code
- Diagrams
- Page breaks
- Table of contents generation

---

# 1. Introduction

This is a standard paragraph used to verify body text rendering.

The quick brown fox jumps over the lazy dog.

The following inline code should render correctly:

- `system.stateVersion`
- `sops.secrets.example.path`
- `/var/lib/sops-nix`
- `just sops-sync`

---

# 2. Lists

## Unordered list

- Item one
- Item two
- Item three

### Nested list

- Infrastructure
  - NixOS
  - Clan
  - SOPS
- Applications
  - NetBox
  - Grafana
  - Vault

## Ordered list

1. Generate secret
2. Encrypt secret
3. Commit secret
4. Deploy secret
5. Decrypt at runtime

---

# 3. Blockquotes

> Secrets should never be stored in plaintext within the Nix store.

> Access should be derived from policy rather than manually maintained recipient lists.

> Infrastructure should remain reproducible and auditable.

---

# 4. Tables

| Component | Purpose | Example |
|------------|------------|------------|
| Clan Vars | Generated values | Passwords |
| SOPS | Encrypted repository secrets | API tokens |
| Age | Encryption backend | Recipient keys |
| sops-nix | Runtime decryption | Secret files |

---

# 5. Plain Text Diagram

```text
                Secret management
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼

      Clan Vars                    SOPS
          │                           │

          ▼                           ▼

 Generated/lifecycle        Repository secrets
 information                encrypted in Git

          │                           │
          └─────────────┬─────────────┘
                        ▼

                   Workstation
```

---

# 6. Tree Structure

```text
sops/
├── users/
│   ├── kristian/
│   │   └── key.json
│   └── admin/
│       └── key.json
├── machines/
│   ├── workstation01/
│   └── workstation02/
└── secrets/
    └── netbox.yaml
```

---

# 7. Nix Code

```nix
{
  imports = [
    ../../modules/common
    ../../modules/workstation
  ];

  system.stateVersion = "26.05";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
}
```

---

# 8. Bash

```bash
just sops-sync

git add .

git commit -m "Update recipients"

git push
```

---

# 9. JSON

```json
{
  "name": "workstation01",
  "environment": "production",
  "enabled": true,
  "tags": [
    "workstation",
    "developer"
  ]
}
```

---

# 10. YAML

```yaml
apiVersion: v1

metadata:
  name: netbox

spec:
  replicas: 2

  image:
    repository: netboxcommunity/netbox
    tag: latest
```

---

# 11. Long Code Block

```nix
sops.secrets.netbox-token = {
  sopsFile = ../../secrets/services/netbox.yaml;
  key = "token";

  owner = "root";
  group = "root";
  mode = "0400";

  neededFor = "services";
};

services.netbox-sync = {
  enable = true;

  tokenFile =
    config.sops.secrets.netbox-token.path;
};
```

---

# 12. Password Example

Generated outputs:

- `password`
- `password-hash`

The plaintext password is marked:

```text
secret = true
deploy = false
```

The hash is marked:

```text
secret = true
deploy = true
neededFor = "users"
owner = root
group = root
mode = 0400
```

---

# 13. Horizontal Rule Test

Before rule.

---

After rule.

---

# 14. Large Table

| Hostname | Role | Location | Managed | Secrets |
|-----------|-----------|-----------|-----------|-----------|
| ws001 | Workstation | Bjerringbro | Yes | Yes |
| ws002 | Workstation | Bjerringbro | Yes | Yes |
| ws003 | Developer | Aarhus | Yes | Yes |
| ws004 | Admin | Aarhus | Yes | Yes |
| ws005 | Testing | Viborg | Yes | No |

---

# 15. Mixed Formatting

A user with the role `secrets-admin` receives access to encrypted secrets.

The public key is stored at:

```text
sops/users/kristian/key.json
```

Configuration example:

```nix
roles = [
  "admin"
  "secrets-admin"
];
```

> Recipient policies are generated automatically from fleet metadata.

---

# 16. Conclusion

This document intentionally contains a variety of Markdown constructs to validate:

- PDF layout
- Syntax highlighting
- Typography
- Code block rendering
- Diagram rendering
- Table rendering
- Page breaks
- TOC generation
- Blockquote styling

End of test document.
