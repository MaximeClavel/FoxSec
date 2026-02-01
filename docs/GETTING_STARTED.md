# Getting Started Guide - FoxSec

## 🎯 Objective

This guide walks you through the installation and first use of FoxSec to audit your Salesforce org's security.

---

## Prerequisites

### Required Tools

| Tool | Version | Verification |
|------|---------|--------------|
| Salesforce CLI | v2.x+ | `sf version` |
| Node.js | 18.x+ | `node --version` |
| Git | 2.x+ | `git --version` |

### Salesforce Org

You need one of the following:

- **Dev Hub**: Org with Dev Hub enabled to create Scratch Orgs
- **Developer Edition**: Free org for complete testing
- **Sandbox**: For advanced integration testing

---

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/foxsec.git
cd foxsec
```

### Step 2: Install Dependencies

```bash
npm install
```

### Step 3: Authenticate Your Dev Hub

```bash
# Connect to Dev Hub
sf org login web --set-default-dev-hub --alias DevHub

# Verify configuration
sf config list
```

### Step 4: Create a Scratch Org

```bash
# Create scratch org (valid for 30 days)
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias foxsec-dev \
  --duration-days 30 \
  --set-default

# Deploy source code
sf project deploy start

# Open the org
sf org open
```

---

## First Use

### Access the Dashboard

1. Open the org: `sf org open`
2. Navigate to **App Launcher** → **FoxSec**
3. The dashboard automatically displays audit results

### Run a Manual Audit

From Developer Console or VS Code:

```apex
// Execute all audits
List<FoxSecResult> results = FoxSecController.runAllAudits();

// Display results
for (FoxSecResult r : results) {
    System.debug(r.status + ' | ' + r.testName + ' | ' + r.message);
}
```

### Understanding Results

| Status | Meaning | Action |
|--------|---------|--------|
| ✅ `PASS` | No issues detected | No action required |
| ⚠️ `WARNING` | Potential risk | Evaluate and plan |
| 🔴 `CRITICAL` | Security vulnerability | Immediate action required |
| ℹ️ `INFO` | Contextual information | Manual verification |
| ⏭️ `SKIPPED` | Audit not executable | Check permissions |

---

## Advanced Configuration

### Using a Developer Edition

For complete security testing (some objects are not available in Scratch Orgs):

```bash
# Authenticate your DE org
sf org login web --alias foxsec-de --set-default

# Deploy
sf project deploy start --target-org foxsec-de

# Open
sf org open --target-org foxsec-de
```

### Run Unit Tests

```bash
# All tests with coverage
sf apex run test \
  --test-level RunLocalTests \
  --result-format human \
  --code-coverage
```

---

## Troubleshooting

### "Access Denied" Error

**Cause**: User doesn't have required permissions.

**Solution**: Assign the `FoxSec_Admin` Permission Set to the user.

### "Object Not Found" Error

**Cause**: Some Setup objects are not available in Scratch Orgs.

**Solution**: Use a Developer Edition or Sandbox. See [Scratch Org Limitations](./SCRATCH_ORG_LIMITATIONS.md).

### Audit Returns "SKIPPED"

**Cause**: Insufficient permissions or feature not enabled.

**Solution**: 
1. Verify the user has "View Setup and Configuration"
2. Verify the feature is enabled in the org

---

## Next Steps

- 📖 [Technical Architecture](./ARCHITECTURE.md) - Understand the code
- 🔐 [Security Standards](./SECURITY_STANDARDS.md) - AppExchange compliance
- 🧩 [Audit Modules](./AUDIT_MODULES.md) - Control details

---

*Need help? Open an issue on GitHub.*
