// File: force-app/main/default/classes/services/AuditExportServiceTest.cls
/**
 * @description Test class for AuditExportService
 * @author FoxSec Team
 * @date 2026-02-04
 */
@IsTest
private class AuditExportServiceTest {

    @IsTest
    static void testExportToCSV() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed test', null),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_WARNING, 'Warning found', 'Fix it'),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_CRITICAL, 'Critical issue', 'Fix now')
        };
        
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        options.includePassedTests = true;
        options.includeRemediation = true;
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = AuditExportService.exportToCSV(auditResults, options);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assertNotEquals(null, result.content, 'Content should not be null');
        System.assert(result.content.contains('Test Name'), 'Should contain header');
        System.assert(result.content.contains('Test 1'), 'Should contain test data');
        System.assert(result.fileName.endsWith('.csv'), 'Filename should end with .csv');
        System.assertEquals('text/csv', result.mimeType, 'MIME type should be text/csv');
    }

    @IsTest
    static void testExportToCSV_ExcludePassedTests() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Passed Test', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Failed Test', FoxSecResult.STATUS_CRITICAL, 'Failed', 'Fix')
        };
        
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        options.includePassedTests = false;
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = AuditExportService.exportToCSV(auditResults, options);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assert(!result.content.contains('Passed Test'), 'Should not contain passed test');
        System.assert(result.content.contains('Failed Test'), 'Should contain failed test');
    }

    @IsTest
    static void testExportToCSV_NullOptions() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null)
        };
        
        // When - null options should use defaults
        Test.startTest();
        AuditExportService.ExportResult result = AuditExportService.exportToCSV(auditResults, null);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
    }

    @IsTest
    static void testExportToCSV_EmptyResults() {
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportToCSV(new List<FoxSecResult>(), null);
        Test.stopTest();
        
        // Then
        System.assertEquals(false, result.success, 'Export should fail');
        System.assertNotEquals(null, result.errorMessage, 'Error message should be set');
    }

    @IsTest
    static void testExportToCSV_NullResults() {
        // When
        Test.startTest();
        AuditExportService.ExportResult result = AuditExportService.exportToCSV(null, null);
        Test.stopTest();
        
        // Then
        System.assertEquals(false, result.success, 'Export should fail');
    }

    @IsTest
    static void testExportToCSV_SpecialCharacters() {
        // Given - Test with special characters that need escaping
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test with, comma', FoxSecResult.STATUS_WARNING, 'Message with "quotes"', 'Fix\nthis')
        };
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportToCSV(auditResults, new AuditExportService.ExportOptions());
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed with special chars');
        System.assert(result.content.contains('"'), 'Should contain escaped quotes');
    }

    @IsTest
    static void testExportSummaryToCSV() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_CRITICAL, 'Critical', 'Fix')
        };
        
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(auditResults);
        
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportSummaryToCSV(scoreResult, auditResults, options);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assert(result.content.contains('SUMMARY'), 'Should contain summary section');
        System.assert(result.content.contains('Health Score'), 'Should contain health score');
        System.assert(result.content.contains('DETAILED FINDINGS'), 'Should contain detailed findings');
    }

    @IsTest
    static void testExportSummaryToCSV_WithCompliance() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Shadow Admin Detection', FoxSecResult.STATUS_PASS, 'Passed', null)
        };
        
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(auditResults);
        
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        options.includeComplianceMapping = true;
        options.complianceTemplate = 'SOC2';
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportSummaryToCSV(scoreResult, auditResults, options);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assert(result.content.contains('COMPLIANCE ASSESSMENT'), 'Should contain compliance section');
        System.assert(result.content.contains('SOC2'), 'Should contain SOC2');
    }

    @IsTest
    static void testExportTrendDataToCSV() {
        // Given
        List<FoxSec_Audit_Snapshot__c> snapshots = new List<FoxSec_Audit_Snapshot__c>();
        for (Integer i = 0; i < 3; i++) {
            snapshots.add(new FoxSec_Audit_Snapshot__c(
                Snapshot_Date__c = DateTime.now().addDays(-i),
                Health_Score__c = 80 + i,
                Grade__c = 'B',
                Critical_Count__c = 1,
                High_Count__c = 2,
                Medium_Count__c = 1,
                Low_Count__c = 0,
                Pass_Count__c = 10,
                Total_Tests__c = 14,
                Org_Id__c = UserInfo.getOrganizationId(),
                Compliance_Template__c = 'None',
                Compliance_Score__c = 0.85
            ));
        }
        insert snapshots;
        
        // Re-query to get all fields
        snapshots = [
            SELECT Snapshot_Date__c, Health_Score__c, Grade__c, Critical_Count__c,
                   High_Count__c, Medium_Count__c, Low_Count__c, Pass_Count__c,
                   Total_Tests__c, Compliance_Template__c, Compliance_Score__c, Run_By__r.Name
            FROM FoxSec_Audit_Snapshot__c
        ];
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportTrendDataToCSV(snapshots);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assert(result.content.contains('Snapshot Date'), 'Should contain header');
        System.assert(result.content.contains('Health Score'), 'Should contain health score column');
        System.assert(result.fileName.contains('Trend'), 'Filename should contain Trend');
    }

    @IsTest
    static void testExportTrendDataToCSV_EmptySnapshots() {
        // When
        Test.startTest();
        AuditExportService.ExportResult result = 
            AuditExportService.exportTrendDataToCSV(new List<FoxSec_Audit_Snapshot__c>());
        Test.stopTest();
        
        // Then
        System.assertEquals(false, result.success, 'Export should fail');
    }

    @IsTest
    static void testExportToExcel() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_WARNING, 'Warning', 'Fix')
        };
        
        // When
        Test.startTest();
        AuditExportService.ExportResult result = AuditExportService.exportToExcel(auditResults);
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'Export should succeed');
        System.assert(result.fileName.endsWith('.xls'), 'Filename should end with .xls');
        System.assertEquals('application/vnd.ms-excel', result.mimeType, 'Should have Excel MIME type');
    }

    @IsTest
    static void testExportOptionsDefaults() {
        // When
        Test.startTest();
        AuditExportService.ExportOptions options = new AuditExportService.ExportOptions();
        Test.stopTest();
        
        // Then - Verify defaults
        System.assertEquals(true, options.includePassedTests, 'includePassedTests should default to true');
        System.assertEquals(true, options.includeRemediation, 'includeRemediation should default to true');
        System.assertEquals(false, options.includeComplianceMapping, 'includeComplianceMapping should default to false');
        System.assertEquals('None', options.complianceTemplate, 'complianceTemplate should default to None');
        System.assertNotEquals(null, options.dateFormat, 'dateFormat should not be null');
    }

    @IsTest
    static void testExportResultDefaults() {
        // When
        Test.startTest();
        AuditExportService.ExportResult result = new AuditExportService.ExportResult();
        Test.stopTest();
        
        // Then
        System.assertEquals(true, result.success, 'success should default to true');
    }
}
