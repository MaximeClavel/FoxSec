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

### Public Methods

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
// Execute all audits
List<FoxSecResult> results = FoxSecController.runAllAudits();

// Filter critical results
List<FoxSecResult> criticals = new List<FoxSecResult>();
for (FoxSecResult r : results) {
    if (r.status == FoxSecResult.STATUS_CRITICAL) {
        criticals.add(r);
    }
}

System.debug('Found ' + criticals.size() + ' critical issues.');
```

### Usage Example (LWC)

```javascript
// foxSecDashboard.js
import { LightningElement, wire } from 'lwc';
import runAllAudits from '@salesforce/apex/FoxSecController.runAllAudits';

export default class FoxSecDashboard extends LightningElement {
    @wire(runAllAudits)
    wiredResults({ error, data }) {
        if (data) {
            this.auditResults = data;
            this.countCriticals();
        } else if (error) {
            this.handleError(error);
        }
    }
    
    countCriticals() {
        this.criticalCount = this.auditResults.filter(
            r => r.status === 'CRITICAL'
        ).length;
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
