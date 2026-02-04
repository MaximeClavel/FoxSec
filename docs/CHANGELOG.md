# Changelog - FoxSec

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- PermissionAuditEngine: Sensitive permissions audit
- FlowAuditEngine: Flow security audit
- Remediation Flow: Automated corrective actions
- Multi-Org Dashboard: Aggregate scores from multiple orgs

---

## [2.0.1] - 2026-02-04

### Fixed

#### LWC Dashboard Bugs
- **Tab Persistence**: Fixed issue where running a compliance assessment would reset the view to Overview tab instead of staying on Compliance tab
  - Added `isInitialLoading` state to distinguish initial load from action loading
  - Added `onactive` handler on `lightning-tabset` to track active tab
  - Spinner now displays as overlay during actions without destroying the DOM

- **Refresh Button**: Fixed infinite spinner when clicking Refresh button
  - `handleRefresh()` now properly awaits `refreshApex()` promises with `Promise.all()`
  - Added `finally` block to ensure `isLoading` is reset

- **Export Menu Position**: Fixed export dropdown menu appearing outside viewport
  - Added `menu-alignment="right"` to `lightning-button-menu`

- **CSV/Excel Export**: Fixed "Lightning Web Security: Unsupported MIME type" error
  - Replaced `Blob` + `URL.createObjectURL()` with base64 data URI for LWS compatibility
  - Download now uses `data:mime/type;base64,content` format

### Added

- **FoxSecController.exportAuditToExcel()**: New `@AuraEnabled` method for Excel export
  - Previously Excel export was incorrectly calling CSV export method
  - Now properly calls `AuditExportService.exportToExcel()`

### Changed

- **Custom Object Fields**: All fields on `FoxSec_Audit_Snapshot__c` set to `required=false`
  - Fixed deployment errors: "You cannot deploy to a required field"
  - Affected fields: `Health_Score__c`, `Snapshot_Date__c`

---

## [2.0.0] - 2026-02-04

### Added - Phase 2: Security Compliance Suite

#### New Apex Classes

- **HealthScoreCalculator** (`force-app/main/default/classes/core/HealthScoreCalculator.cls`)
  - Security health score calculation (0-100) with severity weighting
  - Grade system: A (90-100), B (75-89), C (60-74), D (40-59), F (0-39)
  - Deduction caps per severity to prevent score collapse
  - Inner classes: `HealthScoreResult`, `GradeInfo`

- **ComplianceTemplateService** (`force-app/main/default/classes/compliance/ComplianceTemplateService.cls`)
  - Pre-built compliance frameworks: SOC2 (9 controls), GDPR (7), HIPAA (7), ISO27001 (8)
  - Maps FoxSec tests to regulatory controls
  - Compliance assessment with pass/partial/fail status per control
  - Inner classes: `ComplianceControl`, `ComplianceAssessment`, `ComplianceTemplateInfo`

- **AuditSnapshotService** (`force-app/main/default/classes/services/AuditSnapshotService.cls`)
  - Audit snapshot persistence to custom object
  - Trend analysis over configurable time periods
  - Snapshot comparison (baseline vs current)
  - Automatic cleanup of old snapshots
  - Inner classes: `TrendDataPoint`, `TrendAnalysis`

- **AuditExportService** (`force-app/main/default/classes/services/AuditExportService.cls`)
  - CSV export for audit results and summaries
  - Excel XML (SpreadsheetML) export
  - Trend data export for external reporting
  - Inner classes: `ExportOptions`, `ExportResult`

#### New Custom Object

- **FoxSec_Audit_Snapshot__c** (`force-app/main/default/objects/FoxSec_Audit_Snapshot__c/`)
  - 14 custom fields for historical audit data
  - Fields: Snapshot_Date__c, Health_Score__c, Grade__c, Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c, Pass_Count__c, Total_Tests__c, Org_Id__c, Audit_Details__c (JSON), Compliance_Template__c, Compliance_Score__c, Run_By__c

#### Updated LWC Dashboard

- **foxSecDashboard** - Complete UI overhaul
  - 3-tab interface: Overview, Compliance, Trends
  - Grade badge display with color coding
  - Compliance assessment UI with template selector
  - Trend visualization (bar chart)
  - Export button menu (CSV/Excel)
  - Snapshot save functionality

#### Updated Controller Methods

