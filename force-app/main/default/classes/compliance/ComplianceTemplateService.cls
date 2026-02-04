// File: force-app/main/default/classes/compliance/ComplianceTemplateService.cls
/**
 * @description Service class for compliance framework templates.
 * Maps FoxSec audit tests to compliance controls (SOC2, GDPR, HIPAA, ISO27001).
 * Calculates compliance scores based on test results.
 * @author FoxSec Team
 * @date 2026-02-04
 */
public with sharing class ComplianceTemplateService {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    public static final String TEMPLATE_SOC2 = 'SOC2';
    public static final String TEMPLATE_GDPR = 'GDPR';
    public static final String TEMPLATE_HIPAA = 'HIPAA';
    public static final String TEMPLATE_ISO27001 = 'ISO27001';
    public static final String TEMPLATE_NONE = 'None';

    // ─────────────────────────────────────────────────────────────────────────────
    // Inner Classes
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Represents a single compliance control mapping
     */
    public class ComplianceControl {
        @AuraEnabled public String controlId { get; set; }
        @AuraEnabled public String controlName { get; set; }
        @AuraEnabled public String requirement { get; set; }
        @AuraEnabled public String foxSecTest { get; set; }
        @AuraEnabled public String mappingType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isPassed { get; set; }
        
        public ComplianceControl(String controlId, String controlName, String requirement, 
                                  String foxSecTest, String mappingType) {
            this.controlId = controlId;
            this.controlName = controlName;
            this.requirement = requirement;
            this.foxSecTest = foxSecTest;
            this.mappingType = mappingType;
            this.status = 'Not Evaluated';
            this.isPassed = false;
        }
    }
    
    /**
     * @description Wrapper for compliance assessment results
     */
    public class ComplianceAssessment {
        @AuraEnabled public String templateName { get; set; }
        @AuraEnabled public String templateDescription { get; set; }
        @AuraEnabled public Decimal complianceScore { get; set; }
        @AuraEnabled public Integer totalControls { get; set; }
        @AuraEnabled public Integer passedControls { get; set; }
        @AuraEnabled public Integer failedControls { get; set; }
        @AuraEnabled public Integer notApplicableControls { get; set; }
        @AuraEnabled public List<ComplianceControl> controls { get; set; }
        
        public ComplianceAssessment(String templateName) {
            this.templateName = templateName;
            this.complianceScore = 0;
            this.totalControls = 0;
            this.passedControls = 0;
            this.failedControls = 0;
            this.notApplicableControls = 0;
            this.controls = new List<ComplianceControl>();
        }
    }
    
    /**
     * @description Wrapper for available compliance templates
     */
    public class ComplianceTemplateInfo {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Integer controlCount { get; set; }
        
        public ComplianceTemplateInfo(String value, String label, String description, Integer controlCount) {
            this.value = value;
            this.label = label;
            this.description = description;
            this.controlCount = controlCount;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Public Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Returns list of available compliance templates
     * @return List<ComplianceTemplateInfo> Available templates
     */
    public static List<ComplianceTemplateInfo> getAvailableTemplates() {
        return new List<ComplianceTemplateInfo>{
            new ComplianceTemplateInfo(
                TEMPLATE_SOC2,
                'SOC 2 Type II',
                'Service Organization Control 2 - Trust Services Criteria for security, availability, and confidentiality.',
                getSOC2Controls().size()
            ),
            new ComplianceTemplateInfo(
                TEMPLATE_GDPR,
                'GDPR',
                'General Data Protection Regulation - EU data privacy and protection requirements.',
                getGDPRControls().size()
            ),
            new ComplianceTemplateInfo(
                TEMPLATE_HIPAA,
                'HIPAA',
                'Health Insurance Portability and Accountability Act - US healthcare data protection.',
                getHIPAAControls().size()
            ),
            new ComplianceTemplateInfo(
                TEMPLATE_ISO27001,
                'ISO 27001',
                'International standard for information security management systems (ISMS).',
                getISO27001Controls().size()
            )
        };
    }
    
    /**
     * @description Runs a compliance assessment against a specific template
     * @param templateName Name of the compliance template to use
     * @param auditResults List of FoxSecResult from audit execution
     * @return ComplianceAssessment Results of the compliance check
     */
    public static ComplianceAssessment runComplianceAssessment(String templateName, 
                                                                List<FoxSecResult> auditResults) {
        List<ComplianceControl> controls = getTemplateControls(templateName);
        ComplianceAssessment assessment = new ComplianceAssessment(templateName);
        assessment.controls = controls;
        assessment.templateDescription = getTemplateDescription(templateName);
        
        // Create a map of test names to results for quick lookup
        Map<String, FoxSecResult> resultsByTestName = new Map<String, FoxSecResult>();
        if (auditResults != null) {
            for (FoxSecResult result : auditResults) {
                if (String.isNotBlank(result.testName)) {
                    resultsByTestName.put(result.testName.toLowerCase(), result);
                }
            }
        }
        
        // Evaluate each control against audit results
        for (ComplianceControl control : assessment.controls) {
            evaluateControl(control, resultsByTestName);
            
            assessment.totalControls++;
            if (control.isPassed) {
                assessment.passedControls++;
            } else if (control.status == 'Not Applicable') {
                assessment.notApplicableControls++;
            } else {
                assessment.failedControls++;
            }
        }
        
        // Calculate compliance score
        Integer applicableControls = assessment.totalControls - assessment.notApplicableControls;
        if (applicableControls > 0) {
            assessment.complianceScore = ((Decimal)assessment.passedControls / applicableControls) * 100;
            assessment.complianceScore = assessment.complianceScore.setScale(2);
        }
        
        return assessment;
    }
    
    /**
     * @description Gets control definitions for a specific template
     * @param templateName Name of the compliance template
     * @return List<ComplianceControl> Controls for the template
     */
    public static List<ComplianceControl> getTemplateControls(String templateName) {
        switch on templateName {
            when 'SOC2' {
                return getSOC2Controls();
            }
            when 'GDPR' {
                return getGDPRControls();
            }
            when 'HIPAA' {
                return getHIPAAControls();
            }
            when 'ISO27001' {
                return getISO27001Controls();
            }
            when else {
                return new List<ComplianceControl>();
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // SOC2 Template Controls
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible
    private static List<ComplianceControl> getSOC2Controls() {
        return new List<ComplianceControl>{
            // CC6.1 - Logical Access
            new ComplianceControl(
                'CC6.1-1',
                'CC6.1 - Logical Access',
                'The entity implements logical access security measures to protect against threats.',
                'Shadow Admin Detection',
                'Direct'
            ),
            new ComplianceControl(
                'CC6.1-2',
                'CC6.1 - Logical Access',
                'Guest user access is appropriately restricted.',
                'Guest User Exposure',
                'Direct'
            ),
            new ComplianceControl(
                'CC6.1-3',
                'CC6.1 - Logical Access',
                'Sharing model ensures least privilege access.',
                'OWD Settings',
                'Direct'
            ),
            // CC6.2 - Authentication
            new ComplianceControl(
                'CC6.2-1',
                'CC6.2 - Authentication',
                'Strong password policies are enforced.',
                'Password Policy',
                'Direct'
            ),
            new ComplianceControl(
                'CC6.2-2',
                'CC6.2 - Authentication',
                'Session security is properly configured.',
                'Session Security',
                'Direct'
            ),
            // CC6.3 - System Operations
            new ComplianceControl(
                'CC6.3-1',
                'CC6.3 - System Operations',
                'Inactive API users are identified and managed.',
                'API Users Stale',
                'Direct'
            ),
            // CC6.6 - System Boundaries
            new ComplianceControl(
                'CC6.6-1',
                'CC6.6 - System Boundaries',
                'External connections use secure protocols.',
                'Remote Site HTTP',
                'Direct'
            ),
            new ComplianceControl(
                'CC6.6-2',
                'CC6.6 - System Boundaries',
                'CSP policies prevent unsafe content execution.',
                'CSP Trusted Site',
                'Direct'
            ),
            // CC6.7 - Change Management
            new ComplianceControl(
                'CC6.7-1',
                'CC6.7 - Change Management',
                'Certificate validity is monitored.',
                'Certificate Expiry',
                'Direct'
            )
        };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // GDPR Template Controls
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible
    private static List<ComplianceControl> getGDPRControls() {
        return new List<ComplianceControl>{
            // Article 25 - Data Protection by Design
            new ComplianceControl(
                'Art.25-1',
                'Article 25 - Data Protection by Design',
                'Default sharing settings minimize data exposure.',
                'OWD Settings',
                'Direct'
            ),
            new ComplianceControl(
                'Art.25-2',
                'Article 25 - Data Protection by Design',
                'Public file sharing is restricted.',
                'Public Files Exposure',
                'Direct'
            ),
            // Article 32 - Security of Processing
            new ComplianceControl(
                'Art.32-1',
                'Article 32 - Security of Processing',
                'Session security measures protect user sessions.',
                'Session Security',
                'Direct'
            ),
            new ComplianceControl(
                'Art.32-2',
                'Article 32 - Security of Processing',
                'SSL/TLS certificates are valid and monitored.',
                'Certificate Expiry',
                'Direct'
            ),
            new ComplianceControl(
                'Art.32-3',
                'Article 32 - Security of Processing',
                'Password policies enforce strong authentication.',
                'Password Policy',
                'Direct'
            ),
            // Article 5 - Data Minimization
            new ComplianceControl(
                'Art.5-1',
                'Article 5 - Data Minimization',
                'External sharing is limited to business necessity.',
                'External Sharing',
                'Direct'
            ),
            // Article 33 - Breach Notification
            new ComplianceControl(
                'Art.33-1',
                'Article 33 - Breach Notification',
                'Admin login capabilities are monitored.',
                'Admin Login As Any User',
                'Direct'
            )
        };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // HIPAA Template Controls
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible
    private static List<ComplianceControl> getHIPAAControls() {
        return new List<ComplianceControl>{
            // 164.312(a)(1) - Access Control
            new ComplianceControl(
                '164.312.a.1-1',
                '164.312(a)(1) - Access Control',
                'Unique user identification is implemented.',
                'Shadow Admin Detection',
                'Direct'
            ),
            new ComplianceControl(
                '164.312.a.1-2',
                '164.312(a)(1) - Access Control',
                'Automatic logoff is configured.',
                'Session Security',
                'Direct'
            ),
            // 164.312(b) - Audit Controls
            new ComplianceControl(
                '164.312.b-1',
                '164.312(b) - Audit Controls',
                'Admin activities can be monitored.',
                'Admin Login As Any User',
                'Direct'
            ),
            // 164.312(c)(1) - Integrity
            new ComplianceControl(
                '164.312.c.1-1',
                '164.312(c)(1) - Integrity',
                'Data integrity controls are in place.',
                'OWD Settings',
                'Direct'
            ),
            // 164.312(d) - Person or Entity Authentication
            new ComplianceControl(
                '164.312.d-1',
                '164.312(d) - Authentication',
                'Strong password requirements are enforced.',
                'Password Policy',
                'Direct'
            ),
            // 164.312(e)(1) - Transmission Security
            new ComplianceControl(
                '164.312.e.1-1',
                '164.312(e)(1) - Transmission Security',
                'HTTPS is required for remote connections.',
                'Remote Site HTTP',
                'Direct'
            ),
            new ComplianceControl(
                '164.312.e.1-2',
                '164.312(e)(1) - Transmission Security',
                'SSL certificates are valid.',
                'Certificate Expiry',
                'Direct'
            )
        };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // ISO 27001 Template Controls
    // ─────────────────────────────────────────────────────────────────────────────
    
    @TestVisible
    private static List<ComplianceControl> getISO27001Controls() {
        return new List<ComplianceControl>{
            // A.9 - Access Control
            new ComplianceControl(
                'A.9.1.1',
                'A.9.1 - Access Control Policy',
                'Access control policies are documented and implemented.',
                'OWD Settings',
                'Direct'
            ),
            new ComplianceControl(
                'A.9.2.1',
                'A.9.2 - User Access Management',
                'User registration and de-registration processes exist.',
                'API Users Stale',
                'Direct'
            ),
            new ComplianceControl(
                'A.9.2.3',
                'A.9.2 - Privileged Access',
                'Privileged access rights are managed and reviewed.',
                'Shadow Admin Detection',
                'Direct'
            ),
            new ComplianceControl(
                'A.9.4.1',
                'A.9.4 - System and Application Access',
                'Access to systems is restricted and controlled.',
                'Guest User Exposure',
                'Direct'
            ),
            // A.10 - Cryptography
            new ComplianceControl(
                'A.10.1.1',
                'A.10.1 - Cryptographic Controls',
                'Cryptographic controls protect data in transit.',
                'Remote Site HTTP',
                'Direct'
            ),
            new ComplianceControl(
                'A.10.1.2',
                'A.10.1 - Key Management',
                'Certificate lifecycle is managed.',
                'Certificate Expiry',
                'Direct'
            ),
            // A.13 - Communications Security
            new ComplianceControl(
                'A.13.1.1',
                'A.13.1 - Network Security',
                'Network security controls protect data flows.',
                'CSP Trusted Site',
                'Direct'
            ),
            // A.18 - Compliance
            new ComplianceControl(
                'A.18.1.3',
                'A.18.1 - Protection of Records',
                'Records are protected from unauthorized access.',
                'External Sharing',
                'Direct'
            )
        };
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Private Helper Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Evaluates a control against audit results
     * @param control The control to evaluate
     * @param resultsByTestName Map of test names to results
     */
    private static void evaluateControl(ComplianceControl control, 
                                         Map<String, FoxSecResult> resultsByTestName) {
        // Find matching audit result by looking for test name in the results
        String testNameLower = control.foxSecTest.toLowerCase();
        FoxSecResult matchingResult = null;
        
        // Search for partial match (test name contains the compliance test reference)
        for (String resultTestName : resultsByTestName.keySet()) {
            if (resultTestName.contains(testNameLower) || 
                testNameLower.contains(resultTestName.substringBefore(' - ').toLowerCase())) {
                matchingResult = resultsByTestName.get(resultTestName);
                break;
            }
        }
        
        if (matchingResult == null) {
            control.status = 'Not Evaluated';
            control.isPassed = false;
            return;
        }
        
        // Evaluate based on audit result status
        String status = matchingResult.status;
        if (status == FoxSecResult.STATUS_PASS) {
            control.status = 'Compliant';
            control.isPassed = true;
        } else if (status == FoxSecResult.STATUS_WARNING) {
            control.status = 'Partial Compliance';
            control.isPassed = false;
        } else if (status == FoxSecResult.STATUS_CRITICAL) {
            control.status = 'Non-Compliant';
            control.isPassed = false;
        } else if (status == FoxSecResult.STATUS_SKIPPED || status == FoxSecResult.STATUS_INFO) {
            control.status = 'Not Applicable';
            control.isPassed = false;
        }
    }
    
    /**
     * @description Gets description for a compliance template
     * @param templateName Name of the template
     * @return String Template description
     */
    private static String getTemplateDescription(String templateName) {
        switch on templateName {
            when 'SOC2' {
                return 'Service Organization Control 2 - Trust Services Criteria';
            }
            when 'GDPR' {
                return 'General Data Protection Regulation - EU Privacy Requirements';
            }
            when 'HIPAA' {
                return 'Health Insurance Portability and Accountability Act';
            }
            when 'ISO27001' {
                return 'ISO/IEC 27001 - Information Security Management';
            }
            when else {
                return 'Custom Compliance Assessment';
            }
        }
    }
}
