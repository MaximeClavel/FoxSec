# FoxSec - Product Roadmap

## 📊 Current State (v2.0)

| Module | Implemented Tests | Status |
|--------|-------------------|--------|
| **ConfigAuditEngine** | Remote Sites, CSP, Certificates, Sessions | ✅ v1.0 |
| **UserAuditEngine** | Shadow Admins, API Users, Guest Users, Passwords | ✅ v1.1 |
| **SharingAuditEngine** | OWD (Account/Contact/Case), External Sharing, Public Files | ✅ v1.0 |
| **HealthScoreCalculator** | Security score 0-100, grades A-F, deduction caps | ✅ v2.0 |
| **ComplianceTemplateService** | SOC2, GDPR, HIPAA, ISO27001 control mappings | ✅ v2.0 |
| **AuditSnapshotService** | Snapshot persistence, trend analysis, comparison | ✅ v2.0 |
| **AuditExportService** | CSV/Excel export for external audits | ✅ v2.0 |

---

## 🎯 Feature Phases

### **Phase 2: Security Compliance Suite** ✅ IMPLEMENTED (Inspired by Security Center)

**Completed**: v2.0  
**Theme**: Visibility & Compliance

| Feature | Description | Priority | Complexity | Status |
|---------|-------------|----------|------------|--------|
| **Security Health Score** | Global score 0-100 with severity weighting | 🔴 High | Medium | ✅ Done |
| **Baseline Comparison** | Compare current config vs defined "gold standard" | 🔴 High | Medium | ✅ Done |
| **Multi-Org Dashboard** | Aggregate scores from multiple orgs (sandbox/prod) | 🟡 Medium | High | 🔜 Future |
| **Compliance Templates** | SOC2, HIPAA, GDPR, ISO27001 templates with mapped controls | 🔴 High | Medium | ✅ Done |
| **Trend Analysis** | Score evolution over time (custom object storage) | 🟡 Medium | Low | ✅ Done |
| **PDF/Excel Export** | Export reports for external audits | 🔴 High | Low | ✅ Done (CSV/Excel) |

#### Implementation Details (v2.0)

**New Apex Classes**:
- `HealthScoreCalculator.cls` - Score calculation with severity weighting and grade system
- `ComplianceTemplateService.cls` - 4 compliance frameworks (SOC2, GDPR, HIPAA, ISO27001)
- `AuditSnapshotService.cls` - Snapshot CRUD, trend analysis, snapshot comparison
- `AuditExportService.cls` - CSV and Excel export functionality

**New Custom Object**:
- `FoxSec_Audit_Snapshot__c` - 14 fields for historical audit data

**Updated LWC**:
- `foxSecDashboard` - 3-tab interface (Overview, Compliance, Trends)

#### 2.1 - Security Health Score (Detailed)

**Concept**: A single numerical score (0-100) representing the overall security posture of the org.

**Calculation Formula**:
```
Score = 100 - Σ(Finding × Weight)

Where:
- CRITICAL finding = -15 points (capped at -60)
- HIGH finding = -8 points (capped at -40)
- MEDIUM finding = -3 points (capped at -20)
- LOW finding = -1 point (capped at -10)
```

**Score Grades**:
| Range | Grade | Color | Meaning |
|-------|-------|-------|---------|
| 90-100 | A | 🟢 Green | Excellent security posture |
| 75-89 | B | 🟡 Yellow | Good, minor improvements needed |
| 60-74 | C | 🟠 Orange | Fair, significant risks present |
| 40-59 | D | 🔴 Red | Poor, critical issues detected |
| 0-39 | F | ⚫ Black | Critical, immediate action required |

**Data Model**:
```
FoxSec_Audit_Snapshot__c
├── Snapshot_Date__c (DateTime)
├── Health_Score__c (Number)
├── Critical_Count__c (Number)
├── High_Count__c (Number)
├── Medium_Count__c (Number)
├── Low_Count__c (Number)
├── Org_Id__c (Text)
└── Audit_Details__c (LongTextArea - JSON)
```

