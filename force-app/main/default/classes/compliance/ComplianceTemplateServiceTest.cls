// File: force-app/main/default/classes/compliance/ComplianceTemplateServiceTest.cls
/**
 * @description Test class for ComplianceTemplateService
 * @author FoxSec Team
 * @date 2026-02-04
 */
@IsTest
private class ComplianceTemplateServiceTest {

    @IsTest
    static void testGetAvailableTemplates() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceTemplateInfo> templates = 
            ComplianceTemplateService.getAvailableTemplates();
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, templates, 'Templates should not be null');
        System.assertEquals(4, templates.size(), 'Should have 4 templates');
        
        // Verify template values
        Set<String> templateValues = new Set<String>();
        for (ComplianceTemplateService.ComplianceTemplateInfo template : templates) {
            templateValues.add(template.value);
            System.assertNotEquals(null, template.label, 'Label should not be null');
            System.assertNotEquals(null, template.description, 'Description should not be null');
            System.assert(template.controlCount > 0, 'Control count should be > 0');
        }
        
        System.assert(templateValues.contains('SOC2'), 'Should contain SOC2');
        System.assert(templateValues.contains('GDPR'), 'Should contain GDPR');
        System.assert(templateValues.contains('HIPAA'), 'Should contain HIPAA');
        System.assert(templateValues.contains('ISO27001'), 'Should contain ISO27001');
    }

    @IsTest
    static void testGetTemplateControls_SOC2() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceControl> controls = 
            ComplianceTemplateService.getTemplateControls('SOC2');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, controls, 'Controls should not be null');
        System.assert(controls.size() > 0, 'Should have controls');
        
        // Verify control structure
        ComplianceTemplateService.ComplianceControl firstControl = controls[0];
        System.assertNotEquals(null, firstControl.controlId, 'Control ID should not be null');
        System.assertNotEquals(null, firstControl.controlName, 'Control name should not be null');
        System.assertNotEquals(null, firstControl.requirement, 'Requirement should not be null');
        System.assertNotEquals(null, firstControl.foxSecTest, 'FoxSec test should not be null');
    }

    @IsTest
    static void testGetTemplateControls_GDPR() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceControl> controls = 
            ComplianceTemplateService.getTemplateControls('GDPR');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, controls, 'Controls should not be null');
        System.assert(controls.size() > 0, 'Should have controls');
    }

    @IsTest
    static void testGetTemplateControls_HIPAA() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceControl> controls = 
            ComplianceTemplateService.getTemplateControls('HIPAA');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, controls, 'Controls should not be null');
        System.assert(controls.size() > 0, 'Should have controls');
    }

    @IsTest
    static void testGetTemplateControls_ISO27001() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceControl> controls = 
            ComplianceTemplateService.getTemplateControls('ISO27001');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, controls, 'Controls should not be null');
        System.assert(controls.size() > 0, 'Should have controls');
    }

    @IsTest
    static void testGetTemplateControls_Invalid() {
        // When
        Test.startTest();
        List<ComplianceTemplateService.ComplianceControl> controls = 
            ComplianceTemplateService.getTemplateControls('InvalidTemplate');
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, controls, 'Controls should not be null');
        System.assertEquals(0, controls.size(), 'Should have no controls for invalid template');
    }

    @IsTest
    static void testRunComplianceAssessment_SOC2() {
        // Given - Mix of passing and failing audit results
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('Shadow Admin Detection', FoxSecResult.STATUS_PASS, 'No shadow admins found', null),
            new FoxSecResult('Guest User Exposure', FoxSecResult.STATUS_WARNING, 'Guest user has write access', 'Restrict access'),
            new FoxSecResult('OWD Settings', FoxSecResult.STATUS_PASS, 'OWD properly configured', null),
            new FoxSecResult('Password Policy', FoxSecResult.STATUS_CRITICAL, 'Weak password policy', 'Update policy'),
            new FoxSecResult('Session Security', FoxSecResult.STATUS_PASS, 'Session timeout configured', null)
        };
        
        // When
        Test.startTest();
        ComplianceTemplateService.ComplianceAssessment assessment = 
            ComplianceTemplateService.runComplianceAssessment('SOC2', auditResults);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, assessment, 'Assessment should not be null');
        System.assertEquals('SOC2', assessment.templateName, 'Template name should be SOC2');
        System.assert(assessment.totalControls > 0, 'Should have controls');
        System.assert(assessment.complianceScore >= 0 && assessment.complianceScore <= 100, 
                      'Score should be between 0 and 100');
        System.assertNotEquals(null, assessment.controls, 'Controls should not be null');
    }

    @IsTest
    static void testRunComplianceAssessment_GDPR() {
        // Given
        List<FoxSecResult> auditResults = new List<FoxSecResult>{
            new FoxSecResult('OWD Settings', FoxSecResult.STATUS_PASS, 'Configured correctly', null),
            new FoxSecResult('Session Security', FoxSecResult.STATUS_PASS, 'Configured correctly', null)
        };
        
        // When
        Test.startTest();
        ComplianceTemplateService.ComplianceAssessment assessment = 
            ComplianceTemplateService.runComplianceAssessment('GDPR', auditResults);
        Test.stopTest();
        
        // Then
        System.assertEquals('GDPR', assessment.templateName, 'Template name should be GDPR');
        System.assert(assessment.passedControls >= 0, 'Passed controls should be >= 0');
    }

    @IsTest
    static void testRunComplianceAssessment_WithNullResults() {
        // When
        Test.startTest();
        ComplianceTemplateService.ComplianceAssessment assessment = 
            ComplianceTemplateService.runComplianceAssessment('SOC2', null);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, assessment, 'Assessment should not be null');
        System.assertEquals(0, assessment.passedControls, 'Passed controls should be 0');
    }

    @IsTest
    static void testRunComplianceAssessment_WithEmptyResults() {
        // When
        Test.startTest();
        ComplianceTemplateService.ComplianceAssessment assessment = 
            ComplianceTemplateService.runComplianceAssessment('SOC2', new List<FoxSecResult>());
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, assessment, 'Assessment should not be null');
        System.assertEquals(0, assessment.passedControls, 'Passed controls should be 0');
    }

    @IsTest
    static void testComplianceControlWrapper() {
        // When
        Test.startTest();
        ComplianceTemplateService.ComplianceControl control = 
            new ComplianceTemplateService.ComplianceControl(
                'TEST-001',
                'Test Control',
                'Test requirement description',
                'Test FoxSec Test',
                'Direct'
            );
        Test.stopTest();
        
        // Then
        System.assertEquals('TEST-001', control.controlId, 'Control ID should match');
        System.assertEquals('Test Control', control.controlName, 'Control name should match');
        System.assertEquals('Test requirement description', control.requirement, 'Requirement should match');
        System.assertEquals('Test FoxSec Test', control.foxSecTest, 'FoxSec test should match');
        System.assertEquals('Direct', control.mappingType, 'Mapping type should match');
        System.assertEquals('Not Evaluated', control.status, 'Default status should be Not Evaluated');
        System.assertEquals(false, control.isPassed, 'Default isPassed should be false');
    }
}
