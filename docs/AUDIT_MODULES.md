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

## 🚧 Planned Modules (Roadmap)

### UserAuditEngine (v1.1)

| Planned Test | Description |
|--------------|-------------|
| Inactive Users | Users inactive for > 90 days |
| Users Without MFA | Users without multi-factor authentication |
| External Users Access | Community/Portal user access |
| Password Policy | Password policy verification |

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

*For technical details, see [API_REFERENCE.md](./API_REFERENCE.md).*
