// File: force-app/main/default/classes/core/FoxSecController.cls
/**
 * @description Main controller for FoxSec audit operations.
 * Orchestrates the execution of all registered audit engines and aggregates results.
 * @author FoxSec Team
 * @date 2026-01-30
 */
public with sharing class FoxSecController {
    
    /**
     * @description Executes all registered audit engines and returns aggregated results.
     * @return List of FoxSecResult objects from all audit engines
     */
    @AuraEnabled(cacheable=true)
    public static List<FoxSecResult> runAllAudits() {
        List<FoxSecResult> allResults = new List<FoxSecResult>();
        
        // Execute ConfigAuditEngine
        IFoxSecAuditor configAuditor = new ConfigAuditEngine();
        allResults.addAll(configAuditor.executeAudit());
        
        // Execute UserAuditEngine
        IFoxSecAuditor userAuditor = new UserAuditEngine();
        allResults.addAll(userAuditor.executeAudit());
        
        // Execute SharingAuditEngine
        IFoxSecAuditor sharingAuditor = new SharingAuditEngine();
        allResults.addAll(sharingAuditor.executeAudit());
        
        // Future audit engines will be added here
        // e.g., PermissionAuditEngine, FlowAuditEngine, etc.
        
        return allResults;
    }
    
    /**
     * @description Private helper method to validate audit results
     * @param results List of results to validate
     * @return Boolean indicating if all results are valid
     */
    @TestVisible
    private static Boolean validateResults(List<FoxSecResult> results) {
        if (results == null || results.isEmpty()) {
            return true; // Empty results are valid
        }
        
        for (FoxSecResult result : results) {
            if (String.isBlank(result.testName) || String.isBlank(result.status)) {
                return false;
            }
            
            // Validate status is one of the allowed values
            if (result.status != FoxSecResult.STATUS_PASS && 
                result.status != FoxSecResult.STATUS_WARNING && 
                result.status != FoxSecResult.STATUS_CRITICAL &&
                result.status != FoxSecResult.STATUS_SKIPPED &&
                result.status != FoxSecResult.STATUS_INFO) {
                return false;
            }
        }
        
        return true;
    }
}