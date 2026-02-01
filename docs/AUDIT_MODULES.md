# Audit Modules - FoxSec

## 📋 Overview

FoxSec implements a series of security controls organized by thematic modules. Each module targets a specific aspect of Salesforce configuration.

---

## 🏗️ ConfigAuditEngine

**Category**: Infrastructure Security  
**Class**: `ConfigAuditEngine.cls`  
**Status**: ✅ Implemented (v1.0)

This engine audits the org's infrastructure configuration.

### Available Tests

---

### 1. Remote Site - Insecure HTTP Protocol

| Property | Value |
|----------|-------|
| **ID** | `TEST_REMOTE_SITE_HTTP` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Object** | `RemoteProxy` |

**Description**  
Detects Remote Site Settings using unsecured HTTP protocol instead of HTTPS.

**Risk**  
HTTP communications are in plain text and can be intercepted (Man-in-the-Middle). Sensitive data such as API tokens or user information can be exposed.

**Detection Criteria**
- URL starting with `http://`
- Active Remote Site (`IsActive = true`)

**Example Finding**
```json
{
    "testName": "Remote Site - Insecure HTTP Protocol",
    "status": "CRITICAL",
    "message": "Remote Site \"LegacyAPI\" uses insecure HTTP: http://api.oldservice.com",
    "remediationSteps": "Update URL to HTTPS. Setup > Security > Remote Site Settings > LegacyAPI"
}
```

**Remediation**
1. Go to Setup → Security → Remote Site Settings
2. Edit the affected Remote Site
3. Replace `http://` with `https://`
4. Ensure the target server supports HTTPS

---

### 2. Remote Site - Overly Permissive Wildcard

| Property | Value |
|----------|-------|
| **ID** | `TEST_REMOTE_SITE_WILDCARD` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `RemoteProxy` |

**Description**  
Detects Remote Site Settings using overly permissive wildcards on shared domains.

**Risk**  
Wildcards on shared cloud platforms (Heroku, AWS, Azure, etc.) enable SSRF (Server-Side Request Forgery) attacks. An attacker can create an application on the same platform and receive malicious callouts.

**Patterns Detected as Risky**
| Pattern | Reason |
|---------|--------|
| `*.herokuapp.com` | Shared platform |
| `*.cloudfront.net` | Shared CDN |
| `*.amazonaws.com` | Shared AWS |
| `*.azurewebsites.net` | Shared Azure |
| `*.ngrok.io` | Exposed dev tunnels |
| `*.com`, `*.net`, `*.org` | Entire TLD |

**Example Finding**
```json
{
    "testName": "Remote Site - Overly Permissive Wildcard",
    "status": "WARNING",
    "message": "Remote Site \"CloudIntegration\" uses overly permissive wildcard: *.herokuapp.com",
    "remediationSteps": "Restrict URL to a specific subdomain. Broad wildcards expose the org to SSRF attacks if the domain hosts third-party content."
}
```

**Remediation**
1. Identify the exact subdomain needed
2. Replace `*.herokuapp.com` with `myapp.herokuapp.com`
3. Test the integration with the specific URL

---

### 3. CSP Trusted Site - Unsafe Inline

| Property | Value |
|----------|-------|
| **ID** | `TEST_CSP_UNSAFE_INLINE` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `CspTrustedSite` |

**Description**  
Detects CSP configurations that could allow inline style injection.

**Risk**  
Inline CSS styles can be exploited for CSS injection attacks or data exfiltration via CSS.

**Detection Criteria**
- `IsApplicableToStyleSrc = true`
- URL containing wildcards or empty

**Remediation**
1. Go to Setup → Security → CSP Trusted Sites
2. Restrict `style-src` to specific domains
3. Avoid wildcards on style sources

---

### 4. CSP Trusted Site - Unsafe Eval / Risky Wildcards

| Property | Value |
|----------|-------|
| **ID** | `TEST_CSP_UNSAFE_EVAL` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `CspTrustedSite` |

**Description**  
Detects CSP configurations with risky wildcards on `frame-src` or `connect-src`.

**Risk**
- **frame-src**: Risk of clickjacking or XSS via iframe
- **connect-src**: Risk of data exfiltration to attacker-controlled endpoints

**Remediation**
1. Restrict sources to exact necessary URLs
2. Avoid wildcards on shared platforms

---