#### 2.2 - Compliance Templates

Pre-built audit profiles mapping FoxSec tests to compliance frameworks:

**SOC2 Template**:
| Control | FoxSec Test | Mapping |
|---------|-------------|---------|
| CC6.1 - Logical Access | Shadow Admins | Direct |
| CC6.1 - Logical Access | Guest User Exposure | Direct |
| CC6.2 - Authentication | Password Policy | Direct |
| CC6.3 - System Operations | API Users Stale | Direct |
| CC6.6 - Boundaries | Remote Site HTTP | Direct |

**GDPR Template**:
| Requirement | FoxSec Test | Mapping |
|-------------|-------------|---------|
| Art. 25 - Data Protection | OWD Settings | Direct |
| Art. 32 - Security | Session Security | Direct |
| Art. 32 - Security | Certificate Expiry | Direct |

---

### **Phase 3: Shield-Equivalent Features** (Inspired by Salesforce Shield)

**Target**: Q3 2026  
**Theme**: Real-Time Threat Detection

#### 3.1 - Event Monitoring & Real-Time Surveillance

| Feature | Description | Priority | Data Source |
|---------|-------------|----------|-------------|
| **Login Anomaly Detection** | Suspicious login detection (geo, device, unusual time) | 🔴 High | `LoginEvent`, `LoginHistory` |
| **Data Export Surveillance** | Alerts on mass exports (Reports, Data Loader) | 🔴 High | `ReportEvent`, `ApiEvent` |
| **API Call Monitoring** | Monitor abnormal API calls (volume, endpoints) | 🔴 High | `ApiEvent`, `ApiTotalUsage` |
| **Permission Changes Tracker** | Real-time audit of permission changes | 🔴 High | `SetupAuditTrail` |
| **Session Hijacking Detection** | Detect duplicate sessions or IP switching | 🟡 Medium | `AuthSession` |

**Login Anomaly Detection Rules**:
```
Rule 1: Geographic Impossibility
- IF user logs in from Location A
- AND logs in from Location B within X hours
- WHERE distance(A, B) / X > 800 km/h
- THEN flag as IMPOSSIBLE_TRAVEL

Rule 2: Unusual Time Access
- IF login time NOT IN user's typical 80% time window
- AND access to sensitive data
- THEN flag as UNUSUAL_TIME_ACCESS

Rule 3: New Device + Sensitive Action
- IF device fingerprint is new
- AND user performs (export OR permission change OR config change)
- THEN flag as NEW_DEVICE_SENSITIVE_ACTION

Rule 4: Brute Force Attempt
- IF failed_logins > 5 within 10 minutes
- FROM same IP or same username
- THEN flag as BRUTE_FORCE_ATTEMPT
```

#### 3.2 - Real-Time Event Dashboard (LWC Components)

| Component | Function | Technology |
|-----------|----------|------------|
| **foxSecLiveFeed** | Stream security events in real-time | empApi (Streaming) |
| **foxSecThreatMap** | Geographic visualization of connections | Leaflet.js / Custom SVG |
| **foxSecAlertBell** | Push notifications for critical events | Platform Events |
| **foxSecActivityHeatmap** | Suspicious activity hours/days | D3.js / Chart.js |
| **foxSecUserTimeline** | Activity timeline for specific user | LWC Timeline |

**Event Categories**:
```
┌─────────────────────────────────────────────────────────────────┐
│                     SECURITY EVENTS                             │
├─────────────────────────────────────────────────────────────────┤
│ LOGIN          │ Login, LoginAs, Logout, FailedLogin, LoginGeo │
│ API            │ ApiCall, BulkApi, CompositeApi, RestApi       │
│ DATA           │ Export, MassDelete, MassUpdate, ReportRun     │
│ CONFIG         │ PermissionChange, ProfileEdit, PSAssignment   │
│ INTEGRATION    │ ConnectedAppAccess, OAuthGrant, ExternalCall  │
│ THREAT         │ BruteForce, ImpossibleTravel, Anomaly         │
└─────────────────────────────────────────────────────────────────┘
```

