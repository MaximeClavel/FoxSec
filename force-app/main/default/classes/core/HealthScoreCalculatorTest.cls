// File: force-app/main/default/classes/core/HealthScoreCalculatorTest.cls
/**
 * @description Test class for HealthScoreCalculator
 * @author FoxSec Team
 * @date 2026-02-04
 */
@IsTest
private class HealthScoreCalculatorTest {

    @IsTest
    static void testCalculateScore_WithCriticalFindings() {
        // Given - 3 CRITICAL findings
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_CRITICAL, 'Critical issue 1', 'Fix it'),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_CRITICAL, 'Critical issue 2', 'Fix it'),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_CRITICAL, 'Critical issue 3', 'Fix it'),
            new FoxSecResult('Test 4', FoxSecResult.STATUS_PASS, 'Passed', null)
        };
        
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(results);
        Test.stopTest();
        
        // Then - 3 critical × 15 = 45 deduction (below cap of 60)
        System.assertEquals(55, scoreResult.score, 'Score should be 55 (100 - 45)');
        System.assertEquals(3, scoreResult.criticalCount, 'Should have 3 critical');
        System.assertEquals(1, scoreResult.passCount, 'Should have 1 pass');
        System.assertEquals('C', scoreResult.grade, 'Grade should be C');
        System.assertEquals('orange', scoreResult.gradeColor, 'Color should be orange');
    }

    @IsTest
    static void testCalculateScore_CriticalCap() {
        // Given - 6 CRITICAL findings (should hit cap)
        List<FoxSecResult> results = new List<FoxSecResult>();
        for (Integer i = 0; i < 6; i++) {
            results.add(new FoxSecResult('Test ' + i, FoxSecResult.STATUS_CRITICAL, 'Critical', 'Fix'));
        }
        
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(results);
        Test.stopTest();
        
        // Then - 6 × 15 = 90, but capped at 60
        System.assertEquals(40, scoreResult.score, 'Score should be 40 (100 - 60 cap)');
        System.assertEquals(60, scoreResult.criticalDeduction, 'Critical deduction should be capped at 60');
        System.assertEquals('D', scoreResult.grade, 'Grade should be D');
    }

    @IsTest
    static void testCalculateScore_MixedFindings() {
        // Given - Mixed findings
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_CRITICAL, 'Critical', 'Fix'),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_WARNING, 'Warning', 'Review'),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_WARNING, 'Warning', 'Review'),
            new FoxSecResult('Test 4', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 5', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 6', FoxSecResult.STATUS_INFO, 'Info', null)
        };
        
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(results);
        Test.stopTest();
        
        // Then - 1 critical (15) + 2 warnings mapped to high (16) = 31
        System.assertEquals(69, scoreResult.score, 'Score should be 69');
        System.assertEquals(1, scoreResult.criticalCount, 'Should have 1 critical');
        System.assertEquals(2, scoreResult.highCount, 'Should have 2 high (warnings)');
        System.assertEquals(2, scoreResult.passCount, 'Should have 2 pass');
        System.assertEquals(1, scoreResult.skippedCount, 'Should have 1 skipped (info)');
        System.assertEquals('C', scoreResult.grade, 'Grade should be C');
    }

    @IsTest
    static void testCalculateScore_AllPass() {
        // Given - All passing tests
        List<FoxSecResult> results = new List<FoxSecResult>{
            new FoxSecResult('Test 1', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 2', FoxSecResult.STATUS_PASS, 'Passed', null),
            new FoxSecResult('Test 3', FoxSecResult.STATUS_PASS, 'Passed', null)
        };
        
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(results);
        Test.stopTest();
        
        // Then - Perfect score
        System.assertEquals(100, scoreResult.score, 'Score should be 100');
        System.assertEquals('A', scoreResult.grade, 'Grade should be A');
        System.assertEquals('green', scoreResult.gradeColor, 'Color should be green');
        System.assertEquals('Excellent security posture', scoreResult.gradeLabel, 'Should have excellent label');
    }

    @IsTest
    static void testCalculateScore_EmptyList() {
        // Given - Empty list
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(results);
        Test.stopTest();
        
        // Then - Perfect score for empty
        System.assertEquals(100, scoreResult.score, 'Score should be 100 for empty list');
        System.assertEquals(0, scoreResult.totalTests, 'Total tests should be 0');
    }

    @IsTest
    static void testCalculateScore_NullList() {
        // When
        Test.startTest();
        HealthScoreCalculator.HealthScoreResult scoreResult = 
            HealthScoreCalculator.calculateScore(null);
        Test.stopTest();
        
        // Then - Perfect score for null
        System.assertEquals(100, scoreResult.score, 'Score should be 100 for null');
    }

    @IsTest
    static void testGetGrade_AllGrades() {
        // Test all grade thresholds
        System.assertEquals('A', HealthScoreCalculator.getGrade(100), 'Score 100 = A');
        System.assertEquals('A', HealthScoreCalculator.getGrade(90), 'Score 90 = A');
        System.assertEquals('B', HealthScoreCalculator.getGrade(89), 'Score 89 = B');
        System.assertEquals('B', HealthScoreCalculator.getGrade(75), 'Score 75 = B');
        System.assertEquals('C', HealthScoreCalculator.getGrade(74), 'Score 74 = C');
        System.assertEquals('C', HealthScoreCalculator.getGrade(60), 'Score 60 = C');
        System.assertEquals('D', HealthScoreCalculator.getGrade(59), 'Score 59 = D');
        System.assertEquals('D', HealthScoreCalculator.getGrade(40), 'Score 40 = D');
        System.assertEquals('F', HealthScoreCalculator.getGrade(39), 'Score 39 = F');
        System.assertEquals('F', HealthScoreCalculator.getGrade(0), 'Score 0 = F');
    }

    @IsTest
    static void testGetGradeInfo() {
        // When
        Test.startTest();
        HealthScoreCalculator.GradeInfo infoA = HealthScoreCalculator.getGradeInfo(95);
        HealthScoreCalculator.GradeInfo infoF = HealthScoreCalculator.getGradeInfo(20);
        Test.stopTest();
        
        // Then
        System.assertEquals('A', infoA.grade, 'Grade should be A');
        System.assertEquals('green', infoA.color, 'Color should be green');
        System.assertNotEquals(null, infoA.label, 'Label should not be null');
        
        System.assertEquals('F', infoF.grade, 'Grade should be F');
        System.assertEquals('black', infoF.color, 'Color should be black');
    }

    @IsTest
    static void testCalculateSimpleScore() {
        // When
        Test.startTest();
        Integer score1 = HealthScoreCalculator.calculateSimpleScore(2, 3);
        Integer score2 = HealthScoreCalculator.calculateSimpleScore(10, 10);
        Test.stopTest();
        
        // Then
        // 2 critical × 15 = 30, 3 warning × 8 = 24 = 54 deduction
        System.assertEquals(46, score1, 'Score should be 46');
        
        // 10 critical = 60 (capped), 10 warning = 80 but capped at 40 = 100 deduction = 0
        System.assertEquals(0, score2, 'Score should be 0 (minimum)');
    }
}
