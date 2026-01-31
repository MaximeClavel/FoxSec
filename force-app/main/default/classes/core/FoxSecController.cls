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
     * Currently returns empty list - will be implemented in future iterations.
     * @return List of FoxSecResult objects from all audit engines
     */
    @AuraEnabled(cacheable=true)
    public static List<FoxSecResult> runAllAudits() {
        // TODO: Implement audit engine registry and execution logic
        // For now, return empty list to satisfy interface contract
        return new List<FoxSecResult>();
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
                result.status != FoxSecResult.STATUS_CRITICAL) {
                return false;
            }
        }
        
        return true;
    }
}