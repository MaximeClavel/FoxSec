# Contributing Guide - FoxSec

## 🤝 Welcome

Thank you for contributing to FoxSec! This guide defines the standards and processes for contributions.

---

## Prerequisites

### Development Environment

1. **VS Code** with extensions:
   - Salesforce Extension Pack
   - ESLint
   - Prettier
   - Apex PMD

2. **Salesforce CLI** v2.x+

3. **Node.js** 18.x+ and npm

### Initial Setup

```bash
# Clone the repo
git clone https://github.com/your-org/foxsec.git
cd foxsec

# Install dependencies
npm install

# Configure Git hooks
npm run postinstall
```

---

## 🌿 Git Workflow

### Branches

| Branch | Usage |
|--------|-------|
| `main` | Stable production |
| `develop` | Integration |
| `feature/*` | New features |
| `bugfix/*` | Bug fixes |
| `hotfix/*` | Urgent production fixes |

### Contribution Process

1. **Create a branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/feature-name
   ```

2. **Develop** following the standards (see below)

3. **Commit** with conventional messages:
   ```bash
   git commit -m "feat(audit): add MFA verification check"
   git commit -m "fix(controller): handle null results gracefully"
   git commit -m "docs: update API reference"
   ```

4. **Push** and create a Pull Request:
   ```bash
   git push origin feature/feature-name
   ```

### Commit Message Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting (no logic changes) |
| `refactor` | Refactoring |
| `test` | Adding/modifying tests |
| `chore` | Maintenance (CI, build, etc.) |

---

## 📝 Code Standards

### Apex

#### Mandatory Rules

1. **Sharing Model**: Always declare `with sharing` or `inherited sharing`
   ```apex
   public with sharing class MyController { }
   ```

2. **SOQL User Mode**: Always use `WITH USER_MODE`
   ```apex
   List<Account> accs = [SELECT Id FROM Account WITH USER_MODE];
   ```

3. **Bind Variables**: Never use SOQL concatenation
   ```apex
   // ✅ Correct
   String name = searchTerm;
   List<Account> accs = [SELECT Id FROM Account WHERE Name = :name WITH USER_MODE];
   
   // ❌ Forbidden
   String query = 'SELECT Id FROM Account WHERE Name = \'' + searchTerm + '\'';
   ```

4. **ApexDoc**: Document all public methods
   ```apex
   /**
    * @description Executes the security audit
    * @param auditType Type of audit to run
    * @return List of audit results
    */
   public List<FoxSecResult> runAudit(String auditType) { }
   ```

#### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes | PascalCase | `ConfigAuditEngine` |
| Methods | camelCase | `executeAudit()` |
| Variables | camelCase | `remoteSites` |
| Constants | SCREAMING_SNAKE | `STATUS_CRITICAL` |
| Tests | ClassNameTest | `ConfigAuditEngineTest` |

### LWC

1. **Use SLDS** exclusively
2. **No innerHTML**
3. **Validate inputs** in `@api` setters
4. **Document** with JSDoc

```javascript
/**
 * Dashboard component for FoxSec audit results
 * @fires auditcomplete - Fired when audit completes
 */
export default class FoxSecDashboard extends LightningElement {
    /**
     * Record ID to audit
     * @type {string}
     */
    @api recordId;
}
```

---

## 🧪 Tests

### Requirements

| Metric | Minimum | Recommended |
|--------|---------|-------------|
| Apex Coverage | 75% | 90%+ |
| LWC Coverage | 80% | 90%+ |

### Apex Test Structure

```apex
@IsTest
private class ConfigAuditEngineTest {
    
    @TestSetup
    static void setup() {
        // Create test data
    }
    
    @IsTest
    static void testExecuteAudit_WithValidData_ReturnsResults() {
        // Arrange
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // Act
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Assert
        Assert.isNotNull(results, 'Results should not be null');
        Assert.isFalse(results.isEmpty(), 'Results should not be empty');
    }
    
    @IsTest
    static void testExecuteAudit_WithNoAccess_ReturnsSkipped() {
        // Test with user without permissions
    }
}
```

### Test Naming

```
test<Method>_<Scenario>_<ExpectedResult>
```

Examples:
- `testExecuteAudit_WithValidData_ReturnsResults`
- `testDetectRiskyWildcard_WithHerokuDomain_ReturnsPattern`
- `testRunAllAudits_WithNoPermissions_ReturnsSkipped`

### Execution

```bash
# All tests
sf apex run test --test-level RunLocalTests --code-coverage

# Specific test
sf apex run test --tests ConfigAuditEngineTest

# LWC tests
npm run test:unit
```

---

## 📋 Pull Request Checklist

Before submitting a PR, verify:

### Code Quality
- [ ] Code follows Apex/LWC standards
- [ ] No `without sharing` or SOQL without `USER_MODE`
- [ ] No SOQL concatenation
- [ ] Complete ApexDoc/JSDoc

### Tests
- [ ] Unit tests added/updated
- [ ] Coverage ≥ 75%
- [ ] All tests pass locally

### Documentation
- [ ] README updated if necessary
- [ ] CHANGELOG updated
- [ ] API documentation updated

### Security
- [ ] No hardcoded sensitive data
- [ ] No sensitive data logging
- [ ] Required permissions reviewed

---

## 🔍 Review Process

### Acceptance Criteria

1. **CI Build**: All checks pass
2. **Code Review**: Approval from at least 1 reviewer
3. **Tests**: Coverage maintained or improved
4. **Documentation**: Up to date with changes

### Reviewers

- **Apex Code**: @apex-reviewer
- **LWC**: @lwc-reviewer
- **Security**: @security-reviewer
- **Documentation**: @docs-reviewer

---

## 🐛 Bug Reporting

### Issue Template

```markdown
## Description
[Clear description of the bug]

## Steps to Reproduce
1. Step 1
2. Step 2
3. ...

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- Org Type: [Scratch/DE/Sandbox]
- API Version: [e.g., 65.0]
- Browser: [if UI]

## Screenshots/Logs
[If applicable]
```

---

## 💡 Proposing a Feature

### Feature Request Template

```markdown
## Problem Statement
[What problem does this feature solve?]

## Proposed Solution
[Description of the proposed solution]

## Alternatives Considered
[Other solutions considered]

## Security Considerations
[Impact on app security]

## Implementation Notes
[Technical notes if applicable]
```

---

## 📞 Contact

- **GitHub Issues**: For bugs and features
- **Discussions**: For general questions
- **Email**: foxsec.salesforce@proton.me (vulnerabilities only)

---

## 📜 Code of Conduct

By contributing, you agree to:

1. Be respectful and inclusive
2. Accept constructive feedback
3. Prioritize security and quality
4. Document your changes

---

*Thank you for contributing to making Salesforce more secure!* 🦊🔐
