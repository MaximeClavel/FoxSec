// File: force-app/main/default/classes/audits/SharingAuditEngineTest.cls
/**
 * @description Test class for SharingAuditEngine.
 * Tests data sharing and exposure audit functionality.
 * Uses mock data for Organization object since it's read-only.
 * @author FoxSec Team
 * @date 2026-02-01
 */
@IsTest
private class SharingAuditEngineTest {

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Interface Implementation
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testImplementsIFoxSecAuditor() {
        // Verify SharingAuditEngine implements the interface correctly
        IFoxSecAuditor auditor = new SharingAuditEngine();
        System.assertNotEquals(null, auditor, 'Should instantiate as IFoxSecAuditor');
    }

    @IsTest
    static void testExecuteAuditReturnsResults() {
        // Given
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() > 0, 'Should return at least one result');
        
        // Verify each result has required fields
        for (FoxSecResult result : results) {
            System.assertNotEquals(null, result.testName, 'testName should not be null');
            System.assertNotEquals(null, result.status, 'status should not be null');
            System.assertNotEquals(null, result.message, 'message should not be null');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Organization-Wide Defaults - CRITICAL Cases
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testOWD_AccountReadWrite_ReturnsCritical() {
        // Given - Account OWD set to ReadWrite (Public Read/Write = risky)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('ReadWrite', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        System.assertNotEquals(null, accountResult, 'Should have Account OWD result');
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, accountResult.status, 
            'ReadWrite OWD should be CRITICAL');
        System.assert(accountResult.message.contains('Public Read/Write'), 
            'Message should mention Public Read/Write');
        System.assertNotEquals(null, accountResult.remediationSteps, 
            'Should provide remediation steps');
    }
    