---

### **Phase 4: Advanced Audit Engines**

**Target**: Q1-Q2 2026  
**Theme**: Deep Security Analysis

#### 4.1 - PermissionAuditEngine

**Class**: `PermissionAuditEngine.cls`  
**Category**: Permission & Access Analysis

| Test ID | Test Name | Severity | Description |
|---------|-----------|----------|-------------|
| `PERM_EXPLOSION` | Permission Explosion Analysis | ⚠️ WARNING | Profiles/PS with > 50 permissions |
| `PERM_EFFECTIVE` | Effective Permission Calculator | ℹ️ INFO | Calculate real permissions (Profile + PS + PSGroups) |
| `PERM_UNUSED` | Least Privilege Violations | ⚠️ WARNING | Users with never-used permissions |
| `PERM_ORPHAN` | Orphan Permission Sets | ℹ️ INFO | PS assigned to 0 users |
| `PERM_CONFLICT` | Conflicting Permissions | ⚠️ WARNING | PS that contradict each other |
| `PERM_VIEWALL` | View All Data Audit | 🔴 CRITICAL | All users with ViewAllData |
| `PERM_MODIFYALL` | Modify All Data Audit | 🔴 CRITICAL | All users with ModifyAllData |
| `PERM_AUTHOR_APEX` | Author Apex Audit | 🔴 CRITICAL | Non-admin users who can deploy code |

**Permission Explosion Detection Logic**:
```apex
// Identify profiles/permission sets with excessive permissions
Integer EXPLOSION_THRESHOLD = 50;

// Count enabled permissions per Profile
Map<Id, Integer> profilePermCount = new Map<Id, Integer>();
for (Profile p : [SELECT Id, (SELECT Id FROM ObjectPermissions), 
                          (SELECT Id FROM FieldPermissions) 
                   FROM Profile]) {
    Integer count = p.ObjectPermissions.size() + p.FieldPermissions.size();
    if (count > EXPLOSION_THRESHOLD) {
        // Flag as permission explosion
    }
}
```

#### 4.2 - FlowAuditEngine

**Class**: `FlowAuditEngine.cls`  
**Category**: Automation Security

| Test ID | Test Name | Severity | Description |
|---------|-----------|----------|-------------|
| `FLOW_NO_FAULT` | Flows Without Error Handling | ⚠️ WARNING | Flows without fault path |
| `FLOW_SYSTEM_MODE` | Flows Running as Admin | 🔴 CRITICAL | Flows in "System Context without Sharing" |
| `FLOW_SCHEDULED` | Scheduled Flows Review | ℹ️ INFO | Scheduled flows with sensitive access |
| `FLOW_SENSITIVE_DML` | Sensitive Object Modification | ⚠️ WARNING | Flows modifying User, Profile, PermissionSet |
| `FLOW_HARDCODED` | Hardcoded Values | ⚠️ WARNING | Flows with hardcoded IDs or credentials |
| `FLOW_LOOP_DML` | DML in Loops | ⚠️ WARNING | Flows with DML inside loops |

**Metadata API Query**:
```apex
// Query Flow metadata via Tooling API
String query = 'SELECT Id, FullName, Status, ProcessType, RunInMode, ' +
               'Description FROM Flow WHERE Status = \'Active\'';
// Analyze RunInMode for system context detection
```

#### 4.3 - ApexSecurityEngine

**Class**: `ApexSecurityEngine.cls`  
**Category**: Code Security Analysis

