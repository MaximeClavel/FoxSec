// File: force-app/main/default/lwc/foxSecDashboard/foxSecDashboard.js
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAuditSummary from '@salesforce/apex/FoxSecController.getAuditSummary';

// Status constants matching Apex FoxSecResult
const STATUS_CRITICAL = 'CRITICAL';
const STATUS_WARNING = 'WARNING';
const STATUS_PASS = 'PASS';
const STATUS_SKIPPED = 'SKIPPED';
const STATUS_INFO = 'INFO';

// Gauge arc length (semicircle from M 20 100 A 80 80 0 0 1 180 100)
const GAUGE_ARC_LENGTH = 251.33;

/**
 * @description Main dashboard component for FoxSec security audits.
 * Displays a security score gauge and detailed audit results in a data table.
 */
export default class FoxSecDashboard extends LightningElement {
    // Audit summary data
    @track score = 0;
    @track criticalCount = 0;
    @track warningCount = 0;
    @track passCount = 0;
    @track skippedCount = 0;
    @track totalTests = 0;
    @track tableData = [];

    // UI state
    @track isLoading = true;
    @track error = null;
    @track sortedBy = 'status';
    @track sortedDirection = 'asc';

    // Wire result for refresh capability
    wiredAuditResult;

    /**
     * @description Table columns definition with custom badge rendering
     */
    columns = [
        {
            label: 'Test Name',
            fieldName: 'testName',
            type: 'text',
            sortable: true,
            wrapText: true,
            initialWidth: 280
        },
        {
            label: 'Impact',
            fieldName: 'status',
            type: 'text',
            sortable: true,
            initialWidth: 120,
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            }
        },
        {
            label: 'Message',
            fieldName: 'message',
            type: 'text',
            wrapText: true,
            sortable: true
        },
        {
            label: 'Remediation Steps',
            fieldName: 'remediationSteps',
            type: 'text',
            wrapText: true,
            initialWidth: 350
        }
    ];

    /**
     * @description Wire adapter to fetch audit summary from Apex controller
     */
    @wire(getAuditSummary)
    wiredGetAuditSummary(result) {
        this.wiredAuditResult = result;
        const { data, error } = result;

        if (data) {
            this.processAuditData(data);
            this.error = null;
        } else if (error) {
            this.handleError(error);
        }
        this.isLoading = false;
    }

    /**
     * @description Process the audit summary data from Apex
     * @param {Object} data - AuditSummary object from Apex
     */
    processAuditData(data) {
        this.score = data.score;
        this.criticalCount = data.criticalCount;
        this.warningCount = data.warningCount;
        this.passCount = data.passCount;
        this.skippedCount = data.skippedCount;
        this.totalTests = data.totalTests;

        // Transform results for datatable with unique IDs and status styling
        this.tableData = data.results.map((result, index) => ({
            id: `result-${index}`,
            testName: result.testName || 'Unknown Test',
            status: result.status || STATUS_INFO,
            message: result.message || '',
            remediationSteps: result.remediationSteps || '-',
            statusClass: this.getStatusClass(result.status),
            sortOrder: this.getStatusSortOrder(result.status)
        }));

        // Apply default sort
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    /**
     * @description Get CSS class for status badge styling
     * @param {String} status - The audit result status
     * @returns {String} CSS class for the status
     */
    getStatusClass(status) {
        switch (status) {
            case STATUS_CRITICAL:
                return 'slds-badge slds-badge_inverse badge-critical';
            case STATUS_WARNING:
                return 'slds-badge badge-warning';
            case STATUS_PASS:
                return 'slds-badge badge-pass';
            case STATUS_SKIPPED:
            case STATUS_INFO:
                return 'slds-badge badge-info';
            default:
                return 'slds-badge';
        }
    }

    /**
     * @description Get sort order priority for status column
     * @param {String} status - The audit result status
     * @returns {Number} Sort priority (lower = higher priority)
     */
    getStatusSortOrder(status) {
        switch (status) {
            case STATUS_CRITICAL:
                return 1;
            case STATUS_WARNING:
                return 2;
            case STATUS_PASS:
                return 3;
            case STATUS_SKIPPED:
                return 4;
            case STATUS_INFO:
                return 5;
            default:
                return 6;
        }
    }

    /**
     * @description Handle errors from wire adapter
     * @param {Object} error - Error object from Apex
     */
    handleError(error) {
        this.error = error;
        this.score = 0;
        this.criticalCount = 0;
        this.warningCount = 0;
        this.passCount = 0;
        this.skippedCount = 0;
        this.totalTests = 0;
        this.tableData = [];
    }

    /**
     * @description Computed property for error message display
     */
    get errorMessage() {
        if (!this.error) return '';
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        if (this.error.message) {
            return this.error.message;
        }
        return 'An unexpected error occurred while running the security audit.';
    }

    /**
     * @description Computed property to check if data is available
     */
    get hasData() {
        return !this.isLoading && !this.error;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Gauge Chart Computed Properties
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Calculate stroke-dasharray for the gauge arc
     */
    get gaugeDashArray() {
        return `${GAUGE_ARC_LENGTH} ${GAUGE_ARC_LENGTH}`;
    }

    /**
     * @description Calculate stroke-dashoffset based on score (0-100)
     */
    get gaugeDashOffset() {
        const percentage = Math.min(100, Math.max(0, this.score)) / 100;
        const offset = GAUGE_ARC_LENGTH * (1 - percentage);
        return offset;
    }

    /**
     * @description Get gauge color class based on score
     */
    get gaugeColorClass() {
        if (this.score >= 80) {
            return 'gauge-stroke gauge-stroke-success';
        } else if (this.score >= 50) {
            return 'gauge-stroke gauge-stroke-warning';
        }
        return 'gauge-stroke gauge-stroke-critical';
    }

    /**
     * @description Get score text color class based on score
     */
    get scoreTextClass() {
        if (this.score >= 80) {
            return 'gauge-score-value score-success';
        } else if (this.score >= 50) {
            return 'gauge-score-value score-warning';
        }
        return 'gauge-score-value score-critical';
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Event Handlers
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * @description Handle refresh button click
     */
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredAuditResult);
    }

    /**
     * @description Handle column sort event
     * @param {Event} event - Sort event from datatable
     */
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortData(fieldName, sortDirection);
    }

    /**
     * @description Sort table data by specified field
     * @param {String} fieldName - Field to sort by
     * @param {String} direction - Sort direction ('asc' or 'desc')
     */
    sortData(fieldName, direction) {
        const parseData = JSON.parse(JSON.stringify(this.tableData));
        const isReverse = direction === 'asc' ? 1 : -1;

        // Special handling for status column - sort by severity order
        const sortField = fieldName === 'status' ? 'sortOrder' : fieldName;

        parseData.sort((a, b) => {
            const valueA = a[sortField] || '';
            const valueB = b[sortField] || '';

            if (typeof valueA === 'number' && typeof valueB === 'number') {
                return isReverse * (valueA - valueB);
            }

            return isReverse * String(valueA).localeCompare(String(valueB));
        });

        this.tableData = parseData;
    }
}
