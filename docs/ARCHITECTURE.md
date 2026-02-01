# Technical Architecture - FoxSec

## 🏗️ Overview

FoxSec follows a modular architecture designed for maintainability, testability, and AppExchange Security Review compliance.

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer (LWC)                           │
│                     foxSecDashboard                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │ @AuraEnabled
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Controller Layer                              │
│                   FoxSecController                               │
│              (Orchestration & Aggregation)                       │
└─────────────────────────────┬───────────────────────────────────┘
                              │ IFoxSecAuditor
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Audit Engines Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ConfigAudit   │  │UserAudit     │  │Permission    │  ...     │
│  │Engine        │  │Engine        │  │AuditEngine   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Core Layer                                    │
│           FoxSecResult (Wrapper) + IFoxSecAuditor (Interface)   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

```
force-app/main/default/
├── classes/
│   ├── core/                          # Core components
│   │   ├── FoxSecResult.cls           # Result wrapper
│   │   ├── FoxSecController.cls       # Main controller
│   │   └── IFoxSecAuditor.cls         # Engine interface
│   │
│   ├── audits/                        # Audit engines
│   │   └── ConfigAuditEngine.cls      # Infrastructure audit
│   │
│   └── audit-modules/                 # Sub-modules (future)
│
├── lwc/                               # Lightning components
│   └── foxSecDashboard/               # Main dashboard
│
├── permissionsets/                    # Permissions
└── flexipages/                        # Application pages
```

---

## 🧩 Core Components

### FoxSecResult

**File**: `force-app/main/default/classes/core/FoxSecResult.cls`

Standardized wrapper for all audit results.

```apex
public inherited sharing class FoxSecResult {
    @AuraEnabled public String testName;        // Test name
    @AuraEnabled public String status;          // PASS, WARNING, CRITICAL, SKIPPED, INFO
    @AuraEnabled public String message;         // Result description
    @AuraEnabled public String remediationSteps;// Correction steps
}
```

**Status Constants**:
| Constant | Value | Usage |
|----------|-------|-------|
| `STATUS_PASS` | `'PASS'` | No issues |
| `STATUS_WARNING` | `'WARNING'` | Moderate risk |
| `STATUS_CRITICAL` | `'CRITICAL'` | Critical vulnerability |
| `STATUS_SKIPPED` | `'SKIPPED'` | Audit not executable |
| `STATUS_INFO` | `'INFO'` | Contextual information |

### IFoxSecAuditor

**File**: `force-app/main/default/classes/core/IFoxSecAuditor.cls`

Interface that all audit engines must implement.

```apex
public interface IFoxSecAuditor {
    List<FoxSecResult> executeAudit();
}
```

**Responsibilities**:
- Guarantees a uniform contract for all engines
- Allows adding new audits without modifying the controller
- Facilitates testing with mocks

### FoxSecController

**File**: `force-app/main/default/classes/core/FoxSecController.cls`

Main controller exposing `@AuraEnabled` methods.

```apex
public with sharing class FoxSecController {
    @AuraEnabled(cacheable=true)
    public static List<FoxSecResult> runAllAudits() {
        // Orchestrates execution of all engines
    }
}
```

**Characteristics**:
- `with sharing` mandatory (CRUD/FLS compliance)
- `cacheable=true` for LDS performance
- Aggregates results from all registered engines

---

## 🔍 Audit Engines

### ConfigAuditEngine

**File**: `force-app/main/default/classes/audits/ConfigAuditEngine.cls`

Audits the org's infrastructure configuration.

**Implemented Controls**:

| Test | Description | Max Severity |
|------|-------------|--------------|
| Remote Site - HTTP | Detects HTTP URLs (unsecured) | CRITICAL |
| Remote Site - Wildcard | Detects overly permissive wildcards | WARNING |
| CSP - Unsafe Inline | Detects risky CSP configurations | WARNING |
| CSP - Unsafe Eval | Detects dangerous frame-src/connect-src | WARNING |
| Certificates | Checks certificate expiration | CRITICAL |
| Login As Any User | Checks admin login policy | WARNING |
| Session Security | Checks session settings | INFO |

**Risky Wildcard Patterns**:
```apex
private static final Set<String> RISKY_WILDCARD_PATTERNS = new Set<String>{
    '*.herokuapp.com',
    '*.cloudfront.net',
    '*.amazonaws.com',
    '*.azurewebsites.net',
    '*.ngrok.io',
    // ... other shared domains
};
```

---

## 🔒 Security Principles

### 1. Sharing Model

All classes use `with sharing` or `inherited sharing`:

