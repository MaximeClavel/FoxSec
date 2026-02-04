// File: force-app/main/default/lwc/foxSecDashboard/foxSecDashboard.js
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAuditSummary from '@salesforce/apex/FoxSecController.getAuditSummary';
import getComplianceTemplates from '@salesforce/apex/FoxSecController.getComplianceTemplates';
import runComplianceAssessment from '@salesforce/apex/FoxSecController.runComplianceAssessment';
import saveAuditSnapshot from '@salesforce/apex/FoxSecController.saveAuditSnapshot';
import getTrendAnalysis from '@salesforce/apex/FoxSecController.getTrendAnalysis';
import exportAuditToCSV from '@salesforce/apex/FoxSecController.exportAuditToCSV';
import exportAuditToExcel from '@salesforce/apex/FoxSecController.exportAuditToExcel';
import exportTrendDataToCSV from '@salesforce/apex/FoxSecController.exportTrendDataToCSV';

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
 * Phase 2: Includes Health Score, Compliance Assessment, Trend Analysis, and Export.
 */
export default class FoxSecDashboard extends LightningElement {
    // Audit summary data
    @track score = 0;
    @track grade = 'A';
    @track gradeColor = 'green';
    @track gradeLabel = 'Excellent security posture';
    @track criticalCount = 0;
    @track warningCount = 0;
    @track passCount = 0;
    @track skippedCount = 0;
    @track totalTests = 0;
    @track tableData = [];

    // UI state
    @track isLoading = true;
    @track isInitialLoading = true;
    @track error = null;
    @track sortedBy = 'status';
    @track sortedDirection = 'asc';
    @track activeTab = 'overview';

    // Compliance state
    @track selectedTemplate = '';
    @track complianceTemplateOptions = [];
    @track complianceData = null;
    @track complianceControlsData = [];

    // Trend state
    @track selectedTrendDays = '30';
    @track trendData = null;
    @track trendDataPoints = [];

    // Wire results for refresh capability
    wiredAuditResult;
    wiredTemplatesResult;
    wiredTrendResult;

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
     * @description Compliance table columns
     */
    complianceColumns = [
        { label: 'Control ID', fieldName: 'controlId', type: 'text', initialWidth: 120 },
        { label: 'Control Name', fieldName: 'controlName', type: 'text', initialWidth: 200 },
        { label: 'Requirement', fieldName: 'requirement', type: 'text', wrapText: true },
        { label: 'FoxSec Test', fieldName: 'foxSecTest', type: 'text', initialWidth: 180 },
        { 
            label: 'Status', 
            fieldName: 'status', 
            type: 'text', 
            initialWidth: 130,
            cellAttributes: { class: { fieldName: 'statusClass' } }
        }
    ];

    /**
     * @description Trend range options
     */
    trendRangeOptions = [
        { label: 'Last 7 days', value: '7' },
        { label: 'Last 30 days', value: '30' },
        { label: 'Last 90 days', value: '90' },
        { label: 'Last 180 days', value: '180' },
        { label: 'Last 365 days', value: '365' }
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
        this.isInitialLoading = false;
    }

    /**
     * @description Wire adapter to fetch compliance templates
     */
    @wire(getComplianceTemplates)
    wiredGetTemplates(result) {
        this.wiredTemplatesResult = result;
        const { data, error } = result;

        if (data) {
            this.complianceTemplateOptions = data.map(template => ({
                label: `${template.label} (${template.controlCount} controls)`,
                value: template.value,
                description: template.description
            }));
        } else if (error) {
            console.error('Error loading compliance templates:', error);
        }
    }

    /**
     * @description Wire adapter to fetch trend analysis
     */
    @wire(getTrendAnalysis, { days: '$selectedTrendDaysInt' })
    wiredGetTrend(result) {
        this.wiredTrendResult = result;
        const { data, error } = result;

        if (data) {
            this.processTrendData(data);
        } else if (error) {
            console.error('Error loading trend data:', error);
            this.trendData = null;
        }
    }

    /**
     * @description Get selected trend days as integer for wire
     */
    get selectedTrendDaysInt() {
        return parseInt(this.selectedTrendDays, 10);
    }