### 5. Certificates - Expiration Check

| Property | Value |
|----------|-------|
| **ID** | `TEST_CERTIFICATES` |
| **Max Severity** | 🔴 CRITICAL (expired) / ⚠️ WARNING (near expiration) |
| **Scanned Object** | `Certificate` |

**Description**  
Checks expiration status of certificates configured in the org.

**Risk**  
An expired certificate can disrupt SSO integrations, signed callouts, and mutual TLS authentication.

**Detection Criteria**
| Condition | Severity |
|-----------|----------|
| Certificate expired | CRITICAL |
| Expiration < 30 days | WARNING |
| Valid certificate | PASS |

**Technical Note**  
The `Certificate` object is not always accessible via standard SOQL. In this case, an `INFO` result is returned with instructions for manual verification.

**Remediation**
1. Setup → Security → Certificate and Key Management
2. Renew certificates before expiration
3. Update dependent integrations

---

### 6. Admin Login As Any User

| Property | Value |
|----------|-------|
| **ID** | `TEST_LOGIN_AS_ANY_USER` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `Organization`, `LoginHistory` |

**Description**  
Checks if the "Administrators Can Log in as Any User" feature is potentially enabled.

**Risk**  
This feature allows admins to log in as any user without their consent. In production, this poses risks:
- Privacy violation
- GDPR/SOX non-compliance
- Lack of action traceability

**Technical Note**  
The exact setting is not accessible via SOQL. The audit detects the org type (Production vs Sandbox) and provides appropriate recommendations.

**Remediation (Production)**
1. Setup → Security → Login Access Policies
2. Uncheck "Administrators Can Log in as Any User"
3. Use Grant Login Access on-demand

---

### 7. Session Security - Force Logout on Timeout

| Property | Value |
|----------|-------|
| **ID** | `TEST_SESSION_FORCE_LOGOUT` |
| **Max Severity** | ℹ️ INFO |
| **Scanned Object** | `AuthSession`, `Organization` |

**Description**  
Checks session security settings, particularly forced logout on timeout.

**Risk**  
Without forced logout, an abandoned session can be reused by an attacker with browser access.

**Additional Controls**
- Detection of sessions with LOW/STANDARD security level
- Org language verification (to ensure security messages are understood)

**Remediation**
1. Setup → Session Settings
2. Enable "Force logout on session timeout"
3. Configure appropriate timeout (max 2 hours recommended)
4. Configure Session Security Levels for sensitive operations

---

## � UserAuditEngine

**Category**: Identity & Access Management  
**Class**: `UserAuditEngine.cls`  
**Status**: ✅ Implemented (v1.1)

This engine audits user access, privileges, and IAM-related security risks.

### Available Tests

---

### 1. Shadow Admins - Excessive Privileges

| Property | Value |
|----------|-------|
| **ID** | `TEST_SHADOW_ADMINS` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Objects** | `User`, `Profile`, `PermissionSet`, `PermissionSetAssignment` |

**Description**  
Detects "Shadow Admins" - users who are NOT System Administrators but have critical system permissions that grant admin-level access.

**Risk**  
Shadow admins can:
- Deploy Apex code (backdoors)
- Modify org configuration
- Access all data regardless of sharing rules
- Create/modify user accounts

**Critical Permissions Detected**
| Permission | Risk Level |
|------------|------------|
| `AuthorApex` | Can deploy malicious code |
| `CustomizeApplication` | Can modify org setup |
| `ManageUsers` | Can create/modify users |
| `ViewAllData` | Bypass all data sharing |
| `ModifyAllData` | Full data access |

**Detection Logic**
1. Query Profiles (non-admin) with critical permissions
2. Query PermissionSets with critical permissions
3. Find active users assigned to these Profiles/PermissionSets
4. Report each user with the source of their privileges

**Example Finding**
```json
{
    "testName": "Shadow Admins - Excessive Privileges",
    "status": "CRITICAL",
    "message": "Shadow Admin detected: \"john.doe@company.com\" (Profile: Sales User) has critical permissions via: PermissionSet: Sales Admin Override",
    "remediationSteps": "Review and remove unnecessary privileges. Setup > Users > John Doe > Permission Set Assignments"
}
```

**Remediation**
1. Setup → Users → [Affected User] → Permission Set Assignments
2. Remove permission sets granting critical permissions
3. Apply Principle of Least Privilege
4. Use dedicated admin accounts for admin tasks

