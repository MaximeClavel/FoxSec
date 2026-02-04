// File: force-app/main/default/classes/core/HealthScoreCalculator.cls
/**
 * @description Service class for calculating security health scores.
 * Implements the scoring formula from the FoxSec roadmap:
 * Score = 100 - Σ(Finding × Weight) with severity-based caps.
 * @author FoxSec Team
 * @date 2026-02-04
 */
public with sharing class HealthScoreCalculator {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants - Scoring Weights (from roadmap)
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible private static final Integer CRITICAL_WEIGHT = 15;
    @TestVisible private static final Integer HIGH_WEIGHT = 8;
    @TestVisible private static final Integer MEDIUM_WEIGHT = 3;
    @TestVisible private static final Integer LOW_WEIGHT = 1;
    
    // Maximum deduction caps per severity
    @TestVisible private static final Integer CRITICAL_CAP = 60;
    @TestVisible private static final Integer HIGH_CAP = 40;
    @TestVisible private static final Integer MEDIUM_CAP = 20;
    @TestVisible private static final Integer LOW_CAP = 10;
    
    // Grade thresholds
    @TestVisible private static final Integer GRADE_A_THRESHOLD = 90;
    @TestVisible private static final Integer GRADE_B_THRESHOLD = 75;
    @TestVisible private static final Integer GRADE_C_THRESHOLD = 60;
    @TestVisible private static final Integer GRADE_D_THRESHOLD = 40;

    // ─────────────────────────────────────────────────────────────────────────────
    // Inner Classes
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Wrapper class containing complete health score breakdown
     */
    public class HealthScoreResult {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public String grade { get; set; }
        @AuraEnabled public String gradeColor { get; set; }
        @AuraEnabled public String gradeLabel { get; set; }
        @AuraEnabled public Integer criticalCount { get; set; }
        @AuraEnabled public Integer highCount { get; set; }
        @AuraEnabled public Integer mediumCount { get; set; }
        @AuraEnabled public Integer lowCount { get; set; }
        @AuraEnabled public Integer passCount { get; set; }
        @AuraEnabled public Integer skippedCount { get; set; }
        @AuraEnabled public Integer totalTests { get; set; }
        @AuraEnabled public Integer criticalDeduction { get; set; }
        @AuraEnabled public Integer highDeduction { get; set; }
        @AuraEnabled public Integer mediumDeduction { get; set; }
        @AuraEnabled public Integer lowDeduction { get; set; }
        @AuraEnabled public Integer totalDeduction { get; set; }
        
        public HealthScoreResult() {
            this.score = 100;
            this.grade = 'A';
            this.gradeColor = 'green';
            this.gradeLabel = 'Excellent';
            this.criticalCount = 0;
            this.highCount = 0;
            this.mediumCount = 0;
            this.lowCount = 0;
            this.passCount = 0;
            this.skippedCount = 0;
            this.totalTests = 0;
            this.criticalDeduction = 0;
            this.highDeduction = 0;
            this.mediumDeduction = 0;
            this.lowDeduction = 0;
            this.totalDeduction = 0;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Public Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Calculates the health score from a list of audit results.
     * Uses the formula: Score = 100 - Σ(Finding × Weight) with severity caps.
     * @param results List of FoxSecResult audit findings
     * @return HealthScoreResult Complete score breakdown
     */
    public static HealthScoreResult calculateScore(List<FoxSecResult> results) {
        HealthScoreResult scoreResult = new HealthScoreResult();
        
        if (results == null || results.isEmpty()) {
            return scoreResult;
        }
        
        scoreResult.totalTests = results.size();
        
        // Count findings by severity
        for (FoxSecResult result : results) {
            String status = result.status;
            
            if (status == FoxSecResult.STATUS_CRITICAL) {
                scoreResult.criticalCount++;
            } else if (status == FoxSecResult.STATUS_WARNING) {
                // Map WARNING to HIGH for scoring purposes
                scoreResult.highCount++;
            } else if (status == FoxSecResult.STATUS_PASS) {
                scoreResult.passCount++;
            } else if (status == FoxSecResult.STATUS_SKIPPED || 
                       status == FoxSecResult.STATUS_INFO) {
                scoreResult.skippedCount++;
            }
        }
        
        // Calculate deductions with caps
        scoreResult.criticalDeduction = Math.min(
            scoreResult.criticalCount * CRITICAL_WEIGHT, 
            CRITICAL_CAP
        );
        scoreResult.highDeduction = Math.min(
            scoreResult.highCount * HIGH_WEIGHT, 
            HIGH_CAP
        );
        scoreResult.mediumDeduction = Math.min(
            scoreResult.mediumCount * MEDIUM_WEIGHT, 
            MEDIUM_CAP
        );
        scoreResult.lowDeduction = Math.min(
            scoreResult.lowCount * LOW_WEIGHT, 
            LOW_CAP
        );
        
        // Total deduction
        scoreResult.totalDeduction = scoreResult.criticalDeduction + 
                                     scoreResult.highDeduction + 
                                     scoreResult.mediumDeduction + 
                                     scoreResult.lowDeduction;
        
        // Calculate final score (minimum 0)
        scoreResult.score = Math.max(0, 100 - scoreResult.totalDeduction);
        
        // Determine grade
        GradeInfo gradeInfo = getGradeInfo(scoreResult.score);
        scoreResult.grade = gradeInfo.grade;
        scoreResult.gradeColor = gradeInfo.color;
        scoreResult.gradeLabel = gradeInfo.label;
        
        return scoreResult;
    }
    
    /**
     * @description Calculates a simple score for backward compatibility with existing controller.
     * @param criticalCount Number of critical findings
     * @param warningCount Number of warning findings
     * @return Integer Score from 0-100
     */
    public static Integer calculateSimpleScore(Integer criticalCount, Integer warningCount) {
        Integer criticalDeduction = Math.min(criticalCount * CRITICAL_WEIGHT, CRITICAL_CAP);
        Integer warningDeduction = Math.min(warningCount * HIGH_WEIGHT, HIGH_CAP);
        return Math.max(0, 100 - criticalDeduction - warningDeduction);
    }
    
    /**
     * @description Gets the letter grade for a given score.
     * @param score Numeric score (0-100)
     * @return String Letter grade (A, B, C, D, F)
     */
    public static String getGrade(Integer score) {
        return getGradeInfo(score).grade;
    }
    
    /**
     * @description Gets complete grade information for a score.
     * @param score Numeric score (0-100)
     * @return GradeInfo Grade details including color and label
     */
    public static GradeInfo getGradeInfo(Integer score) {
        GradeInfo info = new GradeInfo();
        
        if (score >= GRADE_A_THRESHOLD) {
            info.grade = 'A';
            info.color = 'green';
            info.label = 'Excellent security posture';
        } else if (score >= GRADE_B_THRESHOLD) {
            info.grade = 'B';
            info.color = 'yellow';
            info.label = 'Good, minor improvements needed';
        } else if (score >= GRADE_C_THRESHOLD) {
            info.grade = 'C';
            info.color = 'orange';
            info.label = 'Fair, significant risks present';
        } else if (score >= GRADE_D_THRESHOLD) {
            info.grade = 'D';
            info.color = 'red';
            info.label = 'Poor, critical issues detected';
        } else {
            info.grade = 'F';
            info.color = 'black';
            info.label = 'Critical, immediate action required';
        }
        
        return info;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Helper Classes
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Wrapper for grade information
     */
    public class GradeInfo {
        @AuraEnabled public String grade { get; set; }
        @AuraEnabled public String color { get; set; }
        @AuraEnabled public String label { get; set; }
    }
}
