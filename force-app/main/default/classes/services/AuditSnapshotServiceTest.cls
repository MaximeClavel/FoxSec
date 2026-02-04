// File: force-app/main/default/classes/services/AuditSnapshotServiceTest.cls
/**
 * @description Test class for AuditSnapshotService
 * @author FoxSec Team
 * @date 2026-02-04
 */
@IsTest
private class AuditSnapshotServiceTest {

    @TestSetup
    static void setup() {
        // Create test snapshots for trend analysis
        List<FoxSec_Audit_Snapshot__c> snapshots = new List<FoxSec_Audit_Snapshot__c>();
        
        for (Integer i = 0; i < 5; i++) {
            snapshots.add(new FoxSec_Audit_Snapshot__c(
                Snapshot_Date__c = DateTime.now().addDays(-i * 7),
                Health_Score__c = 80 + i,
                Grade__c = 'B',
                Critical_Count__c = 2 - (i > 1 ? 1 : 0),
                High_Count__c = 3,
                Medium_Count__c = 1,
                Low_Count__c = 0,
                Pass_Count__c = 10 + i,
                Total_Tests__c = 15 + i,
                Org_Id__c = UserInfo.getOrganizationId(),
                Audit_Details__c = '[]',
                Compliance_Template__c = 'None',
                Run_By__c = UserInfo.getUserId()
            ));
        }
        
        insert snapshots;
    }