```apex
public with sharing class FoxSecController { ... }
public inherited sharing class FoxSecResult { ... }
```

### 2. SOQL User Mode

All SOQL queries use `WITH USER_MODE`:

```apex
List<RemoteProxy> sites = [
    SELECT Id, SiteName, EndpointUrl
    FROM RemoteProxy
    WITH USER_MODE  // Respects FLS/CRUD
];
```

### 3. Error Handling

Errors are captured and transformed into `SKIPPED` results:

```apex
try {
    // Audit logic
} catch (System.NoAccessException nae) {
    results.add(createSkippedResult(
        TEST_NAME,
        'Access denied to object.'
    ));
}
```

### 4. XSS Protection

User values are escaped in messages:

```apex
'Remote Site "' + String.escapeSingleQuotes(site.SiteName) + '"...'
```

---

## 🔄 Data Flow

```
[User Action in LWC]
        │
        ▼
[FoxSecController.runAllAudits()]
        │
        ├──▶ [ConfigAuditEngine.executeAudit()]
        │           │
        │           ├──▶ auditRemoteSiteSettings()
        │           ├──▶ auditCspTrustedSites()
        │           ├──▶ auditCertificates()
        │           ├──▶ auditLoginAsAnyUser()
        │           └──▶ auditSessionSecurity()
        │           │
        │           ▼
        │    [List<FoxSecResult>]
        │
        ├──▶ [UserAuditEngine.executeAudit()]
        │           │
        │           ├──▶ auditShadowAdmins()
        │           ├──▶ auditStaleApiUsers()
        │           ├──▶ auditWeakPasswordPolicies()
        │           └──▶ auditGuestUserExposure()
        │           │
        │           ▼
        │    [List<FoxSecResult>]
        │
        └──▶ [PermissionAuditEngine.executeAudit()] (Future)
        │
        ▼
[Aggregated List<FoxSecResult>]
        │
        ▼
[LWC Dashboard Display]
```

---

## 🧪 Testing Strategy

### Test Structure

Each class has its corresponding test file:

| Class | Test File |
|-------|-----------|
| `FoxSecResult` | `FoxSecResultTest.cls` |
| `FoxSecController` | `FoxSecControllerTest.cls` |
| `ConfigAuditEngine` | `ConfigAuditEngineTest.cls` |
| `UserAuditEngine` | `UserAuditEngineTest.cls` |

### Minimum Coverage

- **Target**: 75% minimum (AppExchange requirement)
- **Recommended**: 90%+ for critical code

### Execution

```bash
sf apex run test --test-level RunLocalTests --code-coverage
```

---

## 🚀 Extending the Framework

### Adding a New Audit Engine

1. **Create the class** implementing `IFoxSecAuditor`:

```apex
// File: force-app/main/default/classes/audits/UserAuditEngine.cls
public with sharing class UserAuditEngine implements IFoxSecAuditor {
    public List<FoxSecResult> executeAudit() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        // Audit logic here
        return results;
    }
}
```

2. **Register in the controller**:

```apex
// In FoxSecController.runAllAudits()
IFoxSecAuditor userAuditor = new UserAuditEngine();
allResults.addAll(userAuditor.executeAudit());
```

3. **Create the corresponding tests**.

---

## 📊 Class Diagram

```
┌─────────────────────┐
│   <<interface>>     │
│   IFoxSecAuditor    │
├─────────────────────┤
│ + executeAudit()    │
└─────────┬───────────┘
          │ implements
          │
┌─────────┴───────────┐     ┌─────────────────────┐
│  ConfigAuditEngine  │────▶│    FoxSecResult     │
├─────────────────────┤     ├─────────────────────┤
│ - auditRemoteSite() │     │ + testName          │
│ - auditCspSites()   │     │ + status            │
│ - auditCertificates │     │ + message           │
│ - auditLoginAs()    │     │ + remediationSteps  │
│ - auditSession()    │     └─────────────────────┘
└─────────────────────┘              ▲
                                     │ uses
┌─────────────────────┐              │
│   UserAuditEngine   │──────────────┤
├─────────────────────┤              │
│ - auditShadowAdmins │              │
│ - auditStaleApiUser │              │
│ - auditWeakPassword │              │
│ - auditGuestUser()  │              │
└─────────────────────┘              │
                                     │
┌─────────────────────┐              │
│  FoxSecController   │──────────────┘
├─────────────────────┤
│ + runAllAudits()    │
│ - validateResults() │
└─────────────────────┘
```

---

*For implementation details, see the source code in `force-app/main/default/classes/`.*