- **FoxSecController** - 9 new `@AuraEnabled` methods:
  - `getComplianceTemplates()` - List available compliance templates
  - `runComplianceAssessment(templateName)` - Execute compliance assessment
  - `saveAuditSnapshot(complianceTemplate, complianceScore)` - Persist audit state
  - `getTrendAnalysis(numberOfMonths)` - Retrieve trend data
  - `getLatestSnapshot()` - Get most recent snapshot
  - `exportAuditToCSV()` - Export current audit to CSV
  - `exportAuditToExcel()` - Export current audit to Excel XML
  - `exportTrendDataToCSV(numberOfMonths)` - Export trend data to CSV
  - `compareSnapshots(snapshot1Id, snapshot2Id)` - Compare two snapshots

#### Updated Permission Set

- **FoxSec_Admin.permissionset-meta.xml**
  - Added Apex class access: HealthScoreCalculator, ComplianceTemplateService, AuditSnapshotService, AuditExportService
  - Added object permissions: FoxSec_Audit_Snapshot__c (CRUD + ViewAll)
  - Added field permissions for all 14 snapshot fields

### Security
- All new classes use `with sharing` enforcement
- CRUD/FLS checks via `Security.stripInaccessible` and `WITH USER_MODE`
- Export service handles special characters (CSV injection prevention)
- No external callouts for data exfiltration prevention

---

## [1.2.1] - 2026-02-01

### Added

#### Application Metadata
- **Custom Tab** (`FoxSec_Dashboard.tab-meta.xml`)
  - Lightning Tab pointing to `foxSecDashboard` LWC
  - Label: "FoxSec Audit"
  - Icon: Custom70 (Handshake)

- **Lightning App** (`FoxSec.app-meta.xml`)
  - Label: "FoxSec Security"
  - Navigation: Standard
  - UI Type: Lightning
  - Default Landing Tab: FoxSec_Dashboard

- **Permission Set** (`FoxSec_Admin.permissionset-meta.xml`)
  - Label: "FoxSec Admin Access"
  - Apex Class Access: FoxSecController, ConfigAuditEngine, UserAuditEngine, SharingAuditEngine, FoxSecResult
  - Tab Visibility: FoxSec_Dashboard (Visible)
  - App Visibility: FoxSec (Visible)
  - System Permissions: ViewRoles, ViewSetup
  - Note: ViewAllData/ModifyAllData intentionally excluded for AppExchange compliance

### Fixed

#### UserAuditEngine
- **NullPointerException Fix**: Added null-safe checks for `Profile.Name` access
  - `AutomatedProcess` users and other system users may have null Profile
  - Affected methods: `auditShadowAdmins()`, `auditWeakPasswordPolicies()`
  - Pattern: `(u.Profile != null && u.Profile.Name != null) ? u.Profile.Name : 'N/A'`

### Security
- Permission Set follows AppExchange Security Review best practices
- ViewAllData not included in package - admins must have it via Profile
- Minimal privilege principle applied

---

## [1.2.0] - 2026-02-01

### Added

#### FoxSecController
- **AuditSummary Inner Class**: Wrapper containing score, statistics, and detailed results
- **getAuditSummary() Method**: Returns aggregated audit data with security score calculation
  - Score formula: `100 - (criticals × 10) - (warnings × 3)`
  - Minimum score capped at 0

#### foxSecDashboard (LWC)
- **Security Score Gauge**: SVG-based semicircle gauge with animated fill
  - Color coding: Green (≥80), Yellow (50-79), Red (<50)
  - Real-time score display in center
- **Statistics Cards**: Visual summary of Critical, Warning, Pass, and Total counts
  - Hover effects and color-coded borders
- **Audit Results DataTable**: Sortable table with all audit findings
  - Impact column with SLDS badges (red for CRITICAL, yellow for WARNING)
  - Custom sorting by severity level
  - Wrap text support for long messages
- **Refresh Button**: Manual audit re-execution with loading state
- **Responsive Design**: Mobile-friendly layout with CSS media queries

### Changed
- `FoxSecController.runAllAudits()` now also usable standalone (unchanged API)

---

## [1.1.0] - 2026-01-31

### Added

#### UserAuditEngine
- **Shadow Admin Detection** (CRITICAL)
  - Detects non-admin users with `AuthorApex`, `CustomizeApplication`, `ManageUsers`, `ViewAllData`, `ModifyAllData`
  - Scans both Profile and PermissionSet assignments
  - Reports permission source for each shadow admin

