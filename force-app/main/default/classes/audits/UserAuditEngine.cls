// File: force-app/main/default/classes/audits/UserAuditEngine.cls
/**
 * @description Audit engine for Identity & Access Management security.
 * Scans users, profiles, permission sets for excessive privileges.
 * All operations are read-only and respect user permissions.
 * @author FoxSec Team
 * @date 2026-01-31
 */
public with sharing class UserAuditEngine implements IFoxSecAuditor {

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────────
    
    private static final String AUDIT_CATEGORY = 'Identity & Access Management';
    
    // Test names
    @TestVisible private static final String TEST_SHADOW_ADMINS = 'Shadow Admins - Excessive Privileges';
    @TestVisible private static final String TEST_STALE_API_USERS = 'API Users - Stale Accounts';
    @TestVisible private static final String TEST_WEAK_PASSWORD = 'Password Policy - Never Expires';
    @TestVisible private static final String TEST_GUEST_USER_EXPOSURE = 'Guest User - Excessive Permissions';
    
    // Critical system permissions that indicate admin-level access
    @TestVisible private static final Set<String> CRITICAL_PERMISSIONS = new Set<String>{
        'PermissionsAuthorApex',
        'PermissionsCustomizeApplication',
        'PermissionsManageUsers',
        'PermissionsViewAllData',
        'PermissionsModifyAllData'
    };
    
    // Profile names that are expected to have admin permissions
    private static final Set<String> ADMIN_PROFILE_NAMES = new Set<String>{
        'System Administrator',
        'Administrateur système',
        'Systemadministrator'
    };
    
    // Stale threshold in days for API users
    @TestVisible private static final Integer STALE_DAYS_THRESHOLD = 90;
    
    // Query limit to prevent governor limit issues
    private static final Integer USER_QUERY_LIMIT = 2000;
    private static final Integer ASSIGNMENT_QUERY_LIMIT = 5000;

    // ─────────────────────────────────────────────────────────────────────────────
    // IFoxSecAuditor Implementation
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Executes all IAM security audits.
     * @return List<FoxSecResult> Aggregated findings from all checks.
     */
    public List<FoxSecResult> executeAudit() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        // Shadow Admin detection
        results.addAll(auditShadowAdmins());
        
        // Stale API users check
        results.addAll(auditStaleApiUsers());
        
        // Weak password policy check
        results.addAll(auditWeakPasswordPolicies());
        
        // Guest user exposure check
        results.addAll(auditGuestUserExposure());
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Shadow Admin Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Detects "Shadow Admins" - non-admin users with critical system permissions.
     * Checks both Profile and PermissionSet assignments for dangerous permissions.
     * @return List<FoxSecResult> Shadow admin findings.
     */
    @TestVisible
    private List<FoxSecResult> auditShadowAdmins() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Step 1: Find non-admin profiles with critical permissions
            Map<Id, Profile> riskyProfiles = findRiskyProfiles();
            
            // Step 2: Find permission sets with critical permissions
            Map<Id, PermissionSet> riskyPermSets = findRiskyPermissionSets();
            
            // Step 3: Find active non-admin users with these profiles
            Set<Id> shadowAdminUserIds = new Set<Id>();
            Map<Id, List<String>> userPermissionSources = new Map<Id, List<String>>();
            
            // Check users via risky profiles
            if (!riskyProfiles.isEmpty()) {
                for (User u : [
                    SELECT Id, Username, Profile.Name
                    FROM User
                    WHERE IsActive = true
                    AND ProfileId IN :riskyProfiles.keySet()
                    WITH USER_MODE
                    LIMIT :USER_QUERY_LIMIT
                ]) {
                    shadowAdminUserIds.add(u.Id);
                    String profileName = (u.Profile != null && u.Profile.Name != null) ? u.Profile.Name : 'N/A';
                    String source = 'Profile: ' + profileName;
                    if (!userPermissionSources.containsKey(u.Id)) {
                        userPermissionSources.put(u.Id, new List<String>());
                    }
                    userPermissionSources.get(u.Id).add(source);
                }
            }
            
            // Step 4: Check permission set assignments for risky permission sets
            if (!riskyPermSets.isEmpty()) {
                for (PermissionSetAssignment psa : [
                    SELECT AssigneeId, Assignee.Username, PermissionSetId, PermissionSet.Name,
                           Assignee.Profile.Name
                    FROM PermissionSetAssignment
                    WHERE PermissionSetId IN :riskyPermSets.keySet()
                    AND Assignee.IsActive = true
                    AND Assignee.Profile.Name NOT IN :ADMIN_PROFILE_NAMES
                    WITH USER_MODE
                    LIMIT :ASSIGNMENT_QUERY_LIMIT
                ]) {
                    shadowAdminUserIds.add(psa.AssigneeId);
                    String source = 'PermissionSet: ' + psa.PermissionSet.Name;
                    if (!userPermissionSources.containsKey(psa.AssigneeId)) {
                        userPermissionSources.put(psa.AssigneeId, new List<String>());
                    }
                    userPermissionSources.get(psa.AssigneeId).add(source);
                }
            }
            
            // Step 5: Report findings
            if (shadowAdminUserIds.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_SHADOW_ADMINS,
                    FoxSecResult.STATUS_PASS,
                    'No shadow admin detected. Critical permissions are limited to admin profiles.',
                    null
                ));
            } else {
                // Get user details for reporting
                Map<Id, User> shadowAdmins = new Map<Id, User>([
                    SELECT Id, Username, Name, Profile.Name, LastLoginDate
                    FROM User
                    WHERE Id IN :shadowAdminUserIds
                    WITH USER_MODE
                ]);
                
                for (User u : shadowAdmins.values()) {
                    List<String> sources = userPermissionSources.get(u.Id);
                    String sourcesStr = sources != null ? String.join(sources, ', ') : 'Unknown';
                    String profileName = (u.Profile != null && u.Profile.Name != null) 
                        ? String.escapeSingleQuotes(u.Profile.Name) 
                        : 'N/A';
                    
                    results.add(new FoxSecResult(
                        TEST_SHADOW_ADMINS,
                        FoxSecResult.STATUS_CRITICAL,
                        'Shadow Admin detected: "' + String.escapeSingleQuotes(u.Username) + 
                        '" (Profile: ' + profileName + 
                        ') has critical permissions via: ' + sourcesStr,
                        'Review and remove unnecessary privileges. ' +
                        'Setup > Users > ' + String.escapeSingleQuotes(u.Name) + 
                        ' > Permission Set Assignments'
                    ));
                }
                
                // Summary result
                results.add(new FoxSecResult(
                    TEST_SHADOW_ADMINS,
                    FoxSecResult.STATUS_CRITICAL,
                    'Total shadow admins found: ' + shadowAdminUserIds.size() + 
                    '. These users have admin-level permissions without System Administrator profile.',
                    'Principle of Least Privilege: Remove AuthorApex, CustomizeApplication, ' +
                    'ManageUsers, ViewAllData, ModifyAllData from non-admin users.'
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_SHADOW_ADMINS,
                'Error querying user permissions: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_SHADOW_ADMINS,
                'Access denied to User/Profile/PermissionSet objects.'
            ));
        }
        
        return results;
    }
    
    /**
     * @description Finds profiles (non-admin) with critical permissions.
     * @return Map<Id, Profile> Profiles with dangerous permissions.
     */
    private Map<Id, Profile> findRiskyProfiles() {
        // Query profiles with critical permissions, excluding known admin profiles
        // We use dynamic SOQL approach to check specific permission fields
        return new Map<Id, Profile>([
            SELECT Id, Name,
                   PermissionsAuthorApex, PermissionsCustomizeApplication,
                   PermissionsManageUsers, PermissionsViewAllData, PermissionsModifyAllData
            FROM Profile
            WHERE Name NOT IN :ADMIN_PROFILE_NAMES
            AND (
                PermissionsAuthorApex = true
                OR PermissionsCustomizeApplication = true
                OR PermissionsManageUsers = true
                OR PermissionsViewAllData = true
                OR PermissionsModifyAllData = true
            )
            WITH USER_MODE
        ]);
    }
    
    /**
     * @description Finds permission sets (non-profile-based) with critical permissions.
     * @return Map<Id, PermissionSet> Permission sets with dangerous permissions.
     */
    private Map<Id, PermissionSet> findRiskyPermissionSets() {
        // Query permission sets with critical permissions
        // Exclude permission sets that are actually profiles (IsOwnedByProfile = true)
        return new Map<Id, PermissionSet>([
            SELECT Id, Name, Label,
                   PermissionsAuthorApex, PermissionsCustomizeApplication,
                   PermissionsManageUsers, PermissionsViewAllData, PermissionsModifyAllData
            FROM PermissionSet
            WHERE IsOwnedByProfile = false
            AND (
                PermissionsAuthorApex = true
                OR PermissionsCustomizeApplication = true
                OR PermissionsManageUsers = true
                OR PermissionsViewAllData = true
                OR PermissionsModifyAllData = true
            )
            WITH USER_MODE
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Stale API Users Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Identifies API-only users who haven't logged in for 90+ days.
     * These accounts are a security risk if credentials are compromised.
     * @return List<FoxSecResult> Stale API user findings.
     */
    @TestVisible
    private List<FoxSecResult> auditStaleApiUsers() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            Date staleThreshold = Date.today().addDays(-STALE_DAYS_THRESHOLD);
            
            // Query users with ApiEnabled permission via Profile or PermissionSet
            // First, find profiles with API enabled
            Set<Id> apiEnabledProfileIds = new Set<Id>();
            for (Profile p : [
                SELECT Id 
                FROM Profile 
                WHERE PermissionsApiEnabled = true
                WITH USER_MODE
            ]) {
                apiEnabledProfileIds.add(p.Id);
            }
            
            // Query active users with API access who haven't logged in recently
            // Using optimized query with date filter in WHERE clause
            List<User> staleApiUsers = [
                SELECT Id, Username, Name, Profile.Name, LastLoginDate, CreatedDate
                FROM User
                WHERE IsActive = true
                AND ProfileId IN :apiEnabledProfileIds
                AND (
                    LastLoginDate < :staleThreshold
                    OR LastLoginDate = null
                )
                WITH USER_MODE
                LIMIT :USER_QUERY_LIMIT
            ];
            
            // Also check users with API permission via PermissionSet
            Set<Id> permSetApiUserIds = new Set<Id>();
            for (PermissionSetAssignment psa : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSet.PermissionsApiEnabled = true
                AND PermissionSet.IsOwnedByProfile = false
                AND Assignee.IsActive = true
                AND (
                    Assignee.LastLoginDate < :staleThreshold
                    OR Assignee.LastLoginDate = null
                )
                WITH USER_MODE
                LIMIT :ASSIGNMENT_QUERY_LIMIT
            ]) {
                permSetApiUserIds.add(psa.AssigneeId);
            }
            
            // Combine results and deduplicate
            Set<Id> allStaleApiUserIds = new Set<Id>();
            for (User u : staleApiUsers) {
                allStaleApiUserIds.add(u.Id);
            }
            allStaleApiUserIds.addAll(permSetApiUserIds);
            
            if (allStaleApiUserIds.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_STALE_API_USERS,
                    FoxSecResult.STATUS_PASS,
                    'No stale API users detected. All API-enabled users have logged in within ' + 
                    STALE_DAYS_THRESHOLD + ' days.',
                    null
                ));
            } else {
                // Get full details for reporting
                Map<Id, User> staleUsers = new Map<Id, User>([
                    SELECT Id, Username, Name, Profile.Name, LastLoginDate, CreatedDate
                    FROM User
                    WHERE Id IN :allStaleApiUserIds
                    WITH USER_MODE
                ]);
                
                Integer neverLoggedIn = 0;
                Integer staleCount = 0;
                
                for (User u : staleUsers.values()) {
                    String lastLoginStr;
                    String severity;
                    
                    if (u.LastLoginDate == null) {
                        neverLoggedIn++;
                        lastLoginStr = 'NEVER (created: ' + u.CreatedDate.format() + ')';
                        severity = FoxSecResult.STATUS_CRITICAL;
                    } else {
                        staleCount++;
                        Integer daysSinceLogin = u.LastLoginDate.date().daysBetween(Date.today());
                        lastLoginStr = u.LastLoginDate.format() + ' (' + daysSinceLogin + ' days ago)';
                        severity = FoxSecResult.STATUS_WARNING;
                    }
                    
                    results.add(new FoxSecResult(
                        TEST_STALE_API_USERS,
                        severity,
                        'Stale API user: "' + String.escapeSingleQuotes(u.Username) + 
                        '" - Last login: ' + lastLoginStr,
                        'Review API user necessity. Deactivate or rotate credentials if unused. ' +
                        'Setup > Users > ' + String.escapeSingleQuotes(u.Name)
                    ));
                }
                
                // Summary
                results.add(new FoxSecResult(
                    TEST_STALE_API_USERS,
                    neverLoggedIn > 0 ? FoxSecResult.STATUS_CRITICAL : FoxSecResult.STATUS_WARNING,
                    'Total stale API users: ' + allStaleApiUserIds.size() + 
                    ' (' + neverLoggedIn + ' never logged in, ' + staleCount + ' inactive > ' + 
                    STALE_DAYS_THRESHOLD + ' days)',
                    'API users with unused credentials are attack vectors. ' +
                    'Implement regular access reviews and deactivate unused accounts.'
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_STALE_API_USERS,
                'Error querying API users: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_STALE_API_USERS,
                'Access denied to User object.'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Weak Password Policy Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Identifies users with "Password Never Expires" setting.
     * This is a security risk as it allows indefinite credential validity.
     * @return List<FoxSecResult> Password policy findings.
     */
    @TestVisible
    private List<FoxSecResult> auditWeakPasswordPolicies() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Query profiles where PasswordNeverExpires could be configured
            // Note: This is controlled at Profile level in some cases
            // and org-wide via Password Policies in Setup
            
            // Check for users with UserPreferencesPasswordNeverExpires (if accessible)
            // Note: This field may not be directly exposed; we check what's available
            
            // Approach: Query org-level password policy info
            // Password policies are typically set at org level, not user level in modern SF
            
            // Check profiles that might have weak password settings
            List<Profile> profiles = [
                SELECT Id, Name, Description
                FROM Profile
                WHERE Name != null
                WITH USER_MODE
                LIMIT 100
            ];
            
            // Since direct password policy fields aren't available on User/Profile via SOQL,
            // we provide guidance and check what we can
            
            // Check if there are Integration users (often configured with non-expiring passwords)
            List<User> integrationUsers = [
                SELECT Id, Username, Name, Profile.Name, UserType
                FROM User
                WHERE IsActive = true
                AND (
                    Username LIKE '%integration%'
                    OR Username LIKE '%api%'
                    OR Username LIKE '%service%'
                    OR Username LIKE '%system%'
                    OR UserType = 'AutomatedProcess'
                )
                WITH USER_MODE
                LIMIT :USER_QUERY_LIMIT
            ];
            
            if (integrationUsers.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_WEAK_PASSWORD,
                    FoxSecResult.STATUS_INFO,
                    'Password expiration policies are managed at the org level. ' +
                    'No obvious integration/service accounts detected.',
                    'Verify password policies: Setup > Security > Password Policies. ' +
                    'Ensure "User passwords expire in" is set (recommended: 90 days max).'
                ));
            } else {
                // Flag potential service accounts that may have non-expiring passwords
                results.add(new FoxSecResult(
                    TEST_WEAK_PASSWORD,
                    FoxSecResult.STATUS_WARNING,
                    'Found ' + integrationUsers.size() + ' potential integration/service accounts. ' +
                    'These often have non-expiring passwords configured.',
                    'Review password policies for service accounts. Consider using OAuth ' +
                    'instead of passwords. Setup > Security > Password Policies'
                ));
                
                for (User u : integrationUsers) {
                    String profileName = (u.Profile != null && u.Profile.Name != null) 
                        ? String.escapeSingleQuotes(u.Profile.Name) 
                        : 'N/A';
                    results.add(new FoxSecResult(
                        TEST_WEAK_PASSWORD,
                        FoxSecResult.STATUS_INFO,
                        'Service account identified: "' + String.escapeSingleQuotes(u.Username) + 
                        '" (Type: ' + u.UserType + ', Profile: ' + profileName + ')',
                        'Verify password policy for this account. Consider credential rotation.'
                    ));
                }
            }
            
            // General recommendation for org-level policy
            results.add(new FoxSecResult(
                TEST_WEAK_PASSWORD,
                FoxSecResult.STATUS_INFO,
                'Note: "Password Never Expires" is controlled at org-level Password Policies. ' +
                'This audit identified potential service accounts that may have special configurations.',
                'Check Setup > Security > Password Policies > "User passwords expire in". ' +
                'Recommended: 90 days or less. Never set to "Never expires" in production.'
            ));
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_WEAK_PASSWORD,
                'Error querying password policy data: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_WEAK_PASSWORD,
                'Access denied to User/Profile objects.'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Guest User Exposure Audit
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Identifies Guest Users with excessive permissions.
     * Guest users should have minimal read-only access.
     * @return List<FoxSecResult> Guest user exposure findings.
     */
    @TestVisible
    private List<FoxSecResult> auditGuestUserExposure() {
        List<FoxSecResult> results = new List<FoxSecResult>();
        
        try {
            // Find Guest users (Site/Community Guest users)
            List<User> guestUsers = [
                SELECT Id, Username, Name, Profile.Name, ProfileId, UserType
                FROM User
                WHERE UserType = 'Guest'
                AND IsActive = true
                WITH USER_MODE
                LIMIT 100
            ];
            
            if (guestUsers.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_PASS,
                    'No active Guest users detected.',
                    null
                ));
                return results;
            }
            
            // Collect Guest user profile IDs
            Set<Id> guestProfileIds = new Set<Id>();
            Map<Id, User> guestUsersByProfileId = new Map<Id, User>();
            for (User u : guestUsers) {
                guestProfileIds.add(u.ProfileId);
                guestUsersByProfileId.put(u.ProfileId, u);
            }
            
            // Check for write permissions on Guest profiles via ObjectPermissions
            List<ObjectPermissions> guestObjectPerms = [
                SELECT Id, ParentId, Parent.Profile.Name, SobjectType,
                       PermissionsCreate, PermissionsEdit, PermissionsDelete
                FROM ObjectPermissions
                WHERE ParentId IN (
                    SELECT Id FROM PermissionSet WHERE ProfileId IN :guestProfileIds
                )
                AND (
                    PermissionsCreate = true
                    OR PermissionsEdit = true
                    OR PermissionsDelete = true
                )
                WITH USER_MODE
                LIMIT 500
            ];
            
            // Also check Permission Sets assigned to Guest users
            Set<Id> guestUserIds = new Set<Id>();
            for (User u : guestUsers) {
                guestUserIds.add(u.Id);
            }
            
            List<PermissionSetAssignment> guestPermSetAssignments = [
                SELECT AssigneeId, PermissionSetId, PermissionSet.Name, PermissionSet.Label
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :guestUserIds
                AND PermissionSet.IsOwnedByProfile = false
                WITH USER_MODE
                LIMIT 500
            ];
            
            // Check object permissions on assigned permission sets
            Set<Id> assignedPermSetIds = new Set<Id>();
            for (PermissionSetAssignment psa : guestPermSetAssignments) {
                assignedPermSetIds.add(psa.PermissionSetId);
            }
            
            List<ObjectPermissions> permSetObjectPerms = new List<ObjectPermissions>();
            if (!assignedPermSetIds.isEmpty()) {
                permSetObjectPerms = [
                    SELECT Id, ParentId, Parent.Name, SobjectType,
                           PermissionsCreate, PermissionsEdit, PermissionsDelete
                    FROM ObjectPermissions
                    WHERE ParentId IN :assignedPermSetIds
                    AND (
                        PermissionsCreate = true
                        OR PermissionsEdit = true
                        OR PermissionsDelete = true
                    )
                    WITH USER_MODE
                    LIMIT 500
                ];
            }
            
            // Report findings
            Boolean foundCriticalIssue = false;
            Set<String> reportedObjects = new Set<String>();
            
            // Report profile-level write permissions
            for (ObjectPermissions op : guestObjectPerms) {
                String objectKey = op.SobjectType;
                if (reportedObjects.contains(objectKey)) {
                    continue;
                }
                reportedObjects.add(objectKey);
                
                foundCriticalIssue = true;
                List<String> perms = new List<String>();
                if (op.PermissionsCreate) perms.add('Create');
                if (op.PermissionsEdit) perms.add('Edit');
                if (op.PermissionsDelete) perms.add('Delete');
                
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_CRITICAL,
                    'Guest user has write access on object "' + 
                    String.escapeSingleQuotes(op.SobjectType) + '": ' + 
                    String.join(perms, ', ') + ' (via Profile)',
                    'Remove write permissions from Guest user profile. ' +
                    'Guest users should have minimal read-only access. ' +
                    'Setup > Profiles > [Guest Profile] > Object Settings'
                ));
            }
            
            // Report permission set write permissions
            for (ObjectPermissions op : permSetObjectPerms) {
                String objectKey = op.SobjectType + '_permset_' + op.ParentId;
                if (reportedObjects.contains(objectKey)) {
                    continue;
                }
                reportedObjects.add(objectKey);
                
                foundCriticalIssue = true;
                List<String> perms = new List<String>();
                if (op.PermissionsCreate) perms.add('Create');
                if (op.PermissionsEdit) perms.add('Edit');
                if (op.PermissionsDelete) perms.add('Delete');
                
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_CRITICAL,
                    'Guest user has write access on object "' + 
                    String.escapeSingleQuotes(op.SobjectType) + '": ' + 
                    String.join(perms, ', ') + ' (via PermissionSet: ' + 
                    String.escapeSingleQuotes(op.Parent.Name) + ')',
                    'Remove write permissions from Guest user permission sets. ' +
                    'Setup > Permission Sets > ' + String.escapeSingleQuotes(op.Parent.Name) + 
                    ' > Object Settings'
                ));
            }
            
            // Report permission set assignments to Guest users
            if (!guestPermSetAssignments.isEmpty()) {
                for (PermissionSetAssignment psa : guestPermSetAssignments) {
                    results.add(new FoxSecResult(
                        TEST_GUEST_USER_EXPOSURE,
                        FoxSecResult.STATUS_WARNING,
                        'Guest user has Permission Set assigned: "' + 
                        String.escapeSingleQuotes(psa.PermissionSet.Label) + 
                        '". Verify this is necessary.',
                        'Review all permission sets assigned to Guest users. ' +
                        'Setup > Users > [Guest User] > Permission Set Assignments'
                    ));
                }
            }
            
            // Summary
            if (foundCriticalIssue) {
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_CRITICAL,
                    'CRITICAL: ' + guestUsers.size() + ' Guest user(s) found with write permissions. ' +
                    'This is a major AppExchange security review blocker.',
                    'Guest users must have strictly minimal permissions (read-only on specific objects only). ' +
                    'Review: Setup > Sites > [Your Site] > Public Access Settings'
                ));
            } else if (!guestPermSetAssignments.isEmpty()) {
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_WARNING,
                    guestUsers.size() + ' Guest user(s) found with permission set assignments. ' +
                    'No write permissions detected, but review assignments.',
                    'Verify Guest user permission sets are strictly necessary.'
                ));
            } else {
                results.add(new FoxSecResult(
                    TEST_GUEST_USER_EXPOSURE,
                    FoxSecResult.STATUS_PASS,
                    guestUsers.size() + ' Guest user(s) found. No excessive write permissions detected.',
                    null
                ));
            }
            
        } catch (QueryException qe) {
            results.add(createSkippedResult(
                TEST_GUEST_USER_EXPOSURE,
                'Error querying Guest user permissions: ' + qe.getMessage()
            ));
        } catch (System.NoAccessException nae) {
            results.add(createSkippedResult(
                TEST_GUEST_USER_EXPOSURE,
                'Access denied to User/ObjectPermissions objects.'
            ));
        }
        
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Utility Methods
    // ─────────────────────────────────────────────────────────────────────────────
    
    /**
     * @description Creates a SKIPPED result for when audit cannot be performed.
     * @param testName The test that was skipped.
     * @param reason The reason for skipping.
     * @return FoxSecResult A SKIPPED status result.
     */
    private FoxSecResult createSkippedResult(String testName, String reason) {
        return new FoxSecResult(
            testName,
            FoxSecResult.STATUS_SKIPPED,
            reason,
            'Verify that the user has appropriate permissions (View Setup, Manage Users).'
        );
    }
}
