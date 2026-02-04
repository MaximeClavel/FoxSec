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

### Phase 2 Methods (v2.0+)

#### exportAuditToCSV

```apex
@AuraEnabled
public static AuditExportService.ExportResult exportAuditToCSV(
    Boolean includePassedTests, 
    Boolean includeRemediation,
    String complianceTemplate
)
```

Exports current audit results to CSV format.

| Parameter | Type | Description |
|-----------|------|-------------|
| `includePassedTests` | `Boolean` | Include PASS results in export |
| `includeRemediation` | `Boolean` | Include remediation steps column |
| `complianceTemplate` | `String` | Compliance framework for mapping (optional) |

| Return | Description |
|--------|-------------|
| `ExportResult` | Contains CSV content, filename, and MIME type |

#### exportAuditToExcel

```apex
@AuraEnabled
public static AuditExportService.ExportResult exportAuditToExcel()
```

Exports current audit results to Excel XML (SpreadsheetML) format.

| Return | Description |
|--------|-------------|
| `ExportResult` | Contains Excel XML content, filename, and MIME type |

#### exportTrendDataToCSV

```apex
@AuraEnabled
public static AuditExportService.ExportResult exportTrendDataToCSV(Integer days)
```

Exports trend data for the specified period to CSV format.

| Parameter | Type | Description |
|-----------|------|-------------|
| `days` | `Integer` | Number of days of trend data to export (default: 30) |

#### getComplianceTemplates

```apex
@AuraEnabled(cacheable=true)
public static List<ComplianceTemplateService.ComplianceTemplateInfo> getComplianceTemplates()
```

Returns list of available compliance frameworks.

#### runComplianceAssessment

```apex
@AuraEnabled
public static ComplianceTemplateService.ComplianceAssessment runComplianceAssessment(String templateName)
```

Runs compliance assessment against current audit results.

| Parameter | Type | Description |
|-----------|------|-------------|
| `templateName` | `String` | Framework name: `SOC2`, `GDPR`, `HIPAA`, `ISO27001` |

#### saveAuditSnapshot

```apex
@AuraEnabled
public static Id saveAuditSnapshot(String complianceTemplate)
```

Saves current audit state to `FoxSec_Audit_Snapshot__c`.

| Return | Description |
|--------|-------------|
| `Id` | Record ID of created snapshot |

#### getTrendAnalysis

```apex
@AuraEnabled(cacheable=true)
public static AuditSnapshotService.TrendAnalysis getTrendAnalysis(Integer days)
```

Retrieves trend analysis for the specified period.

| Parameter | Type | Description |
|-----------|------|-------------|
| `days` | `Integer` | Number of days to analyze |

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

## Phase 2 Classes (v2.0)

---

## HealthScoreCalculator

**Type**: `public with sharing class`  
**Package**: `foxsec`  
**File**: [HealthScoreCalculator.cls](../force-app/main/default/classes/core/HealthScoreCalculator.cls)

### Description

Calculates security health scores based on audit results with severity weighting and grade assignment.

### Constants

```apex
public static final Integer CRITICAL_WEIGHT = 15;
public static final Integer CRITICAL_CAP = 60;
public static final Integer HIGH_WEIGHT = 8;
public static final Integer HIGH_CAP = 40;
public static final Integer MEDIUM_WEIGHT = 3;
public static final Integer MEDIUM_CAP = 20;
public static final Integer LOW_WEIGHT = 1;
public static final Integer LOW_CAP = 10;
```

### Inner Classes

#### HealthScoreResult

| Property | Type | Description |
|----------|------|-------------|
| `score` | `Integer` | Health score (0-100) |
| `grade` | `String` | Letter grade (A-F) |
| `gradeColor` | `String` | SLDS color for grade |
| `gradeLabel` | `String` | Human-readable label |
| `criticalCount` | `Integer` | CRITICAL findings count |
| `highCount` | `Integer` | HIGH/WARNING findings count |
| `mediumCount` | `Integer` | MEDIUM findings count |
| `lowCount` | `Integer` | LOW findings count |
| `passCount` | `Integer` | PASS findings count |
| `deductions` | `Map<String, Integer>` | Deductions by severity |

#### GradeInfo

| Property | Type | Description |
|----------|------|-------------|
| `grade` | `String` | Letter grade |
| `color` | `String` | SLDS color class |
| `label` | `String` | Descriptive label |
| `minScore` | `Integer` | Minimum score for grade |
| `maxScore` | `Integer` | Maximum score for grade |

