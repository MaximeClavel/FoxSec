// File: force-app/main/default/classes/core/FoxSecControllerTest.cls
/**
 * @description Test class for FoxSecController
 * @author FoxSec Team
 * @date 2026-01-30
 */
@isTest
private class FoxSecControllerTest {
    
    // ─────────────────────────────────────────────────────────────────────────────
    // getAuditSummary Tests
    // ─────────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetAuditSummary_ReturnsSummary() {
        Test.startTest();
        FoxSecController.AuditSummary summary = FoxSecController.getAuditSummary();
        Test.stopTest();
        
        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.isNotNull(summary.results, 'Results list should not be null');
        Assert.isTrue(summary.totalTests >= 0, 'Total tests should be non-negative');
        Assert.isTrue(summary.score >= 0 && summary.score <= 100, 'Score should be between 0 and 100');
    }
    
    @isTest
    static void testGetAuditSummary_ScoreCalculation() {
        Test.startTest();
        FoxSecController.AuditSummary summary = FoxSecController.getAuditSummary();
        Test.stopTest();
        
        // Verify statistics are consistent
        Integer expectedTotal = summary.criticalCount + summary.warningCount + 
                               summary.passCount + summary.skippedCount;
        Assert.areEqual(summary.totalTests, expectedTotal, 
            'Total should equal sum of all categories');
        
        // Verify score formula: 100 - (criticals * 10) - (warnings * 3), min 0
        Integer expectedScore = Math.max(0, 100 - (summary.criticalCount * 10) - (summary.warningCount * 3));
        Assert.areEqual(expectedScore, summary.score, 
            'Score should follow formula: 100 - (criticals * 10) - (warnings * 3)');
    }
    
    @isTest
    static void testGetAuditSummary_Cacheable() {
        // First call
        FoxSecController.AuditSummary summary1 = FoxSecController.getAuditSummary();
        
        Test.startTest();
        // Second call - cacheable should work
        FoxSecController.AuditSummary summary2 = FoxSecController.getAuditSummary();
        Test.stopTest();
        
        Assert.isNotNull(summary1, 'First summary should not be null');
        Assert.isNotNull(summary2, 'Second summary should not be null');
    }
    
    @isTest
    static void testAuditSummary_DefaultConstructor() {
        Test.startTest();
        FoxSecController.AuditSummary summary = new FoxSecController.AuditSummary();
        Test.stopTest();
        
        Assert.areEqual(100, summary.score, 'Default score should be 100');
        Assert.areEqual(0, summary.totalTests, 'Default totalTests should be 0');
        Assert.areEqual(0, summary.criticalCount, 'Default criticalCount should be 0');
        Assert.areEqual(0, summary.warningCount, 'Default warningCount should be 0');
        Assert.areEqual(0, summary.passCount, 'Default passCount should be 0');
        Assert.areEqual(0, summary.skippedCount, 'Default skippedCount should be 0');
        Assert.isNotNull(summary.results, 'Results list should be initialized');
    }
    
    // ─────────────────────────────────────────────────────────────────────────────
    // runAllAudits Tests
    // ─────────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testRunAllAudits_ReturnsResults() {
        Test.startTest();
        List<FoxSecResult> results = FoxSecController.runAllAudits();
        Test.stopTest();
        
        Assert.isNotNull(results, 'Results should not be null');
        Assert.isTrue(results.size() > 0, 'Should return results from all registered audit engines');
    }
    
    @isTest
    static void testRunAllAudits_Cacheable() {
        // First call
        List<FoxSecResult> results1 = FoxSecController.runAllAudits();
        
        // Second call - should use cache if working properly
        Test.startTest();
        List<FoxSecResult> results2 = FoxSecController.runAllAudits();
        Test.stopTest();
        
        Assert.isNotNull(results1, 'First call results should not be null');
        Assert.isNotNull(results2, 'Second call results should not be null');
        // Both calls should return results (may differ due to org state)
        Assert.isTrue(results1.size() > 0, 'First call should return results');
        Assert.isTrue(results2.size() > 0, 'Second call should return results');
    }
    
    @isTest
    static void testValidateResults_EmptyList() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(results);
        Test.stopTest();
        
        Assert.isTrue(isValid, 'Empty list should be valid');
    }
    
    @isTest
    static void testValidateResults_NullList() {
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(null);
        Test.stopTest();
        
        Assert.isTrue(isValid, 'Null list should be valid');
    }
    
    @isTest
    static void testValidateResults_ValidResults() {
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Message 1', 'Remediation 1'),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_WARNING, 'Message 2', 'Remediation 2'),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_CRITICAL, 'Message 3', 'Remediation 3'),
            new FoxSecResult('Test 4', FoxSecResult.STATUS_SKIPPED, 'Message 4', 'Remediation 4'),
            new FoxSecResult('Test 5', FoxSecResult.STATUS_INFO, 'Message 5', 'Remediation 5')
        };
        
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(results);
        Test.stopTest();
        
        Assert.isTrue(isValid, 'Valid results including SKIPPED and INFO should pass validation');
    }
    
    @isTest
    static void testValidateResults_MissingTestName() {
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('', FoxSecResult.STATUS_PASS, 'Message', 'Remediation')
        };
        
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(results);
        Test.stopTest();
        
        Assert.isFalse(isValid, 'Missing testName should fail validation');
    }
    
    @isTest
    static void testValidateResults_MissingStatus() {
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('Test Name', '', 'Message', 'Remediation')
        };
        
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(results);
        Test.stopTest();
        
        Assert.isFalse(isValid, 'Missing status should fail validation');
    }
    
    @isTest
    static void testValidateResults_InvalidStatus() {
        FoxSecResult result = new FoxSecResult();
        result.testName = 'Test Name';
        result.status = 'INVALID_STATUS';
        result.message = 'Message';
        
        List<FoxSecResult> results = new List<FoxSecResult>{ result };
        
        Test.startTest();
        Boolean isValid = FoxSecController.validateResults(results);
        Test.stopTest();
        
        Assert.isFalse(isValid, 'Invalid status should fail validation');
    }
}