---

### 2. API Users - Stale Accounts

| Property | Value |
|----------|-------|
| **ID** | `TEST_STALE_API_USERS` |
| **Max Severity** | 🔴 CRITICAL (never logged in) / ⚠️ WARNING (stale) |
| **Scanned Objects** | `User`, `Profile`, `PermissionSet`, `PermissionSetAssignment` |

**Description**  
Identifies users with API access (via Profile or PermissionSet) who haven't logged in for more than 90 days.

**Risk**  
Stale API accounts are security risks:
- Credentials may be compromised without detection
- No active monitoring of account activity
- Potential entry point for attackers

**Detection Criteria**
| Condition | Severity |
|-----------|----------|
| API-enabled, never logged in | CRITICAL |
| API-enabled, no login > 90 days | WARNING |
| API-enabled, active | PASS |

**Threshold**: 90 days (configurable via `STALE_DAYS_THRESHOLD`)

**Example Finding**
```json
{
    "testName": "API Users - Stale Accounts",
    "status": "WARNING",
    "message": "Stale API user: \"integration.user@company.com\" - Last login: 2025-10-15 (108 days ago)",
    "remediationSteps": "Review API user necessity. Deactivate or rotate credentials if unused."
}
```

**Remediation**
1. Review the business need for each stale API account
2. Deactivate unused accounts
3. Rotate credentials for active accounts
4. Implement regular access reviews (quarterly)

---

### 3. Password Policy - Never Expires

| Property | Value |
|----------|-------|
| **ID** | `TEST_WEAK_PASSWORD` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Objects** | `User`, `Profile` |

**Description**  
Identifies potential service/integration accounts that may have non-expiring passwords configured.

**Risk**  
Non-expiring passwords:
- Increase credential compromise exposure window
- Often paired with weak passwords
- Non-compliant with security standards (SOC2, ISO27001)

**Detection Logic**
- Identifies accounts with usernames containing: `integration`, `api`, `service`, `system`
- Detects `AutomatedProcess` user types
- Provides guidance for org-level password policy review

**Example Finding**
```json
{
    "testName": "Password Policy - Never Expires",
    "status": "WARNING",
    "message": "Found 3 potential integration/service accounts. These often have non-expiring passwords configured.",
    "remediationSteps": "Review password policies for service accounts. Consider using OAuth instead of passwords."
}
```

**Remediation**
1. Setup → Security → Password Policies
2. Set "User passwords expire in" to 90 days or less
3. For integrations: migrate to OAuth 2.0 / JWT instead of passwords
4. Implement credential rotation procedures

---

### 4. Guest User - Excessive Permissions

| Property | Value |
|----------|-------|
| **ID** | `TEST_GUEST_USER_EXPOSURE` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Objects** | `User`, `ObjectPermissions`, `PermissionSet`, `PermissionSetAssignment` |

**Description**  
Identifies Guest users (Site/Community public users) with write permissions on objects.

**Risk**  
Guest users with write access can:
- Create spam/malicious records
- Modify or delete data
- Exploit data model for injection attacks
- **AppExchange Security Review BLOCKER**

**Detection Criteria**
| Condition | Severity |
|-----------|----------|
| Guest with Create/Edit/Delete on any object (via Profile) | CRITICAL |
| Guest with Create/Edit/Delete on any object (via PermissionSet) | CRITICAL |
| Guest with PermissionSet assigned (no write perms) | WARNING |
| Guest with read-only access | PASS |

**Objects Checked**
- Profile-level ObjectPermissions
- PermissionSet-assigned ObjectPermissions
- Any object with `PermissionsCreate`, `PermissionsEdit`, or `PermissionsDelete` = true

**Example Finding**
```json
{
    "testName": "Guest User - Excessive Permissions",
    "status": "CRITICAL",
    "message": "Guest user has write access on object \"Lead\": Create, Edit (via Profile)",
    "remediationSteps": "Remove write permissions from Guest user profile. Guest users should have minimal read-only access."
}
```

**Remediation**
1. Setup → Sites → [Your Site] → Public Access Settings
2. Remove Create/Edit/Delete permissions from all objects
3. Only allow Read on strictly necessary objects
4. Review all PermissionSets assigned to Guest users
5. Consider using authenticated Experience Cloud instead of public access