### Public Methods

#### calculateScore

```apex
public static HealthScoreResult calculateScore(List<FoxSecResult> results)
```

Calculates detailed health score with grade and deduction breakdown.

#### calculateSimpleScore

```apex
public static Integer calculateSimpleScore(List<FoxSecResult> results)
```

Returns only the numeric score (0-100).

#### getGrade

```apex
public static String getGrade(Integer score)
```

Returns letter grade for a given score.

#### getGradeInfo

```apex
public static GradeInfo getGradeInfo(Integer score)
```

Returns complete grade information including color and label.

### Usage Example

```apex
List<FoxSecResult> results = FoxSecController.runAllAudits();
HealthScoreCalculator.HealthScoreResult scoreResult = HealthScoreCalculator.calculateScore(results);

System.debug('Score: ' + scoreResult.score);
System.debug('Grade: ' + scoreResult.grade);
System.debug('Critical Issues: ' + scoreResult.criticalCount);
```

---

## ComplianceTemplateService

**Type**: `public with sharing class`  
**Package**: `foxsec`  
**File**: [ComplianceTemplateService.cls](../force-app/main/default/classes/compliance/ComplianceTemplateService.cls)

### Description

Provides compliance framework templates (SOC2, GDPR, HIPAA, ISO27001) that map FoxSec audit tests to regulatory controls.

### Supported Templates

| Template | Controls | Description |
|----------|----------|-------------|
| `SOC2` | 9 | Service Organization Control 2 |
| `GDPR` | 7 | EU General Data Protection Regulation |
| `HIPAA` | 7 | Health Insurance Portability and Accountability Act |
| `ISO27001` | 8 | Information Security Management |

### Inner Classes

#### ComplianceControl

| Property | Type | Description |
|----------|------|-------------|
| `controlId` | `String` | Control identifier (e.g., CC6.1) |
| `controlName` | `String` | Control name |
| `description` | `String` | Control description |
| `mappedTests` | `List<String>` | FoxSec test names mapped to this control |
| `status` | `String` | Assessment status (PASS/FAIL/PARTIAL/NOT_ASSESSED) |
| `passedTests` | `Integer` | Number of passed tests |
| `totalTests` | `Integer` | Total mapped tests |

#### ComplianceAssessment

| Property | Type | Description |
|----------|------|-------------|
| `templateName` | `String` | Template identifier |
| `templateLabel` | `String` | Human-readable name |
| `assessmentDate` | `Datetime` | Assessment timestamp |
| `overallScore` | `Decimal` | Compliance percentage (0-100) |
| `controls` | `List<ComplianceControl>` | Assessed controls |
| `passedControls` | `Integer` | Fully compliant controls |
| `partialControls` | `Integer` | Partially compliant controls |
| `failedControls` | `Integer` | Non-compliant controls |
| `totalControls` | `Integer` | Total controls assessed |

### Public Methods

#### getAvailableTemplates

```apex
public static List<ComplianceTemplateInfo> getAvailableTemplates()
```

Returns list of available compliance templates with metadata.

#### runComplianceAssessment

```apex
public static ComplianceAssessment runComplianceAssessment(String templateName, List<FoxSecResult> auditResults)
```

Runs a compliance assessment against audit results using the specified template.

#### getTemplateControls

```apex
public static List<ComplianceControl> getTemplateControls(String templateName)
```

Returns the control definitions for a template without assessment.

### Usage Example

```apex
// Get available templates
List<ComplianceTemplateService.ComplianceTemplateInfo> templates = 
    ComplianceTemplateService.getAvailableTemplates();

// Run SOC2 assessment
List<FoxSecResult> results = FoxSecController.runAllAudits();
ComplianceTemplateService.ComplianceAssessment assessment = 
    ComplianceTemplateService.runComplianceAssessment('SOC2', results);

System.debug('SOC2 Score: ' + assessment.overallScore + '%');
System.debug('Passed Controls: ' + assessment.passedControls + '/' + assessment.totalControls);
```

---

## AuditSnapshotService

**Type**: `public with sharing class`  
**Package**: `foxsec`  
**File**: [AuditSnapshotService.cls](../force-app/main/default/classes/services/AuditSnapshotService.cls)

### Description

Manages audit snapshots for historical tracking and trend analysis. Persists audit results to `FoxSec_Audit_Snapshot__c` custom object.

### Inner Classes

#### TrendDataPoint