- **Stale API Users Detection** (WARNING/CRITICAL)
  - Identifies API-enabled users inactive > 90 days
  - CRITICAL severity for users who never logged in
  - Scans both Profile-based and PermissionSet-based API access

- **Weak Password Policy Detection** (WARNING)
  - Identifies potential service/integration accounts
  - Detects `AutomatedProcess` user types
  - Provides org-level password policy guidance

- **Guest User Exposure Detection** (CRITICAL)
  - Scans Guest users for write permissions (Create, Edit, Delete)
  - Checks both Profile and PermissionSet ObjectPermissions
  - AppExchange Security Review blocker alert

#### Tests
- `UserAuditEngineTest`: Comprehensive IAM engine tests
  - Interface implementation validation
  - All audit methods coverage
  - Governor limits verification
  - Result formatting validation

### Changed
- **FoxSecController**: Now executes both `ConfigAuditEngine` and `UserAuditEngine`
- **Documentation**: Updated ARCHITECTURE.md, API_REFERENCE.md, AUDIT_MODULES.md

### Performance
- Query limits: `USER_QUERY_LIMIT = 2000`, `ASSIGNMENT_QUERY_LIMIT = 5000`
- Optimized SOQL with filters in WHERE clauses
- No post-query loops on large datasets

---

## [1.0.0] - 2026-01-30

### Added

#### Core Framework
- **FoxSecResult**: Wrapper class for audit results
  - Properties: `testName`, `status`, `message`, `remediationSteps`
  - Status constants: `PASS`, `WARNING`, `CRITICAL`, `SKIPPED`, `INFO`
  - `@AuraEnabled` support for LWC exposure

- **IFoxSecAuditor**: Interface for audit engines
  - Method `executeAudit()` returning `List<FoxSecResult>`
  - Uniform contract for all modules

- **FoxSecController**: Main controller
  - Method `runAllAudits()` with `@AuraEnabled(cacheable=true)`
  - Audit engine orchestration
  - Result validation

#### ConfigAuditEngine
- **Remote Site Settings Audit**
  - HTTP protocol detection (CRITICAL)
  - Risky wildcards detection (WARNING)
  - Detected patterns: `*.herokuapp.com`, `*.amazonaws.com`, etc.

- **CSP Trusted Sites Audit**
  - Unsafe-inline configuration detection
  - Wildcards on frame-src/connect-src detection

- **Certificate Expiration Audit**
  - Expiration < 30 days verification (WARNING)
  - Expired certificates detection (CRITICAL)
  - INFO fallback if object not accessible

- **Login As Any User Audit**
  - Org type detection (Production vs Sandbox)
  - Contextual recommendations

- **Session Security Audit**
  - Session security levels analysis
  - Force Logout on Timeout guidance

#### Tests
- `FoxSecResultTest`: Wrapper unit tests
- `FoxSecControllerTest`: Controller tests
- `ConfigAuditEngineTest`: Configuration engine tests

#### Documentation
- README with setup instructions
- Scratch Org limitations documentation

### Security
- All classes use `with sharing` or `inherited sharing`
- All SOQL queries use `WITH USER_MODE`
- No SOQL concatenation (bind variables only)
- User value escaping (`String.escapeSingleQuotes`)
- Graceful permission error handling

### Technical
- API Version: 65.0
- Namespace: `foxsec`
- Package: FoxSec (Winter 2026)

---

## [0.1.0] - 2026-01-25 (Internal)

### Added
- Initial SFDX project structure
- Scratch org configuration
- Core classes scaffolding

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 | 2026-01-30 | First release: Core + ConfigAuditEngine |
| 0.1.0 | 2026-01-25 | Initial project structure |

---

## Upgrade Notes

### From 0.x to 1.0.0

This version is the first public release. No migration required.

### Future Upgrades

Future updates will follow these principles:
- **Backward Compatibility**: Public interfaces will be maintained
- **Deprecation**: Minimum 2 versions before removal
- **Security**: Security patches backported to the latest major

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.

---

*Links to GitHub releases will be added after publication.*

[Unreleased]: https://github.com/your-org/foxsec/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/your-org/foxsec/releases/tag/v1.0.0
[0.1.0]: https://github.com/your-org/foxsec/releases/tag/v0.1.0
