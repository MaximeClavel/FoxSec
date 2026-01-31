// File: force-app/main/default/classes/core/IFoxSecAuditor.cls
/**
 * @description Interface defining the contract for all FoxSec audit engines.
 * Each audit module must implement this interface to be compatible with the framework.
 * @author FoxSec Team
 * @date 2026-01-30
 */
public interface IFoxSecAuditor {
    
    /**
     * @description Executes the security audit and returns findings
     * @return List of FoxSecResult objects containing audit findings
     */
    List<FoxSecResult> executeAudit();
}