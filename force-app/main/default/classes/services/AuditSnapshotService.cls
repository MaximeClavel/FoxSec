// File: force-app/main/default/classes/services/AuditSnapshotService.cls
/**
 * @description Service class for managing audit snapshots.
 * Handles creation, retrieval, and trend analysis of security audit snapshots.
 * All operations respect CRUD/FLS and run in user context.
 * @author FoxSec Team
 * @date 2026-02-04
 */
public with sharing class AuditSnapshotService {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible private static final Integer DEFAULT_TREND_DAYS = 30;
    @TestVisible private static final Integer MAX_TREND_DAYS = 365;

    // ─────────────────────────────────────────────────────────────────────────────
    // Inner Classes
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Wrapper for trend analysis data point
     */
    public class TrendDataPoint {
        @AuraEnabled public DateTime snapshotDate { get; set; }
        @AuraEnabled public Integer healthScore { get; set; }
        @AuraEnabled public String grade { get; set; }
        @AuraEnabled public Integer criticalCount { get; set; }
        @AuraEnabled public Integer highCount { get; set; }
        @AuraEnabled public Integer totalTests { get; set; }
        @AuraEnabled public String dateLabel { get; set; }
        
        public TrendDataPoint() {}
        
        public TrendDataPoint(FoxSec_Audit_Snapshot__c snapshot) {
            this.snapshotDate = snapshot.Snapshot_Date__c;
            this.healthScore = snapshot.Health_Score__c != null ? 
                               snapshot.Health_Score__c.intValue() : 0;
            this.grade = snapshot.Grade__c;
            this.criticalCount = snapshot.Critical_Count__c != null ? 
                                 snapshot.Critical_Count__c.intValue() : 0;
            this.highCount = snapshot.High_Count__c != null ? 
                             snapshot.High_Count__c.intValue() : 0;
            this.totalTests = snapshot.Total_Tests__c != null ? 
                              snapshot.Total_Tests__c.intValue() : 0;
            this.dateLabel = snapshot.Snapshot_Date__c != null ? 
                             snapshot.Snapshot_Date__c.format('MMM dd') : '';
        }
    }
    
    /**
     * @description Wrapper for trend analysis summary
     */
    public class TrendAnalysis {
        @AuraEnabled public List<TrendDataPoint> dataPoints { get; set; }
        @AuraEnabled public Integer currentScore { get; set; }
        @AuraEnabled public Integer previousScore { get; set; }
        @AuraEnabled public Integer scoreTrend { get; set; }
        @AuraEnabled public String trendDirection { get; set; }
        @AuraEnabled public Integer averageScore { get; set; }
        @AuraEnabled public Integer highestScore { get; set; }
        @AuraEnabled public Integer lowestScore { get; set; }
        @AuraEnabled public Integer snapshotCount { get; set; }
        
        public TrendAnalysis() {
            this.dataPoints = new List<TrendDataPoint>();
            this.currentScore = 0;
            this.previousScore = 0;
            this.scoreTrend = 0;
            this.trendDirection = 'stable';
            this.averageScore = 0;
            this.highestScore = 0;
            this.lowestScore = 100;
            this.snapshotCount = 0;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Public Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Creates a new audit snapshot from current audit results
     * @param auditResults List of FoxSecResult from audit execution
     * @param complianceTemplate Optional compliance template name
     * @return Id The ID of the created snapshot record
     */
    public static Id createSnapshot(List<FoxSecResult> auditResults, String complianceTemplate) {
        // Calculate health score
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(auditResults);
        
        // Calculate compliance score if template specified
        Decimal complianceScore = null;
        if (String.isNotBlank(complianceTemplate) && complianceTemplate != 'None') {
            ComplianceTemplateService.ComplianceAssessment assessment = 
                ComplianceTemplateService.runComplianceAssessment(complianceTemplate, auditResults);
            complianceScore = assessment.complianceScore / 100; // Convert to decimal for percent field
        }
        
        // Serialize audit details to JSON
        String auditDetailsJson = JSON.serialize(auditResults);
        
        // Create snapshot record
        FoxSec_Audit_Snapshot__c snapshot = new FoxSec_Audit_Snapshot__c(
            Snapshot_Date__c = DateTime.now(),
            Health_Score__c = scoreResult.score,
            Grade__c = scoreResult.grade,
            Critical_Count__c = scoreResult.criticalCount,
            High_Count__c = scoreResult.highCount,
            Medium_Count__c = scoreResult.mediumCount,
            Low_Count__c = scoreResult.lowCount,
            Pass_Count__c = scoreResult.passCount,
            Total_Tests__c = scoreResult.totalTests,
            Org_Id__c = UserInfo.getOrganizationId(),
            Audit_Details__c = auditDetailsJson,
            Compliance_Template__c = String.isNotBlank(complianceTemplate) ? complianceTemplate : 'None',
            Compliance_Score__c = complianceScore,
            Run_By__c = UserInfo.getUserId()
        );
        
        // Insert with CRUD/FLS check
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, 
            new List<FoxSec_Audit_Snapshot__c>{ snapshot }
        );
        insert decision.getRecords();
        
        return ((FoxSec_Audit_Snapshot__c)decision.getRecords()[0]).Id;
    }
    
    /**
     * @description Retrieves the most recent snapshot
     * @return FoxSec_Audit_Snapshot__c Latest snapshot or null
     */
    public static FoxSec_Audit_Snapshot__c getLatestSnapshot() {
        List<FoxSec_Audit_Snapshot__c> snapshots = [
            SELECT Id, Name, Snapshot_Date__c, Health_Score__c, Grade__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Pass_Count__c, Total_Tests__c, Org_Id__c, Compliance_Template__c,
                   Compliance_Score__c, Run_By__c, Run_By__r.Name
            FROM FoxSec_Audit_Snapshot__c
            WHERE Org_Id__c = :UserInfo.getOrganizationId()
            WITH USER_MODE
            ORDER BY Snapshot_Date__c DESC
            LIMIT 1
        ];
        
        return snapshots.isEmpty() ? null : snapshots[0];
    }
    
    /**
     * @description Retrieves trend data for the specified number of days
     * @param days Number of days to look back (default 30)
     * @return TrendAnalysis Trend analysis data
     */
    public static TrendAnalysis getTrendAnalysis(Integer days) {
        if (days == null || days <= 0) {
            days = DEFAULT_TREND_DAYS;
        }
        days = Math.min(days, MAX_TREND_DAYS);
        
        DateTime startDate = DateTime.now().addDays(-days);
        
        List<FoxSec_Audit_Snapshot__c> snapshots = [
            SELECT Id, Snapshot_Date__c, Health_Score__c, Grade__c,
                   Critical_Count__c, High_Count__c, Total_Tests__c
            FROM FoxSec_Audit_Snapshot__c
            WHERE Org_Id__c = :UserInfo.getOrganizationId()
            AND Snapshot_Date__c >= :startDate
            WITH USER_MODE
            ORDER BY Snapshot_Date__c ASC
        ];
        
        TrendAnalysis analysis = new TrendAnalysis();
        analysis.snapshotCount = snapshots.size();
        
        if (snapshots.isEmpty()) {
            return analysis;
        }
        
        Integer totalScore = 0;
        
        for (FoxSec_Audit_Snapshot__c snapshot : snapshots) {
            TrendDataPoint point = new TrendDataPoint(snapshot);
            analysis.dataPoints.add(point);
            
            Integer score = point.healthScore;
            totalScore += score;
            
            if (score > analysis.highestScore) {
                analysis.highestScore = score;
            }
            if (score < analysis.lowestScore) {
                analysis.lowestScore = score;
            }
        }
        
        // Calculate averages and trends
        analysis.averageScore = totalScore / snapshots.size();
        
        if (snapshots.size() >= 1) {
            analysis.currentScore = analysis.dataPoints[analysis.dataPoints.size() - 1].healthScore;
        }
        
        if (snapshots.size() >= 2) {
            analysis.previousScore = analysis.dataPoints[analysis.dataPoints.size() - 2].healthScore;
            analysis.scoreTrend = analysis.currentScore - analysis.previousScore;
            
            if (analysis.scoreTrend > 0) {
                analysis.trendDirection = 'improving';
            } else if (analysis.scoreTrend < 0) {
                analysis.trendDirection = 'declining';
            } else {
                analysis.trendDirection = 'stable';
            }
        }
        
        return analysis;
    }
    
    /**
     * @description Gets snapshots for a date range
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return List<FoxSec_Audit_Snapshot__c> Snapshots in range
     */
    public static List<FoxSec_Audit_Snapshot__c> getSnapshotsByDateRange(DateTime startDate, 
                                                                          DateTime endDate) {
        return [
            SELECT Id, Name, Snapshot_Date__c, Health_Score__c, Grade__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Pass_Count__c, Total_Tests__c, Org_Id__c, Audit_Details__c,
                   Compliance_Template__c, Compliance_Score__c, Run_By__c, Run_By__r.Name
            FROM FoxSec_Audit_Snapshot__c
            WHERE Org_Id__c = :UserInfo.getOrganizationId()
            AND Snapshot_Date__c >= :startDate
            AND Snapshot_Date__c <= :endDate
            WITH USER_MODE
            ORDER BY Snapshot_Date__c DESC
        ];
    }
    
    /**
     * @description Compares two snapshots and returns the differences
     * @param snapshotId1 First snapshot ID (baseline)
     * @param snapshotId2 Second snapshot ID (comparison)
     * @return Map<String, Object> Comparison results
     */
    public static Map<String, Object> compareSnapshots(Id snapshotId1, Id snapshotId2) {
        List<FoxSec_Audit_Snapshot__c> snapshots = [
            SELECT Id, Name, Snapshot_Date__c, Health_Score__c, Grade__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Pass_Count__c, Total_Tests__c, Audit_Details__c
            FROM FoxSec_Audit_Snapshot__c
            WHERE Id IN (:snapshotId1, :snapshotId2)
            WITH USER_MODE
        ];
        
        Map<String, Object> comparison = new Map<String, Object>();
        
        if (snapshots.size() != 2) {
            comparison.put('error', 'Unable to retrieve both snapshots');
            return comparison;
        }
        
        FoxSec_Audit_Snapshot__c baseline = snapshots[0].Id == snapshotId1 ? 
                                            snapshots[0] : snapshots[1];
        FoxSec_Audit_Snapshot__c current = snapshots[0].Id == snapshotId2 ? 
                                           snapshots[0] : snapshots[1];
        
        comparison.put('baseline', new Map<String, Object>{
            'date' => baseline.Snapshot_Date__c,
            'score' => baseline.Health_Score__c,
            'grade' => baseline.Grade__c,
            'criticalCount' => baseline.Critical_Count__c,
            'highCount' => baseline.High_Count__c
        });
        
        comparison.put('current', new Map<String, Object>{
            'date' => current.Snapshot_Date__c,
            'score' => current.Health_Score__c,
            'grade' => current.Grade__c,
            'criticalCount' => current.Critical_Count__c,
            'highCount' => current.High_Count__c
        });
        
        Integer scoreDiff = current.Health_Score__c != null && baseline.Health_Score__c != null ?
                           current.Health_Score__c.intValue() - baseline.Health_Score__c.intValue() : 0;
        comparison.put('scoreDifference', scoreDiff);
        comparison.put('isImproved', scoreDiff > 0);
        
        return comparison;
    }
    
    /**
     * @description Deletes old snapshots beyond retention period
     * @param retentionDays Number of days to retain snapshots
     * @return Integer Number of deleted records
     */
    public static Integer cleanupOldSnapshots(Integer retentionDays) {
        if (retentionDays == null || retentionDays < 30) {
            retentionDays = 90; // Default 90 days retention
        }
        
        DateTime cutoffDate = DateTime.now().addDays(-retentionDays);
        
        List<FoxSec_Audit_Snapshot__c> oldSnapshots = [
            SELECT Id
            FROM FoxSec_Audit_Snapshot__c
            WHERE Snapshot_Date__c < :cutoffDate
            AND Org_Id__c = :UserInfo.getOrganizationId()
            WITH USER_MODE
            LIMIT 200
        ];
        
        if (!oldSnapshots.isEmpty()) {
            delete oldSnapshots;
        }
        
        return oldSnapshots.size();
    }
}