---

## 🚧 Planned Modules (Roadmap)

### PermissionAuditEngine (v1.2)

| Planned Test | Description |
|--------------|-------------|
| Modify All Data | Profiles/PermSets with "Modify All Data" |
| View All Data | Profiles/PermSets with "View All Data" |
| Author Apex | Users who can create Apex code |
| API Enabled | API access overexposure |

### FlowAuditEngine (v1.3)

| Planned Test | Description |
|--------------|-------------|
| Flows Without Error Handling | Flows without error handling |
| Flows with DML in Loops | Performance issues |
| Scheduled Flows Review | Scheduled flows to audit |

### ApexAuditEngine (v2.0)

| Planned Test | Description |
|--------------|-------------|
| Without Sharing Classes | Classes without explicit sharing |
| SOQL Without User Mode | Queries without USER_MODE |
| Hardcoded IDs | Hardcoded IDs in code |

---

## 📊 Severity Matrix

| Severity | Meaning | Recommended SLA |
|----------|---------|-----------------|
| 🔴 **CRITICAL** | Immediately exploitable vulnerability | Fix < 24h |
| ⚠️ **WARNING** | Potential risk, conditions required | Fix < 1 week |
| ℹ️ **INFO** | Security information, manual verification | Schedule review |
| ✅ **PASS** | No issues detected | No action |
| ⏭️ **SKIPPED** | Audit not executable | Check permissions |

---

## 🔧 Extending Modules

To add a new test to an existing module:

```apex
// In ConfigAuditEngine.cls

// 1. Add test constant
@TestVisible 
private static final String TEST_NEW_CHECK = 'New Security Check';

// 2. Create audit method
@TestVisible
private List<FoxSecResult> auditNewFeature() {
    List<FoxSecResult> results = new List<FoxSecResult>();
    
    try {
        // Audit logic with WITH USER_MODE
        // ...
        
        if (issueFound) {
            results.add(new FoxSecResult(
                TEST_NEW_CHECK,
                FoxSecResult.STATUS_WARNING,
                'Issue description',
                'Remediation steps'
            ));
        } else {
            results.add(new FoxSecResult(
                TEST_NEW_CHECK,
                FoxSecResult.STATUS_PASS,
                'No issues found.',
                null
            ));
        }
        
    } catch (Exception e) {
        results.add(createSkippedResult(
            TEST_NEW_CHECK,
            'Error: ' + e.getMessage()
        ));
    }
    
    return results;
}

// 3. Call in executeAudit()
public List<FoxSecResult> executeAudit() {
    List<FoxSecResult> results = new List<FoxSecResult>();
    // ... existing audits ...
    results.addAll(auditNewFeature());  // Add here
    return results;
}
```

---

## 🔐 SharingAuditEngine

**Category**: Data Sharing Security  
**Class**: `SharingAuditEngine.cls`  
**Status**: ✅ Implemented (v1.0)

This engine audits data sharing configurations that could expose sensitive data.

### Available Tests

---

### 1. OWD - Account Default Access

| Property | Value |
|----------|-------|
| **ID** | `TEST_OWD_ACCOUNT` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Object** | `Organization` |

**Description**  
Detects if Account Organization-Wide Default (OWD) is set to "Public Read/Write".

**Risk**  
When OWD is "Public Read/Write" (ReadWrite), ALL users can view AND edit ALL Account records. No hierarchy-based protection exists.

**Detection Criteria**
- `DefaultAccountAccess = 'ReadWrite'` or `'Edit'` or `'ReadWriteTransfer'`

**Example Finding**
```json
{
    "testName": "OWD - Account Default Access",
    "status": "CRITICAL",
    "message": "Account OWD is set to \"ReadWrite\" (Public Read/Write). All users can view AND edit all Account records.",
    "remediationSteps": "Setup > Security > Sharing Settings > Account > Change to \"Private\" or \"Public Read Only\". Use sharing rules for controlled access."
}
```

**Remediation**
1. Go to Setup → Security → Sharing Settings
2. Edit Organization-Wide Defaults
3. Change Account to "Private" or "Public Read Only"
4. Create Sharing Rules for necessary access

---

### 2. OWD - Contact Default Access

| Property | Value |
|----------|-------|
| **ID** | `TEST_OWD_CONTACT` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Object** | `Organization` |

