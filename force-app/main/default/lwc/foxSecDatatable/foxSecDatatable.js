// File: force-app/main/default/lwc/foxSecDatatable/foxSecDatatable.js
import LightningDatatable from 'lightning/datatable';
import impactBadgeTemplate from './impactBadgeTemplate.html';

/**
 * @description Extended datatable component that supports custom cell types.
 * Adds 'impactBadge' type for rendering severity badges with proper styling.
 */
export default class FoxSecDatatable extends LightningDatatable {
    static customTypes = {
        impactBadge: {
            template: impactBadgeTemplate,
            standardCellLayout: true,
            typeAttributes: ['status']
        }
    };
}