| Test ID | Test Name | Severity | Description |
|---------|-----------|----------|-------------|
| `APEX_NO_SHARING` | Without Sharing Classes | 🔴 CRITICAL | Classes without explicit sharing declaration |
| `APEX_SOQL_INJECT` | SOQL Injection Risk | 🔴 CRITICAL | String concatenation in SOQL |
| `APEX_HARDCODED_ID` | Hardcoded IDs | ⚠️ WARNING | Hardcoded record IDs in code |
| `APEX_HARDCODED_URL` | Hardcoded URLs | ⚠️ WARNING | Hardcoded URLs (should use Custom Metadata) |
| `APEX_DML_LOOP` | DML in Loops | ⚠️ WARNING | DML operations inside loops |
| `APEX_NO_TEST` | Missing Test Coverage | ⚠️ WARNING | Classes < 75% coverage |
| `APEX_CRUD_FLS` | Missing CRUD/FLS Check | 🔴 CRITICAL | DML without Security.stripInaccessible |

**Detection Patterns**:
```apex
// Pattern 1: No sharing declaration
// RISK: Class without 'with sharing' or 'inherited sharing'
Pattern: public class ClassName {  // Missing sharing keyword

// Pattern 2: SOQL Injection
// RISK: User input concatenated into query
Pattern: Database.query('SELECT ... WHERE Name = \'' + userInput + '\'');

// Pattern 3: Hardcoded ID
// RISK: Environment-specific IDs
Pattern: Id recordTypeId = '012000000000AAA';
```

#### 4.4 - IntegrationSecurityEngine

**Class**: `IntegrationSecurityEngine.cls`  
**Category**: Integration & Connected Apps Security

| Test ID | Test Name | Severity | Description |
|---------|-----------|----------|-------------|
| `INT_CONNECTED_APP` | Connected Apps Audit | ⚠️ WARNING | Apps with "Admin approved users are pre-authorized" |
| `INT_NAMED_CRED` | Named Credentials Security | 🔴 CRITICAL | Credentials with password vs OAuth/JWT |
| `INT_EXTERNAL_SVC` | External Services Review | ℹ️ INFO | Connected external services inventory |
| `INT_OAUTH_SCOPE` | OAuth Scope Analysis | ⚠️ WARNING | Apps with excessive OAuth scopes |
| `INT_EXPIRED_TOKEN` | Expired OAuth Tokens | ⚠️ WARNING | Refresh tokens not used in 90+ days |
| `INT_CALLOUT_HTTP` | Insecure Callouts | 🔴 CRITICAL | Named Credentials using HTTP |

---

### **Phase 5: Real-Time Monitoring System**

**Target**: Q3-Q4 2026  
**Theme**: Live Security Operations Center

#### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FoxSec Live Monitor                          │
│                 (Platform Events + Streaming API)               │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Login Events   │  │  API Events     │  │  Setup Events   │
│ (EventLogFile)  │  │ (EventLogFile)  │  │(SetupAuditTrail)│
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              FoxSecEventProcessor (Scheduled Batch)             │
│           - Pattern Detection                                    │
│           - Anomaly Scoring                                      │
│           - Alert Generation                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              FoxSec_Security_Alert__e (Platform Event)          │
│           - Alert_Type__c, Severity__c                          │
│           - User_Id__c, Details__c                               │
│           - Timestamp__c                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              foxSecLiveMonitor (LWC)                            │
│           - empApi (Subscribe to Platform Events)               │
│           - Real-time charts                                     │
│           - Alert notifications                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Data Model

**FoxSec_Security_Event__c** (Custom Object - Historical Storage):
```
Fields:
├── Event_Type__c (Picklist: Login, API, Data, Config, Integration, Threat)
├── Severity__c (Picklist: Critical, High, Medium, Low, Info)
├── Event_Timestamp__c (DateTime)
├── User__c (Lookup: User)
├── Source_IP__c (Text)
├── Geo_Location__c (Geolocation)
├── Country_Code__c (Text)
├── Device_Info__c (Text)
├── Action__c (Text)
├── Target_Object__c (Text)
├── Target_Record_Id__c (Text)
├── Details__c (LongTextArea - JSON)
├── Risk_Score__c (Number)
├── Is_Anomaly__c (Checkbox)
├── Related_Alert__c (Lookup: FoxSec_Security_Alert__c)
└── Resolution_Status__c (Picklist: Open, Investigating, Resolved, FalsePositive)
```