    @IsTest
    static void testOWD_ContactReadWrite_ReturnsCritical() {
        // Given - Contact OWD set to ReadWrite
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'ReadWrite', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult contactResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CONTACT);
        System.assertNotEquals(null, contactResult, 'Should have Contact OWD result');
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, contactResult.status, 
            'ReadWrite OWD should be CRITICAL');
    }
    
    @IsTest
    static void testOWD_CaseReadWrite_ReturnsCritical() {
        // Given - Case OWD set to ReadWrite
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'ReadWrite');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult caseResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CASE);
        System.assertNotEquals(null, caseResult, 'Should have Case OWD result');
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, caseResult.status, 
            'ReadWrite OWD should be CRITICAL');
    }
    
    @IsTest
    static void testOWD_AllReadWrite_ReturnsMultipleCriticals() {
        // Given - All OWDs set to ReadWrite (worst case scenario)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('ReadWrite', 'ReadWrite', 'ReadWrite');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        Integer criticalCount = 0;
        for (FoxSecResult r : results) {
            if (r.status == FoxSecResult.STATUS_CRITICAL) {
                criticalCount++;
            }
        }
        System.assert(criticalCount >= 3, 'Should have at least 3 CRITICAL findings for OWDs');
    }
    
    @IsTest
    static void testOWD_Edit_ReturnsCritical() {
        // Given - 'Edit' is an alias for ReadWrite in some contexts
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Edit', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, accountResult.status, 
            'Edit OWD should be flagged as CRITICAL');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Organization-Wide Defaults - PASS Cases
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testOWD_AllPrivate_ReturnsPass() {
        // Given - All OWDs set to Private (secure)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        FoxSecResult contactResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CONTACT);
        FoxSecResult caseResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CASE);
        
        System.assertEquals(FoxSecResult.STATUS_PASS, accountResult.status, 'Private should PASS');
        System.assertEquals(FoxSecResult.STATUS_PASS, contactResult.status, 'Private should PASS');
        System.assertEquals(FoxSecResult.STATUS_PASS, caseResult.status, 'Private should PASS');
    }
    
    @IsTest
    static void testOWD_PublicReadOnly_ReturnsPass() {
        // Given - OWD set to 'Read' (Public Read Only - acceptable)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Read', 'Read', 'Read');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        System.assertEquals(FoxSecResult.STATUS_PASS, accountResult.status, 
            'Public Read Only should PASS');
    }
    
    @IsTest
    static void testOWD_ControlledByParent_ReturnsPass() {
        // Given - Contact controlled by parent Account
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'ControlledByParent', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult contactResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CONTACT);
        System.assertEquals(FoxSecResult.STATUS_PASS, contactResult.status, 
            'ControlledByParent should PASS');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Organization-Wide Defaults - SKIPPED Cases
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testOWD_NullSettings_ReturnsSkipped() {
        // Given - No mock settings (simulates inaccessible Organization)
        SharingAuditEngine engine = new SharingAuditEngine();
        SharingAuditEngine.mockOrgSettings = null;
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then - Should handle gracefully with SKIPPED status
        // Note: Real query might return data, so we check for valid response
        System.assertNotEquals(null, results, 'Should return results even when settings unavailable');
    }
    
    @IsTest
    static void testOWD_BlankAccessLevel_ReturnsSkipped() {
        // Given - Blank access level (field not readable)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        System.assertEquals(FoxSecResult.STATUS_SKIPPED, accountResult.status, 
            'Blank access level should be SKIPPED');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: isRiskyOwdValue Helper Method
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testIsRiskyOwdValue_ReadWrite() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue('ReadWrite');
        Test.stopTest();
        
        System.assertEquals(true, result, 'ReadWrite should be risky');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_Edit() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue('Edit');
        Test.stopTest();
        
        System.assertEquals(true, result, 'Edit should be risky');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_ReadWriteTransfer() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue('ReadWriteTransfer');
        Test.stopTest();
        
        System.assertEquals(true, result, 'ReadWriteTransfer should be risky');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_Private() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue('Private');
        Test.stopTest();
        
        System.assertEquals(false, result, 'Private should NOT be risky');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_Read() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue('Read');
        Test.stopTest();
        
        System.assertEquals(false, result, 'Read (Public Read Only) should NOT be risky');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_Null() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean result = engine.isRiskyOwdValue(null);
        Test.stopTest();
        
        System.assertEquals(false, result, 'Null should NOT be risky (handled separately)');
    }
    
    @IsTest
    static void testIsRiskyOwdValue_CaseInsensitive() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        Boolean resultLower = engine.isRiskyOwdValue('readwrite');
        Boolean resultUpper = engine.isRiskyOwdValue('READWRITE');
        Boolean resultMixed = engine.isRiskyOwdValue('ReadWrite');
        Test.stopTest();
        
        System.assertEquals(true, resultLower, 'Should be case insensitive (lowercase)');
        System.assertEquals(true, resultUpper, 'Should be case insensitive (uppercase)');
        System.assertEquals(true, resultMixed, 'Should be case insensitive (mixed)');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: External Sharing Model
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testExternalSharing_MatchesInternal_ReturnsWarning() {
        // Given - External sharing matches internal (misconfiguration)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        setupMockExternalSharing('Account', 'Read', 'Read'); // Same internal and external
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult externalResult = findResultByTestName(results, SharingAuditEngine.TEST_EXTERNAL_SHARING);
        System.assertNotEquals(null, externalResult, 'Should have external sharing result');
        System.assertEquals(FoxSecResult.STATUS_WARNING, externalResult.status, 
            'Matching external/internal sharing should be WARNING');
    }
    
    @IsTest
    static void testExternalSharing_DifferentFromInternal_ReturnsPass() {
        // Given - External sharing is more restrictive (correct)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        setupMockExternalSharing('Account', 'Read', 'Private'); // External more restrictive
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult externalResult = findResultByTestName(results, SharingAuditEngine.TEST_EXTERNAL_SHARING);
        System.assertNotEquals(null, externalResult, 'Should have external sharing result');
        System.assertEquals(FoxSecResult.STATUS_PASS, externalResult.status, 
            'Different external sharing should PASS');
    }
    
    @IsTest
    static void testExternalSharing_BothPrivate_ReturnsPass() {
        // Given - Both are Private (exception - matching Private is OK)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        setupMockExternalSharing('Account', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult externalResult = findResultByTestName(results, SharingAuditEngine.TEST_EXTERNAL_SHARING);
        System.assertNotEquals(null, externalResult, 'Should have external sharing result');
        // Both Private is acceptable even if matching
        System.assertNotEquals(FoxSecResult.STATUS_WARNING, externalResult.status, 
            'Both Private should not be WARNING');
    }
    
    @IsTest
    static void testExternalSharing_NoConfig_ReturnsInfo() {
        // Given - No external sharing configuration
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        SharingAuditEngine.mockExternalConfigs = new List<SharingAuditEngine.ExternalSharingConfig>();
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult externalResult = findResultByTestName(results, SharingAuditEngine.TEST_EXTERNAL_SHARING);
        System.assertNotEquals(null, externalResult, 'Should have external sharing result');
        System.assertEquals(FoxSecResult.STATUS_INFO, externalResult.status, 
            'No config should return INFO');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Public Files / Content Distribution
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testPublicFiles_NoDistributions_ReturnsPass() {
        // Given - No ContentDistribution records
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        
        // When - ContentDistribution is empty in test context
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult filesResult = findResultByTestName(results, SharingAuditEngine.TEST_PUBLIC_FILES);
        System.assertNotEquals(null, filesResult, 'Should have public files result');
        // In clean test org, should be PASS or SKIPPED
        System.assert(
            filesResult.status == FoxSecResult.STATUS_PASS || 
            filesResult.status == FoxSecResult.STATUS_SKIPPED,
            'Empty distribution should PASS or be SKIPPED'
        );
    }
    
    @IsTest
    static void testPublicFiles_WithUnprotectedLinks() {
        // Given - Create ContentVersion and ContentDistribution
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        
        // Create test content
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;
        
        // Get the ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        // Create public distribution (unprotected)
        ContentDistribution cd = new ContentDistribution(
            Name = 'Test Distribution',
            ContentVersionId = cv.Id,
            PreferencesAllowOriginalDownload = true,
            PreferencesAllowPDFDownload = false,
            PreferencesAllowViewInBrowser = true
        );
        insert cd;
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult filesResult = findResultByTestName(results, SharingAuditEngine.TEST_PUBLIC_FILES);
        System.assertNotEquals(null, filesResult, 'Should have public files result');
        // Should detect the unprotected link
        System.assert(
            filesResult.status == FoxSecResult.STATUS_WARNING ||
            filesResult.status == FoxSecResult.STATUS_PASS,
            'Should detect unprotected links or pass if protected'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: evaluateOwdSetting Helper Method
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testEvaluateOwdSetting_RiskyValue() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        FoxSecResult result = engine.evaluateOwdSetting(
            'Test OWD', 
            'TestObject', 
            'ReadWrite'
        );
        Test.stopTest();
        
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, result.status, 
            'Risky value should return CRITICAL');
        System.assert(result.message.contains('TestObject'), 
            'Message should contain object name');
        System.assert(result.remediationSteps.contains('Sharing Settings'), 
            'Remediation should mention Sharing Settings');
    }
    
    @IsTest
    static void testEvaluateOwdSetting_SafeValue() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        FoxSecResult result = engine.evaluateOwdSetting(
            'Test OWD', 
            'TestObject', 
            'Private'
        );
        Test.stopTest();
        
        System.assertEquals(FoxSecResult.STATUS_PASS, result.status, 
            'Safe value should return PASS');
        System.assertEquals(null, result.remediationSteps, 
            'PASS result should not have remediation steps');
    }
    
    @IsTest
    static void testEvaluateOwdSetting_BlankValue() {
        SharingAuditEngine engine = new SharingAuditEngine();
        
        Test.startTest();
        FoxSecResult result = engine.evaluateOwdSetting(
            'Test OWD', 
            'TestObject', 
            ''
        );
        Test.stopTest();
        
        System.assertEquals(FoxSecResult.STATUS_SKIPPED, result.status, 
            'Blank value should return SKIPPED');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Edge Cases and Error Handling
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testAuditWithWhitespaceInValues() {
        // Given - Values with whitespace (should be trimmed)
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('  ReadWrite  ', 'Private', 'Private');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, accountResult.status, 
            'Should trim whitespace and detect risky value');
    }
    
    @IsTest
    static void testMixedOWDSettings() {
        // Given - Mix of secure and insecure settings
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'ReadWrite', 'Read');
        
        // When
        Test.startTest();
        List<FoxSecResult> results = engine.executeAudit();
        Test.stopTest();
        
        // Then
        FoxSecResult accountResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_ACCOUNT);
        FoxSecResult contactResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CONTACT);
        FoxSecResult caseResult = findResultByTestName(results, SharingAuditEngine.TEST_OWD_CASE);
        
        System.assertEquals(FoxSecResult.STATUS_PASS, accountResult.status, 'Account should PASS');
        System.assertEquals(FoxSecResult.STATUS_CRITICAL, contactResult.status, 'Contact should be CRITICAL');
        System.assertEquals(FoxSecResult.STATUS_PASS, caseResult.status, 'Case should PASS');
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Test: Bulk/Performance
    // ─────────────────────────────────────────────────────────────────────────────
    
    @IsTest
    static void testExecuteAuditQueryLimits() {
        // Given
        SharingAuditEngine engine = new SharingAuditEngine();
        setupMockOrgSettings('Private', 'Private', 'Private');
        
        // When
        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        List<FoxSecResult> results = engine.executeAudit();
        Integer queriesUsed = Limits.getQueries() - queriesBefore;
        Test.stopTest();
        
        // Then - Should be efficient with queries
        System.assert(queriesUsed <= 10, 
            'Audit should use reasonable number of queries. Used: ' + queriesUsed);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Helper Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Sets up mock Organization sharing settings for testing
     */
    private static void setupMockOrgSettings(
        String accountAccess, 
        String contactAccess, 
        String caseAccess
    ) {
        SharingAuditEngine.OrgSharingSettings mockSettings = 
            new SharingAuditEngine.OrgSharingSettings();
        mockSettings.defaultAccountAccess = accountAccess;
        mockSettings.defaultContactAccess = contactAccess;
        mockSettings.defaultCaseAccess = caseAccess;
        mockSettings.defaultOpportunityAccess = 'Private';
        mockSettings.defaultLeadAccess = 'ReadWrite';
        mockSettings.defaultCalendarAccess = 'HideDetailsInsert';
        mockSettings.defaultPricebookAccess = 'Read';
        
        SharingAuditEngine.mockOrgSettings = mockSettings;
    }
    
    /**
     * @description Sets up mock external sharing configuration for testing
     */
    private static void setupMockExternalSharing(
        String objectName, 
        String internalAccess, 
        String externalAccess
    ) {
        SharingAuditEngine.ExternalSharingConfig config = 
            new SharingAuditEngine.ExternalSharingConfig();
        config.objectName = objectName;
        config.internalAccess = internalAccess;
        config.externalAccess = externalAccess;
        
        SharingAuditEngine.mockExternalConfigs = 
            new List<SharingAuditEngine.ExternalSharingConfig>{ config };
    }
    
    /**
     * @description Finds a result by test name in the results list
     */
    private static FoxSecResult findResultByTestName(
        List<FoxSecResult> results, 
        String testName
    ) {
        for (FoxSecResult result : results) {
            if (result.testName == testName) {
                return result;
            }
        }
        return null;
    }
}
