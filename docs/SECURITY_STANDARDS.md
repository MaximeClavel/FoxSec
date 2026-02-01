# Security Standards - FoxSec

## 🛡️ Overview

This document defines the mandatory security standards for all FoxSec code. These rules ensure compliance with **AppExchange Security Review** requirements.

---

## AppExchange Compliance

### Security Review Checklist

| Requirement | Status | FoxSec Implementation |
|-------------|--------|----------------------|
| CRUD/FLS Enforcement | ✅ | `WITH USER_MODE` on all queries |
| Sharing Model | ✅ | `with sharing` mandatory |
| SOQL Injection Prevention | ✅ | Bind variables only |
| XSS Prevention | ✅ | `String.escapeSingleQuotes()` |
| Open Redirect Prevention | ✅ | No external redirects |
| Sensitive Data Exposure | ✅ | No sensitive data logging |

---

## 🔒 Apex Rules (Non-Negotiable)

### 1. Sharing Model

**Rule**: All Apex classes must explicitly declare their sharing mode.

```apex
// ✅ CORRECT
public with sharing class MyController { }
public inherited sharing class MyWrapper { }

// ❌ FORBIDDEN
public class MyController { }  // Implicit "without sharing"
```

**Exceptions**: None. Even inner classes must declare sharing.

### 2. SOQL - User Mode

**Rule**: All SOQL queries must use `WITH USER_MODE`.

```apex
// ✅ CORRECT
List<Account> accounts = [
    SELECT Id, Name
    FROM Account
    WHERE IsActive = true
    WITH USER_MODE
];

// ❌ FORBIDDEN
List<Account> accounts = [
    SELECT Id, Name
    FROM Account
    WHERE IsActive = true
];  // No USER_MODE = potential FLS bypass
```

### 3. SOQL Injection Prevention

**Rule**: ZERO tolerance for variable concatenation in SOQL.

```apex
// ✅ CORRECT - Bind variables
String searchTerm = '%' + String.escapeSingleQuotes(userInput) + '%';
List<Account> results = [
    SELECT Id, Name
    FROM Account
    WHERE Name LIKE :searchTerm
    WITH USER_MODE
];

// ❌ FORBIDDEN - Direct concatenation
String query = 'SELECT Id FROM Account WHERE Name = \'' + userInput + '\'';
List<Account> results = Database.query(query);  // SOQL INJECTION!
```

### 4. Dynamic SOQL (If Absolutely Necessary)

```apex
// ✅ CORRECT - With bind map
String baseQuery = 'SELECT Id, Name FROM Account WHERE Name LIKE :searchTerm';
Map<String, Object> binds = new Map<String, Object>{
    'searchTerm' => '%' + String.escapeSingleQuotes(input) + '%'
};
List<Account> results = Database.queryWithBinds(
    baseQuery, 
    binds, 
    AccessLevel.USER_MODE
);

// ❌ FORBIDDEN
String query = 'SELECT Id FROM Account WHERE Name = \'' + input + '\'';
Database.query(query);  // Injection possible
```

### 5. CRUD/FLS Verification

For DML operations, use `Security.stripInaccessible()`:

```apex
// ✅ CORRECT
List<Account> accountsToInsert = new List<Account>{ /* ... */ };

// Strip fields user cannot access
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.CREATABLE,
    accountsToInsert
);

insert decision.getRecords();

// Log stripped fields if needed
if (!decision.getRemovedFields().isEmpty()) {
    System.debug('Stripped fields: ' + decision.getRemovedFields());
}
```

### 6. XSS Protection

**Rule**: Escape all user values included in messages.

```apex
// ✅ CORRECT
String message = 'Error processing account: ' + 
                 String.escapeSingleQuotes(accountName);

// For HTML messages (in Visualforce)
String htmlMessage = 'Account: ' + accountName.escapeHtml4();
```

---

## 🖥️ LWC Rules

### 1. No innerHTML

```javascript
// ✅ CORRECT
this.template.querySelector('.container').textContent = userInput;

// ❌ FORBIDDEN - XSS possible
this.template.querySelector('.container').innerHTML = userInput;
```

### 2. No Unsafe Direct DOM Access