**Description**  
Detects if Contact Organization-Wide Default is set to "Public Read/Write".

**Risk**  
Contact records often contain PII (Personally Identifiable Information). Public Read/Write exposes all contact data to all users.

**Remediation**
1. Setup → Security → Sharing Settings
2. Set Contact OWD to "Controlled by Parent" or "Private"
3. Implement need-to-know access via sharing rules

---

### 3. OWD - Case Default Access

| Property | Value |
|----------|-------|
| **ID** | `TEST_OWD_CASE` |
| **Max Severity** | 🔴 CRITICAL |
| **Scanned Object** | `Organization` |

**Description**  
Detects if Case Organization-Wide Default is set to "Public Read/Write".

**Risk**  
Case records may contain:
- Customer complaints
- Support history
- Internal notes
- Sensitive issue details

Public Read/Write exposes all this information to all users.

**Remediation**
1. Setup → Security → Sharing Settings
2. Set Case OWD to "Private"
3. Use case assignment rules and sharing rules for controlled access

---

### 4. External Sharing Model Configuration

| Property | Value |
|----------|-------|
| **ID** | `TEST_EXTERNAL_SHARING` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `Organization` |

**Description**  
Detects when External Sharing Model matches Internal Sharing (potential misconfiguration).

**Risk**  
When external sharing equals internal sharing, external users (Partners, Communities) have the same data access as internal users. This is often unintended and violates data segregation principles.

**Detection Criteria**
- External access level equals internal access level
- External access is not "Private" (both Private is acceptable)

**Example Finding**
```json
{
    "testName": "External Sharing Model Configuration",
    "status": "WARNING",
    "message": "Account: External sharing (\"Read\") matches internal sharing. External users have same access as internal users.",
    "remediationSteps": "Review Setup > Security > Sharing Settings. External users should typically have more restrictive access than internal users."
}
```

**Remediation**
1. Setup → Security → Sharing Settings
2. Enable separate External Sharing Model if not enabled
3. Set more restrictive access for external users
4. Review Community/Partner user access requirements

---

### 5. Content Asset - Public File Exposure

| Property | Value |
|----------|-------|
| **ID** | `TEST_PUBLIC_FILES` |
| **Max Severity** | ⚠️ WARNING |
| **Scanned Object** | `ContentDistribution` |

**Description**  
Detects publicly shared files (Content Deliveries) that lack password protection.

**Risk**  
Files shared via Content Delivery without password protection can be accessed by anyone with the URL. This creates risk of:
- Data leakage
- Unauthorized document access
- Compliance violations (GDPR, HIPAA)

**Detection Criteria**
- `ContentDistribution` records where `IsPasswordProtected = false`
- Expired distribution links still in system

**Example Finding**
```json
{
    "testName": "Content Asset - Public File Exposure",
    "status": "WARNING",
    "message": "15 of 42 public file links are not password protected. Anyone with the URL can download.",
    "remediationSteps": "Review Content Deliveries in Setup. Enable password protection or set expiration dates for sensitive files. Consider using authenticated sharing instead."
}
```

**Remediation**
1. Setup → Content Deliveries
2. Review all active distributions
3. Enable password protection for sensitive files
4. Set appropriate expiration dates
5. Delete obsolete distributions
6. Consider using authenticated sharing (Lightning File Download) instead

---

### Technical Notes

**Mocking Organization Data**  
The `Organization` object is read-only in Salesforce. The engine uses `@TestVisible` mock data pattern:

```apex
// In test class
SharingAuditEngine.mockOrgSettings = new SharingAuditEngine.OrgSharingSettings();
mockOrgSettings.defaultAccountAccess = 'ReadWrite';
// ... run tests ...
```

**OWD Value Reference**
| API Value | Display Name | Risk |
|-----------|--------------|------|
| `Private` | Private | ✅ Safe |
| `Read` | Public Read Only | ✅ Safe |
| `ReadWrite` | Public Read/Write | 🔴 Critical |
| `Edit` | Public Read/Write | 🔴 Critical |
| `ReadWriteTransfer` | Public Read/Write/Transfer | 🔴 Critical |
| `ControlledByParent` | Controlled by Parent | ✅ Safe |
| `ControlledByCampaign` | Controlled by Campaign | ✅ Safe |

---

*For technical details, see [API_REFERENCE.md](./API_REFERENCE.md).*
