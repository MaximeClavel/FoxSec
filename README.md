// File: README.md
# FoxSec - Salesforce Security Audit Application

## Project Structure

- `force-app/main/default/classes/core/` - Core interfaces & controllers
- `force-app/main/default/classes/audit-modules/` - Audit engine implementations
- `force-app/main/default/lwc/` - Lightning Web Components

## Prerequisites

1. **Salesforce CLI** (v2.x recommended)
```bash
   sf version
```

2. **Dev Hub enabled org**
   - Production org with Dev Hub enabled, OR
   - Developer Edition org (free) with Dev Hub enabled
   - Enable at: Setup → Dev Hub → Enable

3. **Developer Edition org** (recommended for full security audit testing)
   - Some security metadata is not available in scratch orgs
   - Get free DE org at: https://developer.salesforce.com/signup

## Setup

### 1. Authorize Dev Hub
```bash
# Login to your Dev Hub org
sf org login web --set-default-dev-hub --alias DevHub

# Verify Dev Hub is set
sf config list
```

### 2. Create Scratch Org (Development)
```bash
# Create scratch org (30 days)
sf org create scratch --definition-file config/project-scratch-def.json --alias foxsec-dev --duration-days 30 --set-default

# Deploy source code
sf project deploy start

# Open the org
sf org open
```

### 3. Alternative: Use Developer Edition (Full Testing)
```bash
# Authorize your persistent Developer Edition org
sf org login web --alias foxsec-de --set-default

# Deploy to DE org
sf project deploy start --target-org foxsec-de

# Open the org
sf org open --target-org foxsec-de
```

### 4. Development Workflow
```bash
# Pull changes from scratch org
sf project retrieve start

# Push local changes to scratch org
sf project deploy start

# Run Apex tests
sf apex run test --test-level RunLocalTests --result-format human --code-coverage

# View org details
sf org display
```

### 5. Cleanup
```bash
# Delete scratch org
sf org delete scratch --target-org foxsec-dev --no-prompt
```

## Known Limitations

See `docs/SCRATCH_ORG_LIMITATIONS.md` for details on:
- Security metadata not available in scratch orgs
- Agentforce testing requirements
- Recommended testing strategy

## Namespace

Managed package namespace: `foxsec`

## Package Development
```bash
# Create package version (when ready)
sf package version create --package FoxSec --installation-key-bypass --wait 20

# Install package version in test org
sf package install --package 04tXXXXXXXXXXXXXXX --target-org <test-org-alias> --wait 20
```