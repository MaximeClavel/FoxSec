# Scratch Org Limitations for FoxSec

## Features Not Available in Scratch Orgs

### SecuritySettings (Feature)
- **Status**: NOT available as a scratch org feature
- **Impact**: Some advanced security audits require a production/sandbox org
- **Workaround**: Use `securitySettings` in the `settings` section of scratch-def
- **Alternative**: Test security audits in a sandbox or persistent Developer Edition

### Agentforce
- **Status**: NOT available in scratch orgs (Q1 2026)
- **Impact**: Automation features via Agentforce must be tested in sandbox
- **Workaround**: Develop with compatible Invocable Actions, test Agentforce in sandbox
- **Alternative**: Use Flow Builder for initial testing

## Limited Setup Objects

Some metadata objects are not accessible via SOQL in scratch orgs:
- `SetupAuditTrail` (limited setup history)
- Some advanced `PermissionSet` views
- `LoginHistory` (limited data)

## Testing Strategy

1. **Scratch Org**: Unit tests, core logic, UI
2. **Developer Edition**: Integration tests, complete security audits
3. **Sandbox**: E2E tests, Agentforce, performance limits
4. **Production**: Final validation before AppExchange release

## Valid Features Used
```json
"features": [
  "LightningServiceConsole",  // Lightning Console
  "Communities",               // For multi-user tests
  "ServiceCloud",              // Case objects, etc.
  "API",                       // REST/SOAP API access
  "AuthorApex"                 // Apex class creation
]
```

## Available Security Settings

The following settings ARE configurable via `settings.securitySettings`:
- Password policies
- Session settings
- Network access (IP ranges)
- Login hours
- Certificate/identity settings

**Note**: These settings do NOT provide access to all Setup Metadata objects.