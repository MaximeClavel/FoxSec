// File: force-app/main/default/classes/core/FoxSecController.cls
/**
 * @description Main controller for FoxSec audit operations.
 * Orchestrates the execution of all registered audit engines and aggregates results.
 * Provides methods for compliance assessment, export, and trend analysis.
 * @author FoxSec Team
 * @date 2026-01-30
 * @updated 2026-02-04 - Added Phase 2 features (Health Score, Compliance, Export)
 */
public with sharing class FoxSecController {
    
    /**
     * @description Wrapper class for audit summary with score and statistics
     */
    public class AuditSummary {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public String grade { get; set; }
        @AuraEnabled public String gradeColor { get; set; }
        @AuraEnabled public String gradeLabel { get; set; }
        @AuraEnabled public Integer totalTests { get; set; }
        @AuraEnabled public Integer criticalCount { get; set; }
        @AuraEnabled public Integer warningCount { get; set; }
        @AuraEnabled public Integer passCount { get; set; }
        @AuraEnabled public Integer skippedCount { get; set; }
        @AuraEnabled public List<FoxSecResult> results { get; set; }
        
        public AuditSummary() {
            this.score = 100;
            this.grade = 'A';
            this.gradeColor = 'green';
            this.gradeLabel = 'Excellent security posture';
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
     * Uses the enhanced HealthScoreCalculator for accurate scoring with grade information.
     * @return AuditSummary containing score, statistics and detailed results
     */
    @AuraEnabled(cacheable=true)
    public static AuditSummary getAuditSummary() {
        AuditSummary summary = new AuditSummary();
        List<FoxSecResult> allResults = runAllAudits();
        
        summary.results = allResults;
        summary.totalTests = allResults.size();
        
        // Use HealthScoreCalculator for accurate scoring
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(allResults);
        
        summary.score = scoreResult.score;
        summary.grade = scoreResult.grade;
        summary.gradeColor = scoreResult.gradeColor;
        summary.gradeLabel = scoreResult.gradeLabel;
        summary.criticalCount = scoreResult.criticalCount;
        summary.warningCount = scoreResult.highCount;
        summary.passCount = scoreResult.passCount;
        summary.skippedCount = scoreResult.skippedCount;
        
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
    
    // ─────────────────────────────────────────────────────────────────────────────
    // Phase 2 Methods - Compliance, Export, Snapshots, Trends
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Returns available compliance templates
     * @return List of available compliance templates with metadata
     */
    @AuraEnabled(cacheable=true)
    public static List<ComplianceTemplateService.ComplianceTemplateInfo> getComplianceTemplates() {
        return ComplianceTemplateService.getAvailableTemplates();
    }
    
    /**
     * @description Runs a compliance assessment against a specific template
     * @param templateName Name of the compliance template (SOC2, GDPR, HIPAA, ISO27001)
     * @return ComplianceAssessment Results of the compliance check
     */
    @AuraEnabled
    public static ComplianceTemplateService.ComplianceAssessment runComplianceAssessment(String templateName) {
        List<FoxSecResult> auditResults = runAllAudits();
        return ComplianceTemplateService.runComplianceAssessment(templateName, auditResults);
    }
    
    /**
     * @description Saves the current audit results as a snapshot
     * @param complianceTemplate Optional compliance template name
     * @return Id The ID of the created snapshot record
     */
    @AuraEnabled
    public static Id saveAuditSnapshot(String complianceTemplate) {
        List<FoxSecResult> auditResults = runAllAudits();
        return AuditSnapshotService.createSnapshot(auditResults, complianceTemplate);
    }
    
    /**
     * @description Retrieves trend analysis data for the specified number of days
     * @param days Number of days to look back (default 30)
     * @return TrendAnalysis Trend analysis data with data points
     */
    @AuraEnabled(cacheable=true)
    public static AuditSnapshotService.TrendAnalysis getTrendAnalysis(Integer days) {
        return AuditSnapshotService.getTrendAnalysis(days);
    }
    
    /**
     * @description Gets the most recent audit snapshot
     * @return FoxSec_Audit_Snapshot__c Latest snapshot or null
     */
    @AuraEnabled(cacheable=true)
    public static FoxSec_Audit_Snapshot__c getLatestSnapshot() {
        return AuditSnapshotService.getLatestSnapshot();
    }
    
    /**
     * @description Exports current audit results to CSV format
     * @param includePassedTests Whether to include passed tests in export
     * @param includeRemediation Whether to include remediation steps
     * @param complianceTemplate Compliance template for mapping (optional)
     * @return ExportResult Contains CSV content and metadata
     */
    @AuraEnabled
    public static AuditExportService.ExportResult exportAuditToCSV(
        Boolean includePassedTests, 
        Boolean includeRemediation,
        String complianceTemplate
    ) {
        List<FoxSecResult> auditResults = runAllAudits();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(auditResults);
        
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        options.includePassedTests = includePassedTests != null ? includePassedTests : true;
        options.includeRemediation = includeRemediation != null ? includeRemediation : true;
        options.includeComplianceMapping = String.isNotBlank(complianceTemplate) && 
                                           complianceTemplate != 'None';
        options.complianceTemplate = complianceTemplate;
        
        return AuditExportService.exportSummaryToCSV(scoreResult, auditResults, options);
    }
    
    /**
     * @description Exports trend data to CSV format
     * @param days Number of days of trend data to export
     * @return ExportResult Contains CSV content with trend data
     */
    @AuraEnabled
    public static AuditExportService.ExportResult exportTrendDataToCSV(Integer days) {
        if (days == null || days <= 0) {
            days = 30;
        }
        
        DateTime startDate = DateTime.now().addDays(-days);
        DateTime endDate = DateTime.now();
        
        List<FoxSec_Audit_Snapshot__c> snapshots = 
            AuditSnapshotService.getSnapshotsByDateRange(startDate, endDate);
        
        return AuditExportService.exportTrendDataToCSV(snapshots);
    }
    
    /**
     * @description Compares two audit snapshots
     * @param snapshotId1 First snapshot ID (baseline)
     * @param snapshotId2 Second snapshot ID (comparison)
     * @return Map containing comparison results
     */
    @AuraEnabled
    public static Map<String, Object> compareSnapshots(Id snapshotId1, Id snapshotId2) {
        return AuditSnapshotService.compareSnapshots(snapshotId1, snapshotId2);
    }

    /**
     * @description Exports current audit results to Excel XML format
     * @return ExportResult Contains Excel XML content and metadata
     */
    @AuraEnabled
    public static AuditExportService.ExportResult exportAuditToExcel() {
        List<FoxSecResult> auditResults = runAllAudits();
        return AuditExportService.exportToExcel(auditResults);
    }
}