| Property | Type | Description |
|----------|------|-------------|
| `snapshotDate` | `Datetime` | Snapshot date |
| `score` | `Integer` | Health score at that point |
| `grade` | `String` | Grade at that point |
| `criticalCount` | `Integer` | Critical issues count |
| `highCount` | `Integer` | High issues count |
| `mediumCount` | `Integer` | Medium issues count |
| `lowCount` | `Integer` | Low issues count |
| `formattedDate` | `String` | Date formatted for display |

#### TrendAnalysis

| Property | Type | Description |
|----------|------|-------------|
| `dataPoints` | `List<TrendDataPoint>` | Historical data points |
| `averageScore` | `Decimal` | Average score over period |
| `scoreChange` | `Integer` | Change from first to last |
| `trend` | `String` | IMPROVING/DECLINING/STABLE |
| `periodStart` | `Datetime` | Analysis period start |
| `periodEnd` | `Datetime` | Analysis period end |

### Public Methods

#### createSnapshot

```apex
public static Id createSnapshot(List<FoxSecResult> results, String complianceTemplate, Decimal complianceScore)
```

Creates a new audit snapshot with optional compliance data.

#### getLatestSnapshot

```apex
public static FoxSec_Audit_Snapshot__c getLatestSnapshot()
```

Retrieves the most recent snapshot for the current org.

#### getTrendAnalysis

```apex
public static TrendAnalysis getTrendAnalysis(Integer numberOfMonths)
```

Analyzes trends over the specified number of months.

#### compareSnapshots

```apex
public static Map<String, Object> compareSnapshots(Id snapshot1Id, Id snapshot2Id)
```

Compares two snapshots and returns the differences.

#### cleanupOldSnapshots

```apex
public static Integer cleanupOldSnapshots(Integer retentionMonths)
```

Deletes snapshots older than the retention period.

### Usage Example

```apex
// Save current audit state
List<FoxSecResult> results = FoxSecController.runAllAudits();
Id snapshotId = AuditSnapshotService.createSnapshot(results, null, null);

// Analyze 6-month trend
AuditSnapshotService.TrendAnalysis trend = AuditSnapshotService.getTrendAnalysis(6);
System.debug('Trend: ' + trend.trend + ' (Score change: ' + trend.scoreChange + ')');
```

---

## AuditExportService

**Type**: `public with sharing class`  
**Package**: `foxsec`  
**File**: [AuditExportService.cls](../force-app/main/default/classes/services/AuditExportService.cls)

### Description

Exports audit results to CSV and Excel formats for external audit documentation.

### Inner Classes

#### ExportOptions

| Property | Type | Description |
|----------|------|-------------|
| `includeTimestamp` | `Boolean` | Add timestamp to export |
| `includeOrgInfo` | `Boolean` | Include org details |
| `severityFilter` | `List<String>` | Filter by severity |
| `fileName` | `String` | Custom filename |

#### ExportResult

| Property | Type | Description |
|----------|------|-------------|
| `content` | `String` | Export content (CSV/XML) |
| `fileName` | `String` | Generated filename |
| `mimeType` | `String` | MIME type |
| `recordCount` | `Integer` | Number of records exported |

### Public Methods

#### exportToCSV

```apex
public static ExportResult exportToCSV(List<FoxSecResult> results, ExportOptions options)
```

Exports detailed audit results to CSV format.

#### exportSummaryToCSV

```apex
public static ExportResult exportSummaryToCSV(FoxSecController.AuditSummary summary, ExportOptions options)
```

Exports audit summary statistics to CSV.

#### exportTrendDataToCSV

```apex
public static ExportResult exportTrendDataToCSV(AuditSnapshotService.TrendAnalysis trendData, ExportOptions options)
```

Exports trend analysis data to CSV.

#### exportToExcel

```apex
public static ExportResult exportToExcel(List<FoxSecResult> results, ExportOptions options)
```

Exports to Excel XML format (SpreadsheetML).

### Usage Example

```apex
// Export audit results to CSV
List<FoxSecResult> results = FoxSecController.runAllAudits();
AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
options.includeTimestamp = true;
options.includeOrgInfo = true;

AuditExportService.ExportResult export = AuditExportService.exportToCSV(results, options);

// Content is ready for download
System.debug('File: ' + export.fileName);
System.debug('Records: ' + export.recordCount);
```

---

*For more architectural details, see [ARCHITECTURE.md](./ARCHITECTURE.md).*