    @IsTest
    static void testCreateSnapshot() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_WARNING, 'Warning found', 'Fix it'),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_CRITICAL, 'Critical issue', 'Fix now')
        };
        
        // When
        Test.startTest();
        Id snapshotId = AuditSnapshotService.createSnapshot(auditResults, 'SOC2');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, snapshotId, 'Snapshot ID should not be null');
        
        FoxSec_Audit_Snapshot__c snapshot = [
            SELECT Health_Score__c, Grade__c, Critical_Count__c, Compliance_Template__c
            FROM FoxSec_Audit_Snapshot__c 
            WHERE Id = :snapshotId
        ];
        
        System.assertEquals(1, snapshot.Critical_Count__c, 'Should have 1 critical');
        System.assertEquals('SOC2', snapshot.Compliance_Template__c, 'Template should be SOC2');
    }

    @IsTest
    static void testCreateSnapshot_WithoutTemplate() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null)
        };
        
        // When
        Test.startTest();
        Id snapshotId = AuditSnapshotService.createSnapshot(auditResults, null);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, snapshotId, 'Snapshot ID should not be null');
        
        FoxSec_Audit_Snapshot__c snapshot = [
            SELECT Compliance_Template__c
            FROM FoxSec_Audit_Snapshot__c 
            WHERE Id = :snapshotId
        ];
        
        System.assertEquals('None', snapshot.Compliance_Template__c, 'Template should be None');
    }

    @IsTest
    static void testGetLatestSnapshot() {
        // When
        Test.startTest();
        FoxSec_Audit_Snapshot__c snapshot = AuditSnapshotService.getLatestSnapshot();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, snapshot, 'Should return a snapshot');
        System.assertNotEquals(null, snapshot.Health_Score__c, 'Health score should not be null');
    }

    @IsTest
    static void testGetTrendAnalysis() {
        // When
        Test.startTest();
        AuditSnapshotService.TrendAnalysis analysis = AuditSnapshotService.getTrendAnalysis(30);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
        System.assertEquals(5, analysis.snapshotCount, 'Should have 5 snapshots');
        System.assertNotEquals(null, analysis.dataPoints, 'Data points should not be null');
        System.assertEquals(5, analysis.dataPoints.size(), 'Should have 5 data points');
        System.assert(analysis.currentScore > 0, 'Current score should be > 0');
        System.assert(analysis.averageScore > 0, 'Average score should be > 0');
    }

    @IsTest
    static void testGetTrendAnalysis_DefaultDays() {
        // When - null days should default to 30
        Test.startTest();
        AuditSnapshotService.TrendAnalysis analysis = AuditSnapshotService.getTrendAnalysis(null);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
    }

    @IsTest
    static void testGetTrendAnalysis_MaxDays() {
        // When - days > 365 should be capped
        Test.startTest();
        AuditSnapshotService.TrendAnalysis analysis = AuditSnapshotService.getTrendAnalysis(500);
        Test.stopTest();
        
        // Then - Should still work (capped at 365)
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
    }

    @IsTest
    static void testGetSnapshotsByDateRange() {
        // When
        Test.startTest();
        List<FoxSec_Audit_Snapshot__c> snapshots = AuditSnapshotService.getSnapshotsByDateRange(
            DateTime.now().addDays(-60),
            DateTime.now()
        );
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, snapshots, 'Snapshots should not be null');
        System.assertEquals(5, snapshots.size(), 'Should have 5 snapshots');
    }

    @IsTest
    static void testCompareSnapshots() {
        // Given
        List<FoxSec_Audit_Snapshot__c> snapshots = [
            SELECT Id FROM FoxSec_Audit_Snapshot__c ORDER BY Snapshot_Date__c DESC LIMIT 2
        ];
        
        // When
        Test.startTest();
        Map<String, Object> comparison = AuditSnapshotService.compareSnapshots(
            snapshots[0].Id, 
            snapshots[1].Id
        );
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, comparison, 'Comparison should not be null');
        System.assert(comparison.containsKey('baseline'), 'Should have baseline');
        System.assert(comparison.containsKey('current'), 'Should have current');
        System.assert(comparison.containsKey('scoreDifference'), 'Should have score difference');
    }

    @IsTest
    static void testCompareSnapshots_InvalidIds() {
        // When - Use fake IDs
        Test.startTest();
        Map<String, Object> comparison = AuditSnapshotService.compareSnapshots(
            UserInfo.getUserId(), // Wrong type of ID
            UserInfo.getUserId()
        );
        Test.stopTest();
        
        // Then - Should return error
        System.assert(comparison.containsKey('error'), 'Should have error key');
    }

    @IsTest
    static void testCleanupOldSnapshots() {
        // Given - Create old snapshot
        FoxSec_Audit_Snapshot__c oldSnapshot = new FoxSec_Audit_Snapshot__c(
            Snapshot_Date__c = DateTime.now().addDays(-100),
            Health_Score__c = 50,
            Grade__c = 'C',
            Org_Id__c = UserInfo.getOrganizationId()
        );
        insert oldSnapshot;
        
        // When - Cleanup with 90 day retention
        Test.startTest();
        Integer deletedCount = AuditSnapshotService.cleanupOldSnapshots(90);
        Test.stopTest();
        
        // Then
        System.assertEquals(1, deletedCount, 'Should have deleted 1 old snapshot');
    }

    @IsTest
    static void testCleanupOldSnapshots_MinRetention() {
        // When - Retention < 30 should default to 90
        Test.startTest();
        Integer deletedCount = AuditSnapshotService.cleanupOldSnapshots(10);
        Test.stopTest();
        
        // Then - Should still work with 90 day default
        System.assert(deletedCount >= 0, 'Should return valid count');
    }

    @IsTest
    static void testTrendDataPointWrapper() {
        // Given
        FoxSec_Audit_Snapshot__c snapshot = new FoxSec_Audit_Snapshot__c(
            Snapshot_Date__c = DateTime.now(),
            Health_Score__c = 85,
            Grade__c = 'B',
            Critical_Count__c = 1,
            High_Count__c = 2,
            Total_Tests__c = 15
        );
        
        // When
        Test.startTest();
        AuditSnapshotService.TrendDataPoint point = 
            new AuditSnapshotService.TrendDataPoint(snapshot);
        Test.stopTest();
        
        // Then
        System.assertEquals(85, point.healthScore, 'Health score should be 85');
        System.assertEquals('B', point.grade, 'Grade should be B');
        System.assertEquals(1, point.criticalCount, 'Critical count should be 1');
        System.assertEquals(2, point.highCount, 'High count should be 2');
        System.assertEquals(15, point.totalTests, 'Total tests should be 15');
        System.assertNotEquals(null, point.dateLabel, 'Date label should not be null');
    }

    @IsTest
    static void testTrendAnalysisWrapper() {
        // When
        Test.startTest();
        AuditSnapshotService.TrendAnalysis analysis = new AuditSnapshotService.TrendAnalysis();
        Test.stopTest();
        
        // Then - Default values
        System.assertEquals(0, analysis.currentScore, 'Current score should be 0');
        System.assertEquals(0, analysis.previousScore, 'Previous score should be 0');
        System.assertEquals(0, analysis.scoreTrend, 'Score trend should be 0');
        System.assertEquals('stable', analysis.trendDirection, 'Trend direction should be stable');
        System.assertEquals(100, analysis.lowestScore, 'Lowest score should default to 100');
        System.assertNotEquals(null, analysis.dataPoints, 'Data points should not be null');
    }
}
