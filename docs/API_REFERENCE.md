# API Reference - FoxSec

## 📚 Apex Classes

This documentation details the public API of FoxSec for developers.

---

## FoxSecResult

**Type**: `public inherited sharing class`  
**Package**: `foxsec`  
**File**: [FoxSecResult.cls](../force-app/main/default/classes/core/FoxSecResult.cls)

### Description

Wrapper class representing the result of a security audit test. Used to communicate findings between the backend layer and the UI.

### Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `testName` | `String` | `@AuraEnabled` | Name of the security test executed |
| `status` | `String` | `@AuraEnabled` | Result status (`PASS`, `WARNING`, `CRITICAL`, `SKIPPED`, `INFO`) |
| `message` | `String` | `@AuraEnabled` | Message describing the result |
| `remediationSteps` | `String` | `@AuraEnabled` | Recommended remediation steps |

### Constants

```apex
public static final String STATUS_PASS = 'PASS';
public static final String STATUS_WARNING = 'WARNING';
public static final String STATUS_CRITICAL = 'CRITICAL';
public static final String STATUS_SKIPPED = 'SKIPPED';
public static final String STATUS_INFO = 'INFO';
```

### Constructors

#### Default Constructor

```apex
public FoxSecResult()
```

Default constructor for deserialization.

#### Full Constructor

```apex
public FoxSecResult(String testName, String status, String message, String remediationSteps)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `testName` | `String` | Test name |
| `status` | `String` | Status (`PASS`, `WARNING`, `CRITICAL`, `SKIPPED`, `INFO`) |
| `message` | `String` | Descriptive message |
| `remediationSteps` | `String` | Remediation guidance (can be `null`) |

### Usage Example

```apex
// Creating a PASS result
FoxSecResult passResult = new FoxSecResult(
    'Remote Site - HTTPS Check',
    FoxSecResult.STATUS_PASS,
    'All Remote Sites use HTTPS.',
    null
);

// Creating a CRITICAL result
FoxSecResult criticalResult = new FoxSecResult(
    'Remote Site - HTTP Protocol',
    FoxSecResult.STATUS_CRITICAL,
    'Remote Site "MyIntegration" uses insecure HTTP.',
    'Update URL to HTTPS in Setup > Security > Remote Site Settings.'
);
```

---

## IFoxSecAuditor

**Type**: `public interface`  
**Package**: `foxsec`  
**File**: [IFoxSecAuditor.cls](../force-app/main/default/classes/core/IFoxSecAuditor.cls)

### Description

Interface defining the contract for all FoxSec audit engines. Each audit module must implement this interface to be compatible with the framework.

### Methods

#### executeAudit

```apex
List<FoxSecResult> executeAudit()
```

Executes the security audit and returns findings.

| Return | Description |
|--------|-------------|
| `List<FoxSecResult>` | List of audit results |

### Implementation Example

```apex
public with sharing class CustomAuditEngine implements IFoxSecAuditor {
    
    public List<FoxSecResult> executeAudit() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        // Perform audit logic
        if (checkPassed()) {
            results.add(new FoxSecResult(
                'Custom Check',
                FoxSecResult.STATUS_PASS,
                'Custom security check passed.',
                null
            ));
        } else {
            results.add(new FoxSecResult(
                'Custom Check',
                FoxSecResult.STATUS_WARNING,
                'Custom security issue detected.',
                'Remediation instructions here.'
            ));
        }
        
        return results;
    }
    
    private Boolean checkPassed() {
        // Implementation
        return true;
    }
}
```

---

## FoxSecController

**Type**: `public with sharing class`  
**Package**: `foxsec`  
**File**: [FoxSecController.cls](../force-app/main/default/classes/core/FoxSecController.cls)

### Description

Main controller for FoxSec audit operations. Orchestrates the execution of all registered audit engines and aggregates results.

### Inner Classes

#### AuditSummary

Wrapper class for audit summary with score and statistics.

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `score` | `Integer` | `@AuraEnabled` | Global security score (0-100) |
| `totalTests` | `Integer` | `@AuraEnabled` | Total number of tests executed |
| `criticalCount` | `Integer` | `@AuraEnabled` | Number of CRITICAL results |
| `warningCount` | `Integer` | `@AuraEnabled` | Number of WARNING results |
| `passCount` | `Integer` | `@AuraEnabled` | Number of PASS results |
| `skippedCount` | `Integer` | `@AuraEnabled` | Number of SKIPPED/INFO results |
| `results` | `List<FoxSecResult>` | `@AuraEnabled` | Detailed audit results |

**Score Calculation**:
```
score = 100 - (criticalCount × 10) - (warningCount × 3)
minimum = 0
```

### Public Methods

#### getAuditSummary

```apex
@AuraEnabled(cacheable=true)
public static AuditSummary getAuditSummary()
```

Executes all registered audit engines and returns an aggregated summary with score and statistics.

| Return | Description |
|--------|-------------|
| `AuditSummary` | Summary containing score, statistics, and detailed results |

**Characteristics**:
- `@AuraEnabled`: Accessible from LWC/Aura
- `cacheable=true`: Results cached by Lightning Data Service
- Respects sharing model (`with sharing`)
- Calculates security score automatically

#### runAllAudits

```apex
@AuraEnabled(cacheable=true)
public static List<FoxSecResult> runAllAudits()
```

Executes all registered audit engines and returns aggregated results.

| Return | Description |
|--------|-------------|
| `List<FoxSecResult>` | Combined results from all audit engines |

**Characteristics**:
- `@AuraEnabled`: Accessible from LWC/Aura
- `cacheable=true`: Results cached by Lightning Data Service
- Respects sharing model (`with sharing`)

### Usage Example (Apex)

```apex
// Execute audit with summary
FoxSecController.AuditSummary summary = FoxSecController.getAuditSummary();
System.debug('Security Score: ' + summary.score);
System.debug('Critical Issues: ' + summary.criticalCount);
System.debug('Warnings: ' + summary.warningCount);

