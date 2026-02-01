// File: force-app/main/default/classes/core/FoxSecControllerTest.cls
/**
 * @description Test class for FoxSecController
 * @author FoxSec Team
 * @date 2026-01-30
 */
@isTest
private class FoxSecControllerTest {
    
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