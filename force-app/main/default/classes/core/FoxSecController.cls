// File: force-app/main/default/classes/core/FoxSecController.cls
/**
 * @description Main controller for FoxSec audit operations.
 * Orchestrates the execution of all registered audit engines and aggregates results.
 * @author FoxSec Team
 * @date 2026-01-30
 */
public with sharing class FoxSecController {
    
    /**
     * @description Wrapper class for audit summary with score and statistics
     */
    public class AuditSummary {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public Integer totalTests { get; set; }
        @AuraEnabled public Integer criticalCount { get; set; }
        @AuraEnabled public Integer warningCount { get; set; }
        @AuraEnabled public Integer passCount { get; set; }
        @AuraEnabled public Integer skippedCount { get; set; }
        @AuraEnabled public List<FoxSecResult> results { get; set; }
        
        public AuditSummary() {
            this.score = 100;
            this.totalTests = 0;
            this.criticalCount = 0;
            this.warningCount = 0;
            this.passCount = 0;
            this.skippedCount = 0;
            this.results = new List<FoxSecResult>();
        }
    }
    
    /**
     * @description Executes all registered audit engines and returns aggregated results with summary.
     * @return AuditSummary containing score, statistics and detailed results
     */
    @AuraEnabled(cacheable=true)
    public static AuditSummary getAuditSummary() {
        AuditSummary summary = new AuditSummary();
        List<FoxSecResult> allResults = runAllAudits();
        
        summary.results = allResults;
        summary.totalTests = allResults.size();
        
        // Calculate statistics and score
        for (FoxSecResult result : allResults) {
            if (result.status == FoxSecResult.STATUS_CRITICAL) {
                summary.criticalCount++;
            } else if (result.status == FoxSecResult.STATUS_WARNING) {
                summary.warningCount++;
            } else if (result.status == FoxSecResult.STATUS_PASS) {
                summary.passCount++;
            } else if (result.status == FoxSecResult.STATUS_SKIPPED || 
                       result.status == FoxSecResult.STATUS_INFO) {
                summary.skippedCount++;
            }
        }
        
        // Score calculation: 100 - (criticals * 10) - (warnings * 3)
        // Minimum score is 0
        Integer scoreDeduction = (summary.criticalCount * 10) + (summary.warningCount * 3);
        summary.score = Math.max(0, 100 - scoreDeduction);
        
        return summary;
    }
    
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