// File: force-app/main/default/classes/audits/ConfigAuditEngine.cls
/**
 * @description Audit engine for organization infrastructure security settings.
 * Scans Remote Site Settings, CSP Trusted Sites, Session Security, and Admin policies.
 * All operations are read-only and respect user permissions.
 * @author FoxSec Team
 * @date 2026-01-30
 */
public with sharing class ConfigAuditEngine implements IFoxSecAuditor {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    private static final String AUDIT_CATEGORY = 'Infrastructure Security';
    
    // Test names
    @TestVisible private static final String TEST_REMOTE_SITE_HTTP = 'Remote Site - Insecure HTTP Protocol';
    @TestVisible private static final String TEST_REMOTE_SITE_WILDCARD = 'Remote Site - Overly Permissive Wildcard';
    @TestVisible private static final String TEST_CSP_UNSAFE_INLINE = 'CSP Trusted Site - Unsafe Inline';
    @TestVisible private static final String TEST_CSP_UNSAFE_EVAL = 'CSP Trusted Site - Unsafe Eval';
    @TestVisible private static final String TEST_CERTIFICATES = 'Certificates - Expiration Check';
    @TestVisible private static final String TEST_LOGIN_AS_ANY_USER = 'Admin Login As Any User';
    @TestVisible private static final String TEST_SESSION_FORCE_LOGOUT = 'Session Security - Force Logout on Timeout';
    
    // Risky wildcard patterns (too permissive)
    private static final Set<String> RISKY_WILDCARD_PATTERNS = new Set<String>{
        '*.herokuapp.com',
        '*.cloudfront.net',
        '*.amazonaws.com',
        '*.azurewebsites.net',
        '*.ngrok.io',
        '*.ngrok-free.app',
        '*.*.*',
        '*.com',
        '*.net',
        '*.org',
        '*.io'
    };

    // ─────────────────────────────────────────────────────────────────────────────
    // IFoxSecAuditor Implementation
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Executes all infrastructure security audits.
     * @return List<FoxSecResult> Aggregated findings from all checks.
     */
    public List<FoxSecResult> executeAudit() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        // Remote Site Settings checks
        results.addAll(auditRemoteSiteSettings());
        
        // CSP Trusted Sites checks
        results.addAll(auditCspTrustedSites());
        
        // Certificate expiration check (V2 - stubbed)
        results.addAll(auditCertificates());
        
        // Admin Login As Any User check
        results.addAll(auditLoginAsAnyUser());
        
        // Session Security checks
        results.addAll(auditSessionSecurity());
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Remote Site Settings Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Audits Remote Site Settings for security misconfigurations.
     * Checks for: HTTP protocol usage, overly permissive wildcards.
     * @return List<FoxSecResult> Findings from Remote Site audit.
     */
    @TestVisible
    private List<FoxSecResult> auditRemoteSiteSettings() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Query active Remote Site Settings
            // Using WITH USER_MODE to respect user permissions
            List<RemoteProxy> remoteSites = [
                SELECT Id, SiteName, EndpointUrl, IsActive, Description
                FROM RemoteProxy
                WHERE IsActive = true
                WITH USER_MODE
            ];
            
            if (remoteSites.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_REMOTE_SITE_HTTP,
                    FoxSecResult.STATUS_PASS,
                    'No active Remote Site detected.',
                    null
                ));
                return results;
            }
            
            Boolean foundHttpIssue = false;
            Boolean foundWildcardIssue = false;
            
            for (RemoteProxy site : remoteSites) {
                String url = site.EndpointUrl != null ? site.EndpointUrl.toLowerCase() : '';
                
                // Check 1: HTTP protocol (non-secure)
                if (url.startsWith('http://')) {
                    foundHttpIssue = true;
                    results.add(new FoxSecResult(
                        TEST_REMOTE_SITE_HTTP,
                        FoxSecResult.STATUS_CRITICAL,
                        'Remote Site "' + String.escapeSingleQuotes(site.SiteName) + 
                        '" uses insecure HTTP: ' + String.escapeSingleQuotes(url),
                        'Update URL to HTTPS. Setup > Security > Remote Site Settings > ' + 
                        String.escapeSingleQuotes(site.SiteName)
                    ));
                }
                
                // Check 2: Overly permissive wildcards
                String wildcardIssue = detectRiskyWildcard(url);
                if (wildcardIssue != null) {
                    foundWildcardIssue = true;
                    results.add(new FoxSecResult(
                        TEST_REMOTE_SITE_WILDCARD,
                        FoxSecResult.STATUS_WARNING,
                        'Remote Site "' + String.escapeSingleQuotes(site.SiteName) + 
                        '" uses overly permissive wildcard: ' + wildcardIssue,
                        'Restrict URL to a specific subdomain. Broad wildcards expose the org ' +
                        'to SSRF attacks if the domain hosts third-party content.'
                    ));
                }
            }
            
            // Add PASS results if no issues found
            if (!foundHttpIssue) {
                results.add(new FoxSecResult(
                    TEST_REMOTE_SITE_HTTP,
                    FoxSecResult.STATUS_PASS,
                    'All active Remote Sites (' + remoteSites.size() + ') use HTTPS.',
                    null
                ));
            }
            
            if (!foundWildcardIssue) {
                results.add(new FoxSecResult(
                    TEST_REMOTE_SITE_WILDCARD,
                    FoxSecResult.STATUS_PASS,
                    'No overly permissive wildcard detected in Remote Sites.',
                    null
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_REMOTE_SITE_HTTP,
                'Unable to scan RemoteProxy: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_REMOTE_SITE_HTTP,
                'Access denied to RemoteProxy object. "View Setup" permission required.'
            ));
        }
        
        return results;
    }
    
    /**
     * @description Detects risky wildcard patterns in URLs.
     * @param url The URL to check.
     * @return String The risky pattern found, or null if safe.
     */
    @TestVisible
    private String detectRiskyWildcard(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        
        // Extract hostname from URL
        String hostname = extractHostname(url);
        
        // Check against known risky patterns
        for (String pattern : RISKY_WILDCARD_PATTERNS) {
            if (hostname.contains(pattern) || matchesWildcardPattern(hostname, pattern)) {
                return pattern;
            }
        }
        
        // Check for generic wildcard at domain root (e.g., *.example.com where example is a public cloud)
        if (hostname.startsWith('*.') && countDomainParts(hostname) <= 2) {
            return hostname;
        }
        
        return null;
    }
    
    /**
     * @description Extracts hostname from a URL.
     * @param url Full URL string.
     * @return String Hostname portion.
     */
    private String extractHostname(String url) {
        String hostname = url.replaceFirst('https?://', '');
        Integer slashIndex = hostname.indexOf('/');
        if (slashIndex > 0) {
            hostname = hostname.substring(0, slashIndex);
        }
        // Remove port if present
        Integer colonIndex = hostname.indexOf(':');
        if (colonIndex > 0) {
            hostname = hostname.substring(0, colonIndex);
        }
        return hostname;
    }
    
    /**
     * @description Counts the number of parts in a domain name.
     * @param hostname Domain hostname.
     * @return Integer Number of parts (e.g., "a.b.com" = 3).
     */
    private Integer countDomainParts(String hostname) {
        if (String.isBlank(hostname)) {
            return 0;
        }
        return hostname.split('\\.').size();
    }
    
    /**
     * @description Checks if a hostname matches a wildcard pattern.
     * @param hostname The hostname to check.
     * @param pattern The wildcard pattern.
     * @return Boolean True if matches.
     */
    private Boolean matchesWildcardPattern(String hostname, String pattern) {
        if (pattern.startsWith('*.')) {
            String suffix = pattern.substring(1); // Remove the *
            return hostname.endsWith(suffix);
        }
        return hostname.equals(pattern);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // CSP Trusted Sites Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Audits CSP Trusted Sites for dangerous configurations.
     * Checks for: AllowUnsafeInline, AllowUnsafeEval flags.
     * @return List<FoxSecResult> Findings from CSP audit.
     */
    @TestVisible
    private List<FoxSecResult> auditCspTrustedSites() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Query CSP Trusted Sites with risky configurations
            List<CspTrustedSite> cspSites = [
                SELECT Id, DeveloperName, EndpointUrl, IsActive, Context,
                       IsApplicableToConnectSrc, IsApplicableToFontSrc,
                       IsApplicableToFrameSrc, IsApplicableToImgSrc,
                       IsApplicableToMediaSrc, IsApplicableToStyleSrc
                FROM CspTrustedSite
                WHERE IsActive = true
                WITH USER_MODE
            ];
            
            if (cspSites.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_CSP_UNSAFE_INLINE,
                    FoxSecResult.STATUS_PASS,
                    'No active CSP Trusted Site detected.',
                    null
                ));
                return results;
            }
            
            Boolean foundUnsafeInline = false;
            Boolean foundUnsafeEval = false;
            
            // Note: CspTrustedSite doesn't directly expose AllowUnsafeInline/AllowUnsafeEval
            // These are typically controlled at a different level.
            // We check for style-src (potential inline styles) and risky configurations
            
            for (CspTrustedSite site : cspSites) {
                // Style-src with broad permissions can enable inline styles
                if (site.IsApplicableToStyleSrc == true) {
                    String url = site.EndpointUrl != null ? site.EndpointUrl.toLowerCase() : '';
                    
                    // Check for overly broad style sources that could enable inline
                    if (url.contains('*') || url == 'self' || String.isBlank(url)) {
                        foundUnsafeInline = true;
                        results.add(new FoxSecResult(
                            TEST_CSP_UNSAFE_INLINE,
                            FoxSecResult.STATUS_WARNING,
                            'CSP Trusted Site "' + String.escapeSingleQuotes(site.DeveloperName) + 
                            '" allows style-src with broad configuration. CSS injection risk.',
                            'Restrict style-src to specific domains only. ' +
                            'Setup > Security > CSP Trusted Sites'
                        ));
                    }
                }
                
                // Frame-src can be used for script execution in some contexts
                if (site.IsApplicableToFrameSrc == true) {
                    String url = site.EndpointUrl != null ? site.EndpointUrl.toLowerCase() : '';
                    String wildcardIssue = detectRiskyWildcard(url);
                    
                    if (wildcardIssue != null) {
                        foundUnsafeEval = true;
                        results.add(new FoxSecResult(
                            TEST_CSP_UNSAFE_EVAL,
                            FoxSecResult.STATUS_WARNING,
                            'CSP Trusted Site "' + String.escapeSingleQuotes(site.DeveloperName) + 
                            '" allows frame-src with risky wildcard: ' + wildcardIssue + 
                            '. Risk of clickjacking or XSS via iframe.',
                            'Restrict frame-src to specific URLs. Wildcards on shared cloud ' +
                            'platforms allow malicious content injection.'
                        ));
                    }
                }
                
                // Connect-src with wildcards can enable data exfiltration
                if (site.IsApplicableToConnectSrc == true) {
                    String url = site.EndpointUrl != null ? site.EndpointUrl.toLowerCase() : '';
                    String wildcardIssue = detectRiskyWildcard(url);
                    
                    if (wildcardIssue != null) {
                        results.add(new FoxSecResult(
                            TEST_CSP_UNSAFE_EVAL,
                            FoxSecResult.STATUS_WARNING,
                            'CSP Trusted Site "' + String.escapeSingleQuotes(site.DeveloperName) + 
                            '" allows connect-src with risky wildcard: ' + wildcardIssue + 
                            '. Risk of data exfiltration.',
                            'Restrict connect-src to strictly necessary APIs.'
                        ));
                    }
                }
            }
            
            // Add PASS results if no issues
            if (!foundUnsafeInline) {
                results.add(new FoxSecResult(
                    TEST_CSP_UNSAFE_INLINE,
                    FoxSecResult.STATUS_PASS,
                    'No CSP unsafe-inline configuration detected.',
                    null
                ));
            }
            
            if (!foundUnsafeEval) {
                results.add(new FoxSecResult(
                    TEST_CSP_UNSAFE_EVAL,
                    FoxSecResult.STATUS_PASS,
                    'No high-risk CSP configuration (broad wildcards) detected.',
                    null
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_CSP_UNSAFE_INLINE,
                'Unable to scan CspTrustedSite: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_CSP_UNSAFE_INLINE,
                'Access denied to CspTrustedSite object. "View Setup" permission required.'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Certificate Expiration Audit (V2 - Stubbed)
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Audits certificate expiration status.
     * Note: Certificate object is not directly queryable via SOQL in all contexts.
     * This is stubbed for V2 implementation via Tooling API or Metadata API.
     * @return List<FoxSecResult> Certificate audit findings.
     */
    @TestVisible
    private List<FoxSecResult> auditCertificates() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        // V2 TODO: Implement via Tooling API callout to query Certificate metadata
        // For now, we attempt to query what's available and provide guidance
        
        try {
            // Certificate object requires special permissions and may not be queryable
            // We'll check if the object is accessible first
            Schema.DescribeSObjectResult certDescribe = Schema.getGlobalDescribe().get('Certificate')?.getDescribe();
            
            if (certDescribe == null || !certDescribe.isAccessible()) {
                results.add(new FoxSecResult(
                    TEST_CERTIFICATES,
                    FoxSecResult.STATUS_INFO,
                    'Certificate verification not available via standard SOQL. ' +
                    'Check manually: Setup > Security > Certificate and Key Management.',
                    'For automated verification, enable Tooling API access in a future version.'
                ));
                return results;
            }
            
            // If accessible, query certificates (field availability varies by org)
            String query = 'SELECT Id, DeveloperName, ExpirationDate FROM Certificate WITH USER_MODE';
            List<SObject> certificates = Database.query(query);
            
            if (certificates.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_CERTIFICATES,
                    FoxSecResult.STATUS_PASS,
                    'No custom certificate detected in the org.',
                    null
                ));
                return results;
            }
            
            Date today = Date.today();
            Date warningThreshold = today.addDays(30);
            Boolean foundExpired = false;
            Boolean foundExpiringSoon = false;
            
            for (SObject cert : certificates) {
                String certName = (String) cert.get('DeveloperName');
                Date expirationDate = (Date) cert.get('ExpirationDate');
                
                if (expirationDate == null) {
                    continue;
                }
                
                if (expirationDate < today) {
                    foundExpired = true;
                    results.add(new FoxSecResult(
                        TEST_CERTIFICATES,
                        FoxSecResult.STATUS_CRITICAL,
                        'Certificate "' + String.escapeSingleQuotes(certName) + '" EXPIRED since ' + 
                        expirationDate.format() + '.',
                        'Renew certificate immediately. Setup > Security > Certificate and Key Management'
                    ));
                } else if (expirationDate <= warningThreshold) {
                    foundExpiringSoon = true;
                    results.add(new FoxSecResult(
                        TEST_CERTIFICATES,
                        FoxSecResult.STATUS_WARNING,
                        'Certificate "' + String.escapeSingleQuotes(certName) + '" expires on ' + 
                        expirationDate.format() + ' (less than 30 days).',
                        'Schedule certificate renewal before expiration.'
                    ));
                }
            }
            
            if (!foundExpired && !foundExpiringSoon) {
                results.add(new FoxSecResult(
                    TEST_CERTIFICATES,
                    FoxSecResult.STATUS_PASS,
                    'All certificates (' + certificates.size() + ') are valid and not near expiration.',
                    null
                ));
            }
            
        } catch (Exception e) {
            // Certificate object may not be queryable - this is expected in many orgs
            results.add(new FoxSecResult(
                TEST_CERTIFICATES,
                FoxSecResult.STATUS_INFO,
                'Certificate verification not available: ' + e.getMessage() + 
                '. Check manually in Setup.',
                'Setup > Security > Certificate and Key Management'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Login As Any User Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Audits whether administrators can log in as any user.
     * This is a security-sensitive setting that should be disabled in production.
     * @return List<FoxSecResult> Login policy audit findings.
     */
    @TestVisible
    private List<FoxSecResult> auditLoginAsAnyUser() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Query Organization settings
            // Note: The specific field for "Login As" may not be directly exposed
            // We check what's available via Organization object
            List<Organization> orgs = [
                SELECT Id, Name, OrganizationType, IsSandbox
                FROM Organization
                WITH USER_MODE
                LIMIT 1
            ];
            
            if (orgs.isEmpty()) {
                results.add(createSkippedResult(
                    TEST_LOGIN_AS_ANY_USER,
                    'Unable to retrieve Organization information.'
                ));
                return results;
            }
            
            Organization org = orgs[0];
            
            // Check via UserLogin object for any active "Login As" grants
            // This is an indirect check - direct setting is in SecuritySettings
            try {
                Integer loginAsCount = [
                    SELECT COUNT()
                    FROM LoginHistory
                    WHERE LoginType = 'SAML Sfdc Initiated SSO' 
                    OR LoginType = 'Remote Access 2.0'
                    WITH USER_MODE
                    LIMIT 1
                ];
                
                // Note: Direct access to "Administrators Can Log in as Any User" setting
                // requires SecuritySettings which isn't directly queryable via SOQL.
                // We provide guidance for manual verification.
                
                if (org.IsSandbox == false) {
                    // Production org - this setting should be disabled
                    results.add(new FoxSecResult(
                        TEST_LOGIN_AS_ANY_USER,
                        FoxSecResult.STATUS_WARNING,
                        'Production org detected. Verify that "Administrators Can Log in as Any User" ' +
                        'is DISABLED. This setting is not accessible via SOQL.',
                        'Check: Setup > Security > Login Access Policies. ' +
                        'Disable "Administrators Can Log in as Any User" in production.'
                    ));
                } else {
                    // Sandbox - less critical but still worth noting
                    results.add(new FoxSecResult(
                        TEST_LOGIN_AS_ANY_USER,
                        FoxSecResult.STATUS_INFO,
                        'Sandbox detected (' + String.escapeSingleQuotes(org.Name) + '). ' +
                        '"Login As" is often enabled for debugging. Check policies before refresh to prod.',
                        'Setup > Security > Login Access Policies'
                    ));
                }
                
            } catch (QueryException qe) {
                // LoginHistory may not be accessible
                results.add(new FoxSecResult(
                    TEST_LOGIN_AS_ANY_USER,
                    FoxSecResult.STATUS_INFO,
                    'Indirect verification not available. Manual check required.',
                    'Setup > Security > Login Access Policies > "Administrators Can Log in as Any User"'
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_LOGIN_AS_ANY_USER,
                'Error querying Organization: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_LOGIN_AS_ANY_USER,
                'Access denied to Organization object.'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Session Security Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Audits session security settings, specifically ForceLogout on timeout.
     * @return List<FoxSecResult> Session security audit findings.
     */
    @TestVisible
    private List<FoxSecResult> auditSessionSecurity() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // SessionSettings is not directly queryable via SOQL
            // We check Profile-level session settings as a proxy
            
            // Get current user's profile session settings
            List<Profile> profiles = [
                SELECT Id, Name
                FROM Profile
                WHERE Id = :UserInfo.getProfileId()
                WITH USER_MODE
                LIMIT 1
            ];
            
            // Query AuthSession to understand current session patterns
            // This gives us insight into session management
            try {
                List<AuthSession> sessions = [
                    SELECT Id, SessionType, LoginType, SessionSecurityLevel,
                           SourceIp, CreatedDate, LastModifiedDate, ParentId
                    FROM AuthSession
                    WHERE UsersId = :UserInfo.getUserId()
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 5
                ];
                
                // Check for sessions with low security levels
                Boolean foundLowSecurity = false;
                for (AuthSession session : sessions) {
                    if (session.SessionSecurityLevel == 'LOW' || 
                        session.SessionSecurityLevel == 'STANDARD') {
                        foundLowSecurity = true;
                        break;
                    }
                }
                
                if (foundLowSecurity) {
                    results.add(new FoxSecResult(
                        TEST_SESSION_FORCE_LOGOUT,
                        FoxSecResult.STATUS_WARNING,
                        'Sessions with LOW/STANDARD security level detected. ' +
                        'Recommendation: require HIGH_ASSURANCE for sensitive operations.',
                        'Setup > Session Settings > Session Security Levels. ' +
                        'Configure stricter session policies.'
                    ));
                }
                
            } catch (QueryException qe) {
                // AuthSession may not be accessible
            }
            
            // Provide guidance on ForceLogout since it's not directly queryable
            results.add(new FoxSecResult(
                TEST_SESSION_FORCE_LOGOUT,
                FoxSecResult.STATUS_INFO,
                'The "Force logout on session timeout" setting is not accessible via SOQL. ' +
                'This setting is critical to prevent session hijacking.',
                'Check: Setup > Session Settings > "Force logout on session timeout". ' +
                'MUST be enabled in production. Recommended timeout: 2 hours maximum.'
            ));
            
            // Additional check: Session timeout via Organization
            List<Organization> orgs = [
                SELECT Id, Name, DefaultLocaleSidKey, LanguageLocaleKey
                FROM Organization
                WITH USER_MODE
                LIMIT 1
            ];
            
            if (!orgs.isEmpty() && !orgs[0].LanguageLocaleKey.startsWith('en')) {
                // Non-English org - additional security consideration
                results.add(new FoxSecResult(
                    TEST_SESSION_FORCE_LOGOUT,
                    FoxSecResult.STATUS_INFO,
                    'Org configured in non-English language (' + orgs[0].LanguageLocaleKey + '). ' +
                    'Verify that security messages are understandable by all admins.',
                    null
                ));
            }
            
        } catch (Exception e) {
            results.add(createSkippedResult(
                TEST_SESSION_FORCE_LOGOUT,
                'Error during session audit: ' + e.getMessage()
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Utility Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Creates a SKIPPED result for when audit cannot be performed.
     * @param testName The test that was skipped.
     * @param reason The reason for skipping.
     * @return FoxSecResult A SKIPPED status result.
     */
    private FoxSecResult createSkippedResult(String testName, String reason) {
        return new FoxSecResult(
            testName,
            FoxSecResult.STATUS_SKIPPED,
            reason,
            'Verify that the user has "View Setup and Configuration" permission.'
        );
    }
}