```javascript
// ✅ CORRECT - Use Lightning directives
// In HTML template:
// <lightning-formatted-text value={userValue}></lightning-formatted-text>

// ❌ FORBIDDEN
document.getElementById('myElement').innerHTML = this.userValue;
```

### 3. Use SLDS Only

```html
<!-- ✅ CORRECT -->
<div class="slds-box slds-theme_default">
    <lightning-card title="My Card">
        <!-- Content -->
    </lightning-card>
</div>

<!-- ❌ FORBIDDEN - Unvalidated custom CSS -->
<div style="background: url(javascript:alert('xss'))">
```

### 4. Validate Incoming Data

```javascript
// ✅ CORRECT
import { LightningElement, api } from 'lwc';

export default class MyComponent extends LightningElement {
    _recordId;
    
    @api
    get recordId() {
        return this._recordId;
    }
    
    set recordId(value) {
        // Validate before storing
        if (value && typeof value === 'string' && value.length === 18) {
            this._recordId = value;
        }
    }
}
```

---

## 📊 Logging Rules

### What Must NEVER Be Logged

| Data Type | Example | Reason |
|-----------|---------|--------|
| Passwords | `password`, `secret` | Credential exposure |
| Tokens | `accessToken`, `sessionId` | Session hijacking |
| PII | SSN, credit cards | GDPR/CCPA compliance |
| Medical data | PHI | HIPAA compliance |

### Secure Logging Pattern

```apex
// ✅ CORRECT
public class SecureLogger {
    public static void logAuditResult(FoxSecResult result) {
        // Log only non-sensitive fields
        System.debug(LoggingLevel.INFO, 
            'Audit: ' + result.testName + ' | Status: ' + result.status
        );
    }
    
    public static void logError(Exception e) {
        // Never log full stack if it might contain sensitive data
        System.debug(LoggingLevel.ERROR, 
            'Error type: ' + e.getTypeName() + ' | Line: ' + e.getLineNumber()
        );
    }
}
```

---

## 🚫 Forbidden Patterns

### 1. Callouts to Dynamic URLs

```apex
// ❌ FORBIDDEN - Data exfiltration possible
String endpoint = 'https://' + userProvidedDomain + '/api';
HttpRequest req = new HttpRequest();
req.setEndpoint(endpoint);
```

### 2. Storing Secrets in Plain Text

```apex
// ❌ FORBIDDEN
String apiKey = 'sk_live_abc123...';  // Hardcoded secret

// ✅ CORRECT - Use Custom Metadata or Named Credentials
String apiKey = [SELECT Value__c FROM API_Config__mdt WHERE DeveloperName = 'MyAPI'].Value__c;
// Or better: Named Credentials that handle auth automatically
```

### 3. Disabling Security Controls

```apex
// ❌ FORBIDDEN in FoxSec
public without sharing class BypassController { }  // Never allowed

// ❌ FORBIDDEN
Database.query(query);  // Without AccessLevel.USER_MODE
```

---

## ✅ Code Review Checklist

Before each PR, verify:

- [ ] All classes have `with sharing` or `inherited sharing`
- [ ] All SOQL queries have `WITH USER_MODE`
- [ ] No variable concatenation in SOQL (bind variables only)
- [ ] `String.escapeSingleQuotes()` used for values in messages
- [ ] No `innerHTML` in LWCs
- [ ] No sensitive data in logs
- [ ] No callouts to dynamically constructed URLs
- [ ] Unit tests covering permission error cases

---

## 🔍 Verification Tools

### PMD (Static Analysis)

```bash
# Scan Apex code
sf scanner:run --target force-app --format table --engine pmd
```

### Critical PMD Rules

| Rule | Description |
|------|-------------|
| `ApexCRUDViolation` | Detects CRUD/FLS violations |
| `ApexSOQLInjection` | Detects SOQL injections |
| `ApexXSSFromURLParam` | Detects XSS from URL |
| `ApexSharingViolations` | Detects missing sharing |

### ESLint for LWC

```bash
npm run lint
```

---

## 📚 Resources

- [Salesforce Security Guide](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/)
- [AppExchange Security Review](https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packagingGuide/security_review_overview.htm)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Apex Security Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_chapter.htm)

---

*This document is mandatory for all contributors. Non-compliance = PR rejected.*