    /**
     * @description Process the audit summary data from Apex
     * @param {Object} data - AuditSummary object from Apex
     */
    processAuditData(data) {
        this.score = data.score;
        this.grade = data.grade || 'A';
        this.gradeColor = data.gradeColor || 'green';
        this.gradeLabel = data.gradeLabel || 'Excellent security posture';
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
     * @description Process trend analysis data
     * @param {Object} data - TrendAnalysis object from Apex
     */
    processTrendData(data) {
        this.trendData = data;
        
        if (data && data.dataPoints && data.dataPoints.length > 0) {
            // Add bar styles for visualization
            this.trendDataPoints = data.dataPoints.map(point => ({
                ...point,
                barStyle: `height: ${point.healthScore}%; background-color: ${this.getScoreColor(point.healthScore)};`
            }));
        } else {
            this.trendDataPoints = [];
        }
    }

    /**
     * @description Get color for score value
     */
    getScoreColor(score) {
        if (score >= 90) return '#04844b';
        if (score >= 75) return '#ff9a3c';
        if (score >= 60) return '#ff6d3d';
        return '#c23934';
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
        return !this.isInitialLoading && !this.error;
    }

    /**
     * @description Show spinner overlay during actions (not initial load)
     */
    get showSpinnerOverlay() {
        return this.isLoading && !this.isInitialLoading;
    }

    /**
     * @description Grade badge CSS class
     */
    get gradeBadgeClass() {
        const baseClass = 'grade-badge';
        switch (this.gradeColor) {
            case 'green': return `${baseClass} grade-badge-green`;
            case 'yellow': return `${baseClass} grade-badge-yellow`;
            case 'orange': return `${baseClass} grade-badge-orange`;
            case 'red': return `${baseClass} grade-badge-red`;
            case 'black': return `${baseClass} grade-badge-black`;
            default: return baseClass;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Compliance Tab Computed Properties
    // ─────────────────────────────────────────────────────────────────────────────

    get isAssessmentDisabled() {
        return !this.selectedTemplate || this.isLoading;
    }

    get hasComplianceData() {
        return this.complianceData !== null;
    }

    get showComplianceEmpty() {
        return !this.hasComplianceData;
    }

    get complianceScoreDisplay() {
        return this.complianceData ? this.complianceData.complianceScore.toFixed(1) + '%' : '0%';
    }

    get complianceScoreClass() {
        if (!this.complianceData) return 'compliance-score-value';
        const score = this.complianceData.complianceScore;
        if (score >= 80) return 'compliance-score-value score-success';
        if (score >= 60) return 'compliance-score-value score-warning';
        return 'compliance-score-value score-critical';
    }

    get complianceTotalControls() {
        return this.complianceData ? this.complianceData.totalControls : 0;
    }

    get compliancePassedControls() {
        return this.complianceData ? this.complianceData.passedControls : 0;
    }

    get complianceFailedControls() {
        return this.complianceData ? this.complianceData.failedControls : 0;
    }

    get complianceNAControls() {
        return this.complianceData ? this.complianceData.notApplicableControls : 0;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Trends Tab Computed Properties
    // ─────────────────────────────────────────────────────────────────────────────

    get hasTrendData() {
        return this.trendData && this.trendData.snapshotCount > 0;
    }

    get showTrendEmpty() {
        return !this.hasTrendData;
    }

    get trendCurrentScore() {
        return this.trendData ? this.trendData.currentScore : 0;
    }

    get trendAverageScore() {
        return this.trendData ? this.trendData.averageScore : 0;
    }

    get trendHighestScore() {
        return this.trendData ? this.trendData.highestScore : 0;
    }

    get trendSnapshotCount() {
        return this.trendData ? this.trendData.snapshotCount : 0;
    }

    get trendIcon() {
        if (!this.trendData) return 'utility:dash';
        switch (this.trendData.trendDirection) {
            case 'improving': return 'utility:arrowup';
            case 'declining': return 'utility:arrowdown';
            default: return 'utility:dash';
        }
    }

    get trendTextClass() {
        if (!this.trendData) return 'slds-text-color_default';
        switch (this.trendData.trendDirection) {
            case 'improving': return 'slds-text-color_success';
            case 'declining': return 'slds-text-color_error';
            default: return 'slds-text-color_default';
        }
    }

    get trendText() {
        if (!this.trendData || !this.trendData.scoreTrend) return 'No change';
        const diff = this.trendData.scoreTrend;
        if (diff > 0) return `+${diff} points from last snapshot`;
        if (diff < 0) return `${diff} points from last snapshot`;
        return 'No change from last snapshot';
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
    async handleRefresh() {
        this.isLoading = true;
        this.complianceData = null;
        this.complianceControlsData = [];
        try {
            await Promise.all([
                refreshApex(this.wiredAuditResult),
                refreshApex(this.wiredTrendResult)
            ]);
            this.showToast('Success', 'Dashboard refreshed', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to refresh: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
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
     * @description Handle compliance template selection
     */
    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
        this.complianceData = null;
        this.complianceControlsData = [];
    }

    /**
     * @description Handle tab change to persist active tab across re-renders
     */
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    /**
     * @description Handle run compliance assessment button
     */
    async handleRunAssessment() {
        if (!this.selectedTemplate) return;

        this.isLoading = true;
        try {
            const result = await runComplianceAssessment({ templateName: this.selectedTemplate });
            this.complianceData = result;
            
            // Transform controls for datatable
            this.complianceControlsData = result.controls.map(control => ({
                ...control,
                statusClass: this.getComplianceStatusClass(control.status)
            }));

            this.showToast('Success', 'Compliance assessment completed', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to run compliance assessment: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Get CSS class for compliance status
     */
    getComplianceStatusClass(status) {
        switch (status) {
            case 'Compliant': return 'slds-badge slds-badge_success';
            case 'Non-Compliant': return 'slds-badge slds-badge_inverse badge-critical';
            case 'Partial Compliance': return 'slds-badge badge-warning';
            case 'Not Applicable': return 'slds-badge slds-badge_lightest';
            default: return 'slds-badge';
        }
    }

    /**
     * @description Handle trend range selection change
     */
    handleTrendRangeChange(event) {
        this.selectedTrendDays = event.detail.value;
    }

    /**
     * @description Handle save snapshot button
     */
    async handleSaveSnapshot() {
        this.isLoading = true;
        try {
            const snapshotId = await saveAuditSnapshot({ 
                complianceTemplate: this.selectedTemplate || 'None' 
            });
            this.showToast('Success', 'Audit snapshot saved successfully', 'success');
            
            // Refresh trend data
            refreshApex(this.wiredTrendResult);
        } catch (error) {
            this.showToast('Error', 'Failed to save snapshot: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handle export menu selection
     */
    async handleExportSelect(event) {
        const exportType = event.detail.value;
        this.isLoading = true;

        try {
            let result;
            
            switch (exportType) {
                case 'csv':
                    result = await exportAuditToCSV({
                        includePassedTests: true,
                        includeRemediation: true,
                        complianceTemplate: this.selectedTemplate || 'None'
                    });
                    break;
                case 'excel':
                    result = await exportAuditToExcel();
                    break;
                case 'trend':
                    result = await exportTrendDataToCSV({
                        days: parseInt(this.selectedTrendDays, 10)
                    });
                    break;
                default:
                    return;
            }

            if (result && result.success) {
                this.downloadFile(result.content, result.fileName, result.mimeType);
                this.showToast('Success', 'Export completed successfully', 'success');
            } else {
                this.showToast('Error', result.errorMessage || 'Export failed', 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Export failed: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Download file helper - LWS compatible using data URI
     */
    downloadFile(content, fileName, mimeType) {
        // Encode content to base64 for LWS compatibility
        const base64Content = btoa(unescape(encodeURIComponent(content)));
        const dataUri = `data:${mimeType};base64,${base64Content}`;
        
        const link = document.createElement('a');
        link.href = dataUri;
        link.download = fileName;
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    /**
     * @description Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    /**
     * @description Reduce errors to a string message
     */
    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unexpected error occurred';
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