**FoxSec_Security_Alert__c** (Custom Object - Alerts):
```
Fields:
├── Alert_Name__c (Text)
├── Alert_Type__c (Picklist)
├── Severity__c (Picklist)
├── Triggered_At__c (DateTime)
├── User__c (Lookup: User)
├── Description__c (LongTextArea)
├── Recommended_Action__c (LongTextArea)
├── Status__c (Picklist: New, Acknowledged, Investigating, Resolved)
├── Assigned_To__c (Lookup: User)
├── Resolution_Notes__c (LongTextArea)
└── Event_Count__c (Number)
```

**FoxSec_Security_Alert__e** (Platform Event - Real-time):
```
Fields:
├── Alert_Type__c (Text)
├── Severity__c (Text)
├── User_Id__c (Text)
├── Message__c (Text)
├── Details__c (Text - JSON)
└── Timestamp__c (DateTime)
```

#### Monitored Events Matrix

| Category | Event Type | Source | Refresh Rate |
|----------|------------|--------|--------------|
| **Login** | Login Success | LoginHistory | Real-time |
| **Login** | Login Failure | LoginHistory | Real-time |
| **Login** | Login As | LoginHistory | Real-time |
| **Login** | Logout | LoginHistory | Real-time |
| **API** | REST API Call | EventLogFile | Hourly |
| **API** | SOAP API Call | EventLogFile | Hourly |
| **API** | Bulk API Job | AsyncApexJob | Real-time |
| **Data** | Report Export | EventLogFile | Hourly |
| **Data** | Mass Delete | EventLogFile | Hourly |
| **Config** | Permission Change | SetupAuditTrail | 15 min |
| **Config** | Profile Edit | SetupAuditTrail | 15 min |
| **Config** | User Creation | SetupAuditTrail | 15 min |

---

### **Phase 6: Remediation & Automation**

**Target**: Q4 2026  
**Theme**: Agentforce-Ready Security Operations

#### 6.1 - One-Click Remediation Actions

| Finding | Action | Risk Level |
|---------|--------|------------|
| Remote Site HTTP | Disable Remote Site | Low |
| Stale API User | Deactivate User | Medium |
| Expired Certificate | Send Alert Email | Low |
| Shadow Admin | Revoke Permission Set | High |
| Guest Write Access | Remove Permission | High |

#### 6.2 - Invocable Methods for Agentforce

