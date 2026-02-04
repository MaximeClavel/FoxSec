// File: force-app/main/default/classes/services/AuditExportService.cls
/**
 * @description Service class for exporting audit results in various formats.
 * Supports CSV export for data analysis and compliance reporting.
 * PDF export via Visualforce rendering for formal audit reports.
 * @author FoxSec Team
 * @date 2026-02-04
 */
public with sharing class AuditExportService {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    private static final String CSV_SEPARATOR = ',';
    private static final String CSV_NEWLINE = '\n';
    private static final String CSV_QUOTE = '"';

    // ─────────────────────────────────────────────────────────────────────────────
    // Inner Classes
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Wrapper for export configuration options
     */
    public class ExportOptions {
        @AuraEnabled public Boolean includePassedTests { get; set; }
        @AuraEnabled public Boolean includeRemediation { get; set; }
        @AuraEnabled public Boolean includeComplianceMapping { get; set; }
        @AuraEnabled public String complianceTemplate { get; set; }
        @AuraEnabled public String dateFormat { get; set; }
        
        public ExportOptions() {
            this.includePassedTests = true;
            this.includeRemediation = true;
            this.includeComplianceMapping = false;
            this.complianceTemplate = 'None';
            this.dateFormat = 'yyyy-MM-dd HH:mm:ss';
        }
    }
    
    /**
     * @description Wrapper for export result
     */
    public class ExportResult {
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String mimeType { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        
        public ExportResult() {
            this.success = true;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // CSV Export Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Exports audit results to CSV format
     * @param auditResults List of FoxSecResult to export
     * @param options Export configuration options
     * @return ExportResult Contains CSV content and metadata
     */
    public static ExportResult exportToCSV(List<FoxSecResult> auditResults, ExportOptions options) {
        ExportResult result = new ExportResult();
        
        if (auditResults == null || auditResults.isEmpty()) {
            result.success = false;
            result.errorMessage = 'No audit results to export';
            return result;
        }
        
        if (options == null) {
            options = new ExportOptions();
        }
        
        try {
            // Build CSV content
            List<String> csvLines = new List<String>();
            
            // Add header row
            csvLines.add(buildCSVHeader(options));
            
            // Add data rows
            for (FoxSecResult auditResult : auditResults) {
                // Skip passed tests if not included
                if (!options.includePassedTests && auditResult.status == FoxSecResult.STATUS_PASS) {
                    continue;
                }
                csvLines.add(buildCSVRow(auditResult, options));
            }
            
            result.content = String.join(csvLines, CSV_NEWLINE);
            result.fileName = 'FoxSec_Audit_' + DateTime.now().format('yyyyMMdd_HHmmss') + '.csv';
            result.mimeType = 'text/csv';
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error generating CSV: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * @description Exports audit summary to CSV format
     * @param scoreResult Health score calculation result
     * @param auditResults List of FoxSecResult
     * @param options Export configuration options
     * @return ExportResult Contains CSV content with summary and details
     */
    public static ExportResult exportSummaryToCSV(HealthScoreCalculator.HealthScoreResult scoreResult,
                                                   List<FoxSecResult> auditResults,
                                                   ExportOptions options) {
        ExportResult result = new ExportResult();
        
        if (options == null) {
            options = new ExportOptions();
        }
        
        try {
            List<String> csvLines = new List<String>();
            
            // Add summary section
            csvLines.add('FoxSec Security Audit Report');
            csvLines.add('Generated: ' + DateTime.now().format(options.dateFormat));
            csvLines.add('Organization ID: ' + UserInfo.getOrganizationId());
            csvLines.add('');
            
            // Add score summary
            csvLines.add('SUMMARY');
            csvLines.add('Health Score,' + scoreResult.score);
            csvLines.add('Grade,' + scoreResult.grade);
            csvLines.add('Grade Description,' + escapeCSV(scoreResult.gradeLabel));
            csvLines.add('Total Tests,' + scoreResult.totalTests);
            csvLines.add('Critical Issues,' + scoreResult.criticalCount);
            csvLines.add('High Issues,' + scoreResult.highCount);
            csvLines.add('Medium Issues,' + scoreResult.mediumCount);
            csvLines.add('Low Issues,' + scoreResult.lowCount);
            csvLines.add('Passed,' + scoreResult.passCount);
            csvLines.add('Skipped,' + scoreResult.skippedCount);
            csvLines.add('');
            
            // Add compliance section if template specified
            if (options.includeComplianceMapping && 
                String.isNotBlank(options.complianceTemplate) && 
                options.complianceTemplate != 'None') {
                
                ComplianceTemplateService.ComplianceAssessment assessment = 
                    ComplianceTemplateService.runComplianceAssessment(
                        options.complianceTemplate, 
                        auditResults
                    );
                
                csvLines.add('COMPLIANCE ASSESSMENT: ' + options.complianceTemplate);
                csvLines.add('Compliance Score,' + assessment.complianceScore + '%');
                csvLines.add('Total Controls,' + assessment.totalControls);
                csvLines.add('Passed Controls,' + assessment.passedControls);
                csvLines.add('Failed Controls,' + assessment.failedControls);
                csvLines.add('Not Applicable,' + assessment.notApplicableControls);
                csvLines.add('');
                
                // Add compliance control details
                csvLines.add('Control ID,Control Name,Requirement,FoxSec Test,Status');
                for (ComplianceTemplateService.ComplianceControl control : assessment.controls) {
                    csvLines.add(
                        escapeCSV(control.controlId) + CSV_SEPARATOR +
                        escapeCSV(control.controlName) + CSV_SEPARATOR +
                        escapeCSV(control.requirement) + CSV_SEPARATOR +
                        escapeCSV(control.foxSecTest) + CSV_SEPARATOR +
                        escapeCSV(control.status)
                    );
                }
                csvLines.add('');
            }
            
            // Add detailed results section
            csvLines.add('DETAILED FINDINGS');
            csvLines.add(buildCSVHeader(options));
            
            for (FoxSecResult auditResult : auditResults) {
                if (!options.includePassedTests && auditResult.status == FoxSecResult.STATUS_PASS) {
                    continue;
                }
                csvLines.add(buildCSVRow(auditResult, options));
            }
            
            result.content = String.join(csvLines, CSV_NEWLINE);
            result.fileName = 'FoxSec_Full_Report_' + DateTime.now().format('yyyyMMdd_HHmmss') + '.csv';
            result.mimeType = 'text/csv';
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error generating CSV report: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * @description Exports snapshot history to CSV for trend analysis
     * @param snapshots List of snapshots to export
     * @return ExportResult Contains CSV content
     */
    public static ExportResult exportTrendDataToCSV(List<FoxSec_Audit_Snapshot__c> snapshots) {
        ExportResult result = new ExportResult();
        
        if (snapshots == null || snapshots.isEmpty()) {
            result.success = false;
            result.errorMessage = 'No snapshot data to export';
            return result;
        }
        
        try {
            List<String> csvLines = new List<String>();
            
            // Header
            csvLines.add('Snapshot Date,Health Score,Grade,Critical,High,Medium,Low,Passed,Total Tests,Compliance Template,Compliance Score,Run By');
            
            // Data rows
            for (FoxSec_Audit_Snapshot__c snapshot : snapshots) {
                csvLines.add(
                    formatDateTime(snapshot.Snapshot_Date__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Health_Score__c) + CSV_SEPARATOR +
                    escapeCSV(snapshot.Grade__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Critical_Count__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.High_Count__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Medium_Count__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Low_Count__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Pass_Count__c) + CSV_SEPARATOR +
                    formatNumber(snapshot.Total_Tests__c) + CSV_SEPARATOR +
                    escapeCSV(snapshot.Compliance_Template__c) + CSV_SEPARATOR +
                    formatPercent(snapshot.Compliance_Score__c) + CSV_SEPARATOR +
                    escapeCSV(snapshot.Run_By__r != null ? snapshot.Run_By__r.Name : '')
                );
            }
            
            result.content = String.join(csvLines, CSV_NEWLINE);
            result.fileName = 'FoxSec_Trend_Data_' + DateTime.now().format('yyyyMMdd_HHmmss') + '.csv';
            result.mimeType = 'text/csv';
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error generating trend CSV: ' + e.getMessage();
        }
        
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Excel-Compatible Export (Tab-Separated)
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Exports audit results to Excel-compatible format (TSV)
     * @param auditResults List of FoxSecResult to export
     * @return ExportResult Contains TSV content
     */
    public static ExportResult exportToExcel(List<FoxSecResult> auditResults) {
        ExportResult result = new ExportResult();
        
        if (auditResults == null || auditResults.isEmpty()) {
            result.success = false;
            result.errorMessage = 'No audit results to export';
            return result;
        }
        
        try {
            List<String> tsvLines = new List<String>();
            String TAB = '\t';
            
            // Header
            tsvLines.add('Test Name' + TAB + 'Status' + TAB + 'Message' + TAB + 'Remediation Steps');
            
            // Data rows
            for (FoxSecResult auditResult : auditResults) {
                tsvLines.add(
                    escapeExcel(auditResult.testName) + TAB +
                    escapeExcel(auditResult.status) + TAB +
                    escapeExcel(auditResult.message) + TAB +
                    escapeExcel(auditResult.remediationSteps)
                );
            }
            
            result.content = String.join(tsvLines, CSV_NEWLINE);
            result.fileName = 'FoxSec_Audit_' + DateTime.now().format('yyyyMMdd_HHmmss') + '.xls';
            result.mimeType = 'application/vnd.ms-excel';
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error generating Excel export: ' + e.getMessage();
        }
        
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Private Helper Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Builds the CSV header row
     */
    private static String buildCSVHeader(ExportOptions options) {
        String header = 'Test Name,Status,Message';
        if (options.includeRemediation) {
            header += ',Remediation Steps';
        }
        return header;
    }
    
    /**
     * @description Builds a CSV data row for an audit result
     */
    private static String buildCSVRow(FoxSecResult auditResult, ExportOptions options) {
        String row = escapeCSV(auditResult.testName) + CSV_SEPARATOR +
                     escapeCSV(auditResult.status) + CSV_SEPARATOR +
                     escapeCSV(auditResult.message);
        
        if (options.includeRemediation) {
            row += CSV_SEPARATOR + escapeCSV(auditResult.remediationSteps);
        }
        
        return row;
    }
    
    /**
     * @description Escapes a value for CSV format
     */
    private static String escapeCSV(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        
        // Check if value needs quoting
        if (value.contains(CSV_SEPARATOR) || value.contains(CSV_NEWLINE) || 
            value.contains(CSV_QUOTE) || value.contains('\r')) {
            // Escape quotes by doubling them
            value = value.replace(CSV_QUOTE, CSV_QUOTE + CSV_QUOTE);
            // Wrap in quotes
            return CSV_QUOTE + value + CSV_QUOTE;
        }
        
        return value;
    }
    
    /**
     * @description Escapes a value for Excel/TSV format
     */
    private static String escapeExcel(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        // Remove tabs and replace newlines with spaces
        return value.replace('\t', ' ').replace('\n', ' ').replace('\r', '');
    }
    
    /**
     * @description Formats a DateTime for export
     */
    private static String formatDateTime(DateTime dt) {
        return dt != null ? dt.format('yyyy-MM-dd HH:mm:ss') : '';
    }
    
    /**
     * @description Formats a number for export
     */
    private static String formatNumber(Decimal num) {
        return num != null ? String.valueOf(num.intValue()) : '0';
    }
    
    /**
     * @description Formats a percentage for export
     */
    private static String formatPercent(Decimal pct) {
        if (pct == null) {
            return '';
        }
        return String.valueOf((pct * 100).setScale(2)) + '%';
    }
}
