// File: force-app/main/default/lwc/impactBadge/impactBadge.js
import { LightningElement, api } from 'lwc';

/**
 * @description Custom badge component for displaying impact severity in datatable.
 * Provides full control over styling since it's not inside Shadow DOM of lightning-datatable.
 */
export default class ImpactBadge extends LightningElement {
    @api value;

    /**
     * @description Get the appropriate CSS class based on the impact value
     */
    get badgeClass() {
        const baseClass = 'impact-badge';
        switch (this.value) {
            case 'CRITICAL':
                return `${baseClass} impact-critical`;
            case 'WARNING':
                return `${baseClass} impact-warning`;
            case 'PASS':
                return `${baseClass} impact-pass`;
            case 'SKIPPED':
            case 'INFO':
                return `${baseClass} impact-info`;
            default:
                return baseClass;
        }
    }
}
