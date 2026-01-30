# FoxSec - Salesforce Security Audit Application

## Project Structure

- `force-app/main/default/classes/core/` - Core interfaces & controllers
- `force-app/main/default/classes/audit-modules/` - Audit engine implementations
- `force-app/main/default/lwc/` - Lightning Web Components

## Quick Start
```bash
# Create scratch org
sfdx force:org:create -f config/project-scratch-def.json -a foxsec-dev -d 30 -s

# Push source
sfdx force:source:push

# Open org
sfdx force:org:open
```

## Namespace

Managed package namespace: `foxsec`