// Filter critical results
List<FoxSecResult> criticals = new List<FoxSecResult>();
for (FoxSecResult r : summary.results) {
    if (r.status == FoxSecResult.STATUS_CRITICAL) {
        criticals.add(r);
    }
}
```

### Usage Example (LWC)

```javascript
// foxSecDashboard.js
import { LightningElement, wire } from 'lwc';
import getAuditSummary from '@salesforce/apex/FoxSecController.getAuditSummary';

export default class FoxSecDashboard extends LightningElement {
    score = 0;
    criticalCount = 0;
    results = [];

    @wire(getAuditSummary)
    wiredSummary({ error, data }) {
        if (data) {
            this.score = data.score;
            this.criticalCount = data.criticalCount;
            this.results = data.results;
        } else if (error) {
            this.handleError(error);
        }
    }
}
```

---

## ConfigAuditEngine

**Type**: `public with sharing class`  
**Implements**: `IFoxSecAuditor`  
**Package**: `foxsec`  
**File**: [ConfigAuditEngine.cls](../force-app/main/default/classes/audits/ConfigAuditEngine.cls)

### Description

Audit engine for org infrastructure security settings. Scans Remote Site Settings, CSP Trusted Sites, Session Security, and administrator policies.

### Implemented Tests

| Test Name | Constant | Description |
|-----------|----------|-------------|
| Remote Site - Insecure HTTP Protocol | `TEST_REMOTE_SITE_HTTP` | Detects URLs using HTTP |
| Remote Site - Overly Permissive Wildcard | `TEST_REMOTE_SITE_WILDCARD` | Detects dangerous wildcards |
| CSP Trusted Site - Unsafe Inline | `TEST_CSP_UNSAFE_INLINE` | Checks inline configurations |
| CSP Trusted Site - Unsafe Eval | `TEST_CSP_UNSAFE_EVAL` | Checks eval configurations |
| Certificates - Expiration Check | `TEST_CERTIFICATES` | Checks certificate expiration |
| Admin Login As Any User | `TEST_LOGIN_AS_ANY_USER` | Checks admin login policy |
| Session Security - Force Logout | `TEST_SESSION_FORCE_LOGOUT` | Checks session timeout |

### Public Methods

#### executeAudit

```apex
public List<FoxSecResult> executeAudit()
```

Implementation of `IFoxSecAuditor`. Executes all infrastructure audits.

| Return | Description |
|--------|-------------|
| `List<FoxSecResult>` | Findings from all infrastructure controls |

### Risky Wildcards Detected

The engine automatically detects these patterns as dangerous:

```apex
'*.herokuapp.com'
'*.cloudfront.net'
'*.amazonaws.com'
'*.azurewebsites.net'
'*.ngrok.io'
'*.ngrok-free.app'
'*.*.*'
'*.com'
'*.net'
'*.org'
'*.io'
```

### Example Result

```json
{
    "testName": "Remote Site - Insecure HTTP Protocol",
    "status": "CRITICAL",
    "message": "Remote Site \"LegacyAPI\" uses insecure HTTP: http://api.example.com",
    "remediationSteps": "Update URL to HTTPS. Setup > Security > Remote Site Settings > LegacyAPI"
}
```

---

## UserAuditEngine

**Type**: `public with sharing class`  
**Implements**: `IFoxSecAuditor`  
**Package**: `foxsec`  
**File**: [UserAuditEngine.cls](../force-app/main/default/classes/audits/UserAuditEngine.cls)

### Description

Audit engine for Identity & Access Management security. Scans users, profiles, permission sets for excessive privileges and security risks.

### Implemented Tests

| Test Name | Constant | Description |
|-----------|----------|-------------|
| Shadow Admins - Excessive Privileges | `TEST_SHADOW_ADMINS` | Non-admin users with admin-level permissions |
| API Users - Stale Accounts | `TEST_STALE_API_USERS` | API users inactive > 90 days |
| Password Policy - Never Expires | `TEST_WEAK_PASSWORD` | Service accounts with potential non-expiring passwords |
| Guest User - Excessive Permissions | `TEST_GUEST_USER_EXPOSURE` | Guest users with write permissions |

### Critical Permissions Detected

```apex
'PermissionsAuthorApex'        // Can deploy Apex code
'PermissionsCustomizeApplication'  // Can modify org setup
'PermissionsManageUsers'       // Can create/modify users
'PermissionsViewAllData'       // Bypass sharing rules (read)
'PermissionsModifyAllData'     // Bypass sharing rules (write)
```

### Public Methods

#### executeAudit

```apex
public List<FoxSecResult> executeAudit()
```

Implementation of `IFoxSecAuditor`. Executes all IAM audits.

| Return | Description |
|--------|-------------|
| `List<FoxSecResult>` | Findings from all IAM controls |

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `STALE_DAYS_THRESHOLD` | `90` | Days of inactivity before flagging API user |
| `USER_QUERY_LIMIT` | `2000` | Max users per query (governor limits) |
| `ASSIGNMENT_QUERY_LIMIT` | `5000` | Max permission assignments per query |

### Example Results

**Shadow Admin Detection**:
```json
{
    "testName": "Shadow Admins - Excessive Privileges",
    "status": "CRITICAL",
    "message": "Shadow Admin detected: \"john.doe@company.com\" (Profile: Sales User) has critical permissions via: PermissionSet: Sales Admin Override",
    "remediationSteps": "Review and remove unnecessary privileges. Setup > Users > John Doe > Permission Set Assignments"
}
```

**Guest User Exposure**:
```json
{
    "testName": "Guest User - Excessive Permissions",
    "status": "CRITICAL",
    "message": "Guest user has write access on object \"Lead\": Create, Edit (via Profile)",
    "remediationSteps": "Remove write permissions from Guest user profile. Guest users should have minimal read-only access."
}
```

---

## Error Codes and SKIPPED Results

When an audit cannot be executed, a `SKIPPED` result is returned:

| Cause | Message Type | Recommended Action |
|-------|--------------|-------------------|
| `QueryException` | Object not accessible | Check permissions |
| `NoAccessException` | FLS/CRUD violation | Assign Permission Set |
| Object not available | Feature not enabled | Use a different org |

### Standard SKIPPED Format

```apex
{
    "testName": "Test Name",
    "status": "SKIPPED",
    "message": "Reason for skipping...",
    "remediationSteps": "Verify that the user has 'View Setup and Configuration' permission."
}
```

---

## Integration Best Practices

### 1. Error Handling

```apex
try {
    List<FoxSecResult> results = FoxSecController.runAllAudits();
    processResults(results);
} catch (AuraHandledException e) {
    // Handle gracefully in UI
    showErrorToast(e.getMessage());
}
```

### 2. Filtering Results by Severity

```apex
public static Map<String, List<FoxSecResult>> groupBySeverity(List<FoxSecResult> results) {
    Map<String, List<FoxSecResult>> grouped = new Map<String, List<FoxSecResult>>();
    
    for (FoxSecResult r : results) {
        if (!grouped.containsKey(r.status)) {
            grouped.put(r.status, new List<FoxSecResult>());
        }
        grouped.get(r.status).add(r);
    }
    
    return grouped;
}
```

### 3. Exporting Results

```apex
// Convert to JSON for export
String jsonResults = JSON.serializePretty(results);
```

---

*For more architectural details, see [ARCHITECTURE.md](./ARCHITECTURE.md).*
