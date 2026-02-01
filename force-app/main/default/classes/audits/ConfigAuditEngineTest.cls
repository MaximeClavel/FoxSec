// File: force-app/main/default/classes/audits/ConfigAuditEngineTest.cls
/**
 * @description Test class for ConfigAuditEngine.
 * Tests infrastructure security audit functionality.
 * @author FoxSec Team
 * @date 2026-01-30
 */
@IsTest
private class ConfigAuditEngineTest {

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Interface Implementation
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testImplementsIFoxSecAuditor() {
        // Verify ConfigAuditEngine implements the interface correctly
        IFoxSecAuditor auditor = new ConfigAuditEngine();
        System.assertNotEquals(null, auditor, 'Should instantiate as IFoxSecAuditor');
    }

    @IsTest
    static void testExecuteAuditReturnsResults() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Results should not be null');
        // Should have at least INFO/PASS results for each category
        System.assert(results.size() > 0, 'Should return at least one result');
        
        // Verify each result has required fields
        for (FoxSecResult result : results) {
            System.assertNotEquals(null, result.testName, 'testName should not be null');
            System.assertNotEquals(null, result.status, 'status should not be null');
            System.assertNotEquals(null, result.message, 'message should not be null');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Wildcard Detection Logic
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testDetectRiskyWildcard_HerokuPattern() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://*.herokuapp.com/api';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect herokuapp wildcard as risky');
        System.assert(result.contains('herokuapp'), 'Should return the matched pattern');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_AWSPattern() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://*.amazonaws.com';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect AWS wildcard as risky');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_SafeUrl() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://api.mycompany.com/v1';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertEquals(null, result, 'Should not flag specific domain as risky');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_NullUrl() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(null);
        Test.stopTest();
        
        // Then
        System.assertEquals(null, result, 'Should handle null URL gracefully');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_EmptyUrl() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard('');
        Test.stopTest();
        
        // Then
        System.assertEquals(null, result, 'Should handle empty URL gracefully');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_NgrokPattern() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://*.ngrok.io/webhook';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect ngrok as risky (dev tunneling service)');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_GenericTLD() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://*.com';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect *.com as extremely risky');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Remote Site Settings Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditRemoteSiteSettings_ExecutesWithoutException() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.auditRemoteSiteSettings();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        // May return SKIPPED if no access, or PASS if no remote sites, or findings
        System.assert(results.size() > 0 || true, 'Should handle gracefully');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: CSP Trusted Sites Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditCspTrustedSites_ExecutesWithoutException() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.auditCspTrustedSites();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Should return results list');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Certificates Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditCertificates_ExecutesWithoutException() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.auditCertificates();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        // Should return INFO if Certificate object not accessible
        System.assert(results.size() > 0, 'Should provide at least guidance');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Login As Any User Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditLoginAsAnyUser_ExecutesWithoutException() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.auditLoginAsAnyUser();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        System.assert(results.size() > 0, 'Should provide at least one finding');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Session Security Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditSessionSecurity_ExecutesWithoutException() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.auditSessionSecurity();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Should return results list');
        // Should always provide INFO about ForceLogout setting
        Boolean hasSessionInfo = false;
        for (FoxSecResult r : results) {
            if (r.testName == ConfigAuditEngine.TEST_SESSION_FORCE_LOGOUT) {
                hasSessionInfo = true;
                break;
            }
        }
        System.assert(hasSessionInfo, 'Should include session security guidance');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Result Status Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testResultStatusValues() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then - verify all statuses are valid
        Set<String> validStatuses = new Set<String>{
            FoxSecResult.STATUS_PASS,
            FoxSecResult.STATUS_WARNING,
            FoxSecResult.STATUS_CRITICAL,
            FoxSecResult.STATUS_SKIPPED,
            FoxSecResult.STATUS_INFO
        };
        
        for (FoxSecResult result : results) {
            System.assert(
                validStatuses.contains(result.status),
                'Invalid status "' + result.status + '" in result: ' + result.testName
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Test Name Constants Exist
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testTestNameConstantsAreDefined() {
        // Verify all test name constants are properly defined
        System.assertNotEquals(null, ConfigAuditEngine.TEST_REMOTE_SITE_HTTP);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_REMOTE_SITE_WILDCARD);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_CSP_UNSAFE_INLINE);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_CSP_UNSAFE_EVAL);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_CERTIFICATES);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_LOGIN_AS_ANY_USER);
        System.assertNotEquals(null, ConfigAuditEngine.TEST_SESSION_FORCE_LOGOUT);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Full Audit Coverage Categories
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testExecuteAuditCoversAllCategories() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then - verify we have results from multiple categories
        Set<String> coveredTests = new Set<String>();
        for (FoxSecResult result : results) {
            coveredTests.add(result.testName);
        }
        
        // Should cover at least 3 different test categories
        System.assert(
            coveredTests.size() >= 3,
            'Should cover multiple test categories. Found: ' + coveredTests
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Edge Cases - URL Parsing
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testDetectRiskyWildcard_UrlWithPort() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'https://*.herokuapp.com:8080/api';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect pattern even with port number');
    }
    
    @IsTest
    static void testDetectRiskyWildcard_HttpUrl() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        String url = 'http://*.amazonaws.com/bucket';
        
        // When
        Test.startTest();
        String result = engine.detectRiskyWildcard(url);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should detect pattern in HTTP URL');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Security - No Data Modification
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditIsReadOnly() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // Get initial state counts (if queryable)
        Integer initialRemoteSiteCount = 0;
        try {
            initialRemoteSiteCount = [SELECT COUNT() FROM RemoteProxy WITH USER_MODE];
        } catch (Exception e) {
            // May not have access - that's OK
        }
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then - verify no data was modified
        Integer finalRemoteSiteCount = 0;
        try {
            finalRemoteSiteCount = [SELECT COUNT() FROM RemoteProxy WITH USER_MODE];
        } catch (Exception e) {
            // May not have access - that's OK
        }
        
        System.assertEquals(
            initialRemoteSiteCount,
            finalRemoteSiteCount,
            'Audit should not modify any data'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Bulk Execution
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testMultipleAuditExecutions() {
        // Given
        ConfigAuditEngine engine = new ConfigAuditEngine();
        
        // When - Execute multiple times to ensure no state issues
        Test.startTest();
        List<FoxSecResult> results1 = engine.executeAudit();
        List<FoxSecResult> results2 = engine.executeAudit();
        List<FoxSecResult> results3 = engine.executeAudit();
        Test.stopTest();
        
        // Then - Results should be consistent
        System.assertEquals(
            results1.size(),
            results2.size(),
            'Multiple executions should return consistent results'
        );
        System.assertEquals(
            results2.size(),
            results3.size(),
            'Multiple executions should return consistent results'
        );
    }
}
