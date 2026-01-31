// File: force-app/main/default/classes/core/FoxSecResult.cls
/**
 * @description Wrapper class representing the result of a security audit test.
 * Used to communicate audit findings to the UI layer.
 * @author FoxSec Team
 * @date 2026-01-30
 */
public inherited sharing class FoxSecResult {
    
    /**
     * @description Name of the security test executed
     */
    @AuraEnabled
    public String testName { get; set; }
    
    /**
     * @description Status of the test result
     * Allowed values: 'PASS', 'WARNING', 'CRITICAL'
     */
    @AuraEnabled
    public String status { get; set; }
    
    /**
     * @description Human-readable message describing the test result
     */
    @AuraEnabled
    public String message { get; set; }
    
    /**
     * @description Recommended steps to remediate the issue if status is not PASS
     */
    @AuraEnabled
    public String remediationSteps { get; set; }
    
    /**
     * @description Default constructor
     */
    public FoxSecResult() {
        // Default constructor for deserialization
    }
    
    /**
     * @description Full constructor for creating audit results
     * @param testName Name of the test
     * @param status Test status (PASS, WARNING, CRITICAL)
     * @param message Result message
     * @param remediationSteps Remediation guidance
     */
    public FoxSecResult(String testName, String status, String message, String remediationSteps) {
        this.testName = testName;
        this.status = status;
        this.message = message;
        this.remediationSteps = remediationSteps;
    }
    
    /**
     * @description Status constants for type-safe usage
     */
    public static final String STATUS_PASS = 'PASS';
    public static final String STATUS_WARNING = 'WARNING';
    public static final String STATUS_CRITICAL = 'CRITICAL';
}