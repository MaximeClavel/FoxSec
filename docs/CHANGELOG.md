# Changelog - FoxSec

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- UserAuditEngine: User audit (MFA, inactivity)
- PermissionAuditEngine: Sensitive permissions audit
- LWC Dashboard: Complete user interface
- Remediation Flow: Automated corrective actions

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