```apex
// File: force-app/main/default/classes/remediation/FoxSecRemediationActions.cls

/**
 * Invocable actions for Agentforce AI integration
 * These methods can be called by AI agents to remediate security findings
 */
public with sharing class FoxSecRemediationActions {

    /**
     * Deactivate a user account
     * Use case: Stale API users, compromised accounts
     */
    @InvocableMethod(label='Deactivate User' 
                     description='Deactivates a user account for security reasons'
                     category='FoxSec Security')
    public static List<ActionResult> deactivateUser(List<DeactivateRequest> requests) {
        // Implementation
    }

    /**
     * Revoke a permission set from a user
     * Use case: Shadow admin remediation
     */
    @InvocableMethod(label='Revoke Permission Set' 
                     description='Removes a permission set assignment from a user'
                     category='FoxSec Security')
    public static List<ActionResult> revokePermissionSet(List<RevokeRequest> requests) {
        // Implementation
    }

    /**
     * Force password reset for a user
     * Use case: Suspected credential compromise
     */
    @InvocableMethod(label='Force Password Reset' 
                     description='Forces a password reset for specified users'
                     category='FoxSec Security')
    public static List<ActionResult> forcePasswordReset(List<PasswordResetRequest> requests) {
        // Implementation
    }

    /**
     * Disable a Remote Site Setting
     * Use case: Insecure HTTP remote sites
     */
    @InvocableMethod(label='Disable Remote Site' 
                     description='Disables a remote site setting'
                     category='FoxSec Security')
    public static List<ActionResult> disableRemoteSite(List<RemoteSiteRequest> requests) {
        // Implementation via Metadata API
    }

    /**
     * Create security alert
     * Use case: AI-detected anomalies
     */
    @InvocableMethod(label='Create Security Alert' 
                     description='Creates a FoxSec security alert record'
                     category='FoxSec Security')
    public static List<ActionResult> createSecurityAlert(List<AlertRequest> requests) {
        // Implementation
    }

    // Request/Response wrapper classes
    public class DeactivateRequest {
        @InvocableVariable(required=true description='User ID to deactivate')
        public Id userId;
        @InvocableVariable(description='Reason for deactivation')
        public String reason;
    }

    public class RevokeRequest {
        @InvocableVariable(required=true description='User ID')
        public Id userId;
        @InvocableVariable(required=true description='Permission Set ID to revoke')
        public Id permissionSetId;
        @InvocableVariable(description='Reason for revocation')
        public String reason;
    }

    public class ActionResult {
        @InvocableVariable(description='Success status')
        public Boolean success;
        @InvocableVariable(description='Result message')
        public String message;
        @InvocableVariable(description='Error details if failed')
        public String errorDetails;
    }
}
```

#### 6.3 - Scheduled Security Scans

**FoxSecScheduledAudit** (Schedulable Batch):
```apex
// Run daily at 2 AM
String cronExp = '0 0 2 * * ?';
System.schedule('FoxSec Daily Audit', cronExp, new FoxSecScheduledAudit());
```

**Features**:
- Daily full audit scan
- Store results in `FoxSec_Audit_Snapshot__c`
- Compare with previous day's results
- Generate alerts for new findings
- Email digest to security team

---

### **Phase 7: Advanced Features**

**Target**: 2027  
**Theme**: Enterprise-Grade Security Platform

| Feature | Description | Complexity | Dependencies |
|---------|-------------|------------|--------------|
| **Threat Intelligence Feed** | Integration with IP blacklists (local check, no data exfil) | High | Phase 5 |
| **ML Anomaly Detection** | Einstein-based pattern detection | High | Phase 5 |
| **Cross-Object Data Flow** | Visualize data flows between objects | Medium | Phase 4 |
| **Security Playbooks** | Interactive incident response guides | Low | Phase 6 |
| **Slack/Teams Alerts** | External notifications via Platform Events | Medium | Phase 5 |
| **Custom Rule Engine** | Admin-defined custom security rules | High | All phases |
| **Multi-Org Federation** | Central dashboard for multiple orgs | High | Phase 2 |

#### 7.1 - Custom Rule Engine

Allow admins to create custom security rules without code:

**FoxSec_Custom_Rule__c** (Custom Object):
```
Fields:
├── Rule_Name__c (Text)
├── Description__c (LongTextArea)
├── Is_Active__c (Checkbox)
├── Target_Object__c (Text) - Object API name to query
├── Filter_Condition__c (LongTextArea) - SOQL WHERE clause
├── Severity__c (Picklist)
├── Alert_Message__c (Text)
├── Remediation_Steps__c (LongTextArea)
└── Created_By__c (Lookup: User)
```

**Example Custom Rules**:
```
Rule: "Detect Users with Both ViewAllData and Export Permission"
Target: User
Filter: Id IN (SELECT AssigneeId FROM PermissionSetAssignment 
               WHERE PermissionSet.PermissionsViewAllData = true)
        AND Id IN (SELECT AssigneeId FROM PermissionSetAssignment 
                   WHERE PermissionSet.PermissionsExportReport = true)
Severity: HIGH
Message: User {Name} can view all data AND export reports - high data exfiltration risk
```

