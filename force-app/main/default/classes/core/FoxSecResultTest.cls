// File: force-app/main/default/classes/core/FoxSecResultTest.cls
/**
 * @description Test class for FoxSecResult wrapper
 * @author FoxSec Team
 * @date 2026-01-30
 */
@isTest
private class FoxSecResultTest {
    
    @isTest
    static void testDefaultConstructor() {
        Test.startTest();
        FoxSecResult result = new FoxSecResult();
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNull(result.testName, 'testName should be null by default');
        Assert.isNull(result.status, 'status should be null by default');
    }
    
    @isTest
    static void testFullConstructor() {
        String testName = 'Password Policy Check';
        String status = FoxSecResult.STATUS_CRITICAL;
        String message = 'Password policy is too weak';
        String remediation = 'Increase minimum password length to 12';
        
        Test.startTest();
        FoxSecResult result = new FoxSecResult(testName, status, message, remediation);
        Test.stopTest();
        
        Assert.areEqual(testName, result.testName, 'testName should match');
        Assert.areEqual(status, result.status, 'status should match');
        Assert.areEqual(message, result.message, 'message should match');
        Assert.areEqual(remediation, result.remediationSteps, 'remediationSteps should match');
    }
    
    @isTest
    static void testStatusConstants() {
        Assert.areEqual('PASS', FoxSecResult.STATUS_PASS, 'STATUS_PASS constant should be PASS');
        Assert.areEqual('WARNING', FoxSecResult.STATUS_WARNING, 'STATUS_WARNING constant should be WARNING');
        Assert.areEqual('CRITICAL', FoxSecResult.STATUS_CRITICAL, 'STATUS_CRITICAL constant should be CRITICAL');
        Assert.areEqual('SKIPPED', FoxSecResult.STATUS_SKIPPED, 'STATUS_SKIPPED constant should be SKIPPED');
        Assert.areEqual('INFO', FoxSecResult.STATUS_INFO, 'STATUS_INFO constant should be INFO');
    }
    
    @isTest
    static void testSettersAndGetters() {
        FoxSecResult result = new FoxSecResult();
        
        result.testName = 'Test Name';
        result.status = FoxSecResult.STATUS_WARNING;
        result.message = 'Test Message';
        result.remediationSteps = 'Test Remediation';
        
        Assert.areEqual('Test Name', result.testName, 'testName getter should work');
        Assert.areEqual(FoxSecResult.STATUS_WARNING, result.status, 'status getter should work');
        Assert.areEqual('Test Message', result.message, 'message getter should work');
        Assert.areEqual('Test Remediation', result.remediationSteps, 'remediationSteps getter should work');
    }
}