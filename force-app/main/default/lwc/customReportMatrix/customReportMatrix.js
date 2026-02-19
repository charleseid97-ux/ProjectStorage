import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMatrixData from '@salesforce/apex/CustomReportMatrixController.getMatrixData';
import LABEL_CONFIG_NOT_FOUND from '@salesforce/label/c.Matrix_ConfigNotFound';
import LABEL_QUERY_ERROR from '@salesforce/label/c.Matrix_QueryError';
import LABEL_NO_DATA from '@salesforce/label/c.Matrix_NoData';

export default class CustomReportMatrix extends LightningElement {
    @api configName;

    @track _matrixData = null;
    @track _isLoading = false;
    @track _errors = [];
    @track displayRows = [];

    labels = {
        configNotFound: LABEL_CONFIG_NOT_FOUND,
        queryError: LABEL_QUERY_ERROR,
        noData: LABEL_NO_DATA
    };

    connectedCallback() {
        this.loadMatrix();
    }

    async loadMatrix() {
        if (!this.configName) {
            this._errors = [this.labels.configNotFound];
            return;
        }
        this._isLoading = true;
        this._errors = [];
        this._matrixData = null;
        try {
            const result = await getMatrixData({ configName: this.configName });
            this._matrixData = result;
            this.displayRows = this.getDisplayRows();
            this._errors = result?.errors || [];
        }
        catch (error) {
            const msg = error?.body?.message || error?.message || this.labels.queryError;
            this._errors = [msg];
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: msg, variant: 'error'}));
        }
        finally {
            this._isLoading = false;
        }
    }

    getDisplayRows() {
        const rows = [];
        (this._matrixData?.rowGroups || []).forEach((rg, rgIdx) => {
            rg.rows.forEach((rd, rdIdx) => {
                rows.push({
                    key: 'row-' + rgIdx + '-' + rdIdx,
                    isFirstRow: rdIdx === 0,
                    rowGroup1Label: rg.label,
                    rowspan: rg.rowspan,
                    rowGroup2Label: rd.label,
                    values: rd.values.map((v, vi) => ({
                        key: 'cell-' + rgIdx + '-' + rdIdx + '-' + vi,
                        value: v.value || '',
                        cssClass: 'value-cell cell-r' + rgIdx + ' cell-c' + vi,
                        inlineStyle: v.inlineStyle || ''
                    }))
                });
            });
        });
        return rows;
    }

    handleRefresh() {
        this.loadMatrix();
    }

    // ------------------------------------ GETTERS ------------------------------------
    get title() {
        return this._matrixData?.title || this.configName || '';
    }

    get hasErrors() {
        return this._errors && this._errors.length > 0;
    }

    get hasData() {
        return this._matrixData && this._matrixData.rowGroups && this._matrixData.rowGroups.length > 0;
    }

    get isEmpty() {
        return !this._isLoading && !this.hasErrors && !this.hasData;
    }

    get hasColGroup2() {
        return this._matrixData?.hasColGroup2 || false;
    }

    get hasRowGroup2() {
        return this._matrixData?.hasRowGroup2 || false;
    }

    get columnGroups() {
        return this._matrixData?.columnGroups || [];
    }

    get subColumnLabels() {
        return (this._matrixData?.subColumnLabels || []).map((label, idx) => ({
            key: 'sub-' + idx,
            label: label
        }));
    }

    get colGroup1Label() {
        return this._matrixData?.colGroup1Label || '';
    }

    get colGroup2Label() {
        return this._matrixData?.colGroup2Label || '';
    }

    get rowGroup1Label() {
        return this._matrixData?.rowGroup1Label || '';
    }

    get rowGroup2Label() {
        return this._matrixData?.rowGroup2Label || '';
    }

    get cornerColspan() {
        return this.hasRowGroup2 ? 2 : 1;
    }
}