---

## 📅 Release Timeline

```
2026
├── Q1 ────────────────────────────────────────────────────────────
│   ├── v2.0: Security Health Score
│   ├── v2.1: Compliance Templates (SOC2, GDPR)
│   ├── v2.2: PDF/Excel Export
│   └── v2.3: PermissionAuditEngine
│
├── Q2 ────────────────────────────────────────────────────────────
│   ├── v2.4: FlowAuditEngine
│   ├── v2.5: ApexSecurityEngine
│   ├── v2.6: Trend Analysis
│   └── v2.7: Basic Remediation Actions
│
├── Q3 ────────────────────────────────────────────────────────────
│   ├── v3.0: Event Monitoring (Login, API)
│   ├── v3.1: IntegrationSecurityEngine
│   ├── v3.2: Security Event Storage
│   └── v3.3: Basic Live Dashboard
│
└── Q4 ────────────────────────────────────────────────────────────
    ├── v3.4: Real-Time Alert System
    ├── v3.5: Advanced Live Dashboard
    ├── v3.6: Agentforce Integration
    └── v3.7: Scheduled Scans

2027
├── Q1-Q2 ─────────────────────────────────────────────────────────
│   ├── v4.0: Multi-Org Support
│   ├── v4.1: Custom Rule Engine
│   └── v4.2: Security Playbooks
│
└── Q3-Q4 ─────────────────────────────────────────────────────────
    ├── v5.0: ML Anomaly Detection
    ├── v5.1: Threat Intelligence
    └── v5.2: Advanced Visualizations
```

---

## 🏆 Competitive Differentiation

| Feature | Salesforce Shield | Security Center | FoxSec |
|---------|-------------------|-----------------|--------|
| **Pricing** | $$$$ | $$$ | $ |
| **Event Monitoring** | ✅ Native | ✅ Native | ✅ Phase 3 |
| **Health Score** | ❌ | ✅ | ✅ Phase 2 |
| **Multi-Org** | ❌ | ✅ | ✅ Phase 7 |
| **Real-Time Alerts** | ✅ | ❌ | ✅ Phase 5 |
| **Auto-Remediation** | ❌ | ❌ | ✅ Phase 6 |
| **Agentforce Ready** | ❌ | ❌ | ✅ Phase 6 |
| **Custom Rules** | ❌ | ❌ | ✅ Phase 7 |
| **Code Analysis** | ❌ | ❌ | ✅ Phase 4 |
| **Flow Analysis** | ❌ | ❌ | ✅ Phase 4 |
| **AppExchange** | N/A | N/A | ✅ |
| **Open Source** | ❌ | ❌ | ✅ |

---

## 🔐 AppExchange Security Review Considerations

Each phase must maintain compliance with Salesforce Security Review requirements:

| Requirement | Implementation |
|-------------|----------------|
| **No SOQL Injection** | All queries use bind variables |
| **CRUD/FLS Enforcement** | `WITH USER_MODE` or `Security.stripInaccessible` |
| **Sharing Rules** | All classes use `with sharing` or `inherited sharing` |
| **No Data Exfiltration** | No external callouts with org data |
| **No Hardcoded Credentials** | Named Credentials / Custom Metadata only |
| **Namespace Isolation** | All components namespaced (`foxsec__`) |

---

## 📚 Related Documentation

- [Architecture](./ARCHITECTURE.md) - Technical architecture details
- [Audit Modules](./AUDIT_MODULES.md) - Current audit tests documentation
- [API Reference](./API_REFERENCE.md) - Apex API documentation
- [Security Standards](./SECURITY_STANDARDS.md) - Coding standards
- [Contributing](./CONTRIBUTING.md) - How to contribute

---

*Last Updated: February 2026*  
*Version: 1.0*
