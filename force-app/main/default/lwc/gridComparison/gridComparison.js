import { LightningElement, api, track } from 'lwc';
import { reduceError } from 'c/gridBuilderUtils';
import getComparisonData from '@salesforce/apex/GridComparisonController.getComparisonData';
import searchGrids from '@salesforce/apex/GridComparisonController.searchGrids';
import searchAgreements from '@salesforce/apex/GridComparisonController.searchAgreements';
import getGridFromAgreement from '@salesforce/apex/GridComparisonController.getGridFromAgreement';

const ROW_TYPE_CSS = {
    SAME_EXACT    : 'row-green',
    SAME_DIFF     : 'row-red',
    CURRENT_ONLY  : 'row-blue',
    SELECTED_ONLY : 'row-gray'
};

// Parse a formatted percent string like "2.50%" or "2,50%" → 2.50 (or null)
function parsePct(str) {
    if (!str) return null;
    const n = parseFloat(str.replace('%', '').replace(',', '.'));
    return isNaN(n) ? null : n;
}

function formatDiff(a, b) {
    if (a == null || b == null) return null;
    const d = (a - b);
    const sign = d > 0 ? '+' : '';
    return sign + d.toFixed(2) + '%';
}

function fmtAmt(v) {
    if (v == null || v === 0) return null;
    const abs = Math.abs(v);
    if (abs >= 1_000_000) return (v / 1_000_000).toFixed(1) + 'M';
    if (abs >= 1_000)     return Math.round(v).toLocaleString();
    return Math.round(v).toString();
}

function fmtDiffAmt(v) {
    if (v == null || v === 0) return null;
    const sign = v > 0 ? '+' : '';
    const abs = Math.abs(v);
    if (abs >= 1_000_000) return sign + (v / 1_000_000).toFixed(1) + 'M';
    return sign + Math.round(v).toLocaleString();
}

// greenIfNegative=true  → RR  (lower rebate = better)
// greenIfNegative=false → NM/PR (higher = better)
function diffCls(a, b, greenIfNegative) {
    const base = 'td-right td-diff';
    if (a == null || b == null) return base;
    const d = a - b;
    if (d === 0) return base;
    const isGreen = greenIfNegative ? d < 0 : d > 0;
    return base + (isGreen ? '-green' : '-red');
}

export default class GridComparison extends LightningElement {
    @api recordId;
    @api iconName = 'utility:table';

    // ── Header state ──
    @track searchOptions  = [];
    @track selectedGridId = null;
    @track selectedLabel  = null;
    @track mode           = 'grid';   // 'grid' | 'agreement'
    @track errors         = [];
    @track isLoading      = false;

    // ── Overview state ──
    @track overviewRows = [];
    @track overviewOpen = true;

    // ── Detail state ──
    @track mergedRows        = [];
    @track discrepanciesOnly = false;
    @track detailOpen        = true;

    // ── Lifecycle ──
    connectedCallback() {
        this.loadGridOptions();
    }

    // ── Header getters ──
    get hasErrors()            { return this.errors.length > 0; }
    get isModeGrid()           { return this.mode === 'grid'; }
    get isModeAgreement()      { return this.mode === 'agreement'; }
    get byGridVariant()        { return this.mode === 'grid'      ? 'brand' : 'neutral'; }
    get byAgreementVariant()   { return this.mode === 'agreement' ? 'brand' : 'neutral'; }
    get showAllVariant()       { return !this.discrepanciesOnly   ? 'brand' : 'neutral'; }
    get discrepanciesVariant() { return this.discrepanciesOnly    ? 'brand' : 'neutral'; }

    get rowCountLabel() {
        const total   = this.mergedRows.length;
        const visible = this.visibleRows.length;
        return `${visible} of ${total} item${total === 1 ? '' : 's'}`;
    }

    // ── Header handlers ──
    handleModeByGrid() {
        if (this.mode === 'grid') return;
        this.mode = 'grid';
        this.searchOptions = [];
        this.loadGridOptions();
    }

    handleModeByAgreement() {
        if (this.mode === 'agreement') return;
        this.mode = 'agreement';
        this.searchOptions = [];
        this.loadAgreementOptions();
    }

    handleShowAll()           { this.discrepanciesOnly = false; }
    handleShowDiscrepancies() { this.discrepanciesOnly = true;  }

    async loadGridOptions(searchTerm = '') {
        try {
            const results = await searchGrids({ searchTerm, currentGridId: this.recordId });
            this.searchOptions = (results || []).map(r => ({
                label : r.name + (r.subtitle ? ' – ' + r.subtitle : ''),
                value : r.id
            }));
            this._refreshSearchList();
        } catch (e) {
            this.errors = [reduceError(e)];
        }
    }

    async loadAgreementOptions(searchTerm = '') {
        try {
            const results = await searchAgreements({ searchTerm });
            this.searchOptions = (results || []).map(r => ({
                label : r.name + (r.subtitle ? ' – ' + r.subtitle : ''),
                value : r.id
            }));
            this._refreshSearchList();
        } catch (e) {
            this.errors = [reduceError(e)];
        }
    }

    _refreshSearchList() {
        const list = this.template.querySelector('c-multi-select-search-list');
        if (list) list.refreshOptions(this.searchOptions);
    }

    handleSearchChange(event) {
        const { selectedValues, isSearchChange, searchKey } = event.detail;
        if (isSearchChange) {
            if (this.isModeGrid) this.loadGridOptions(searchKey);
            else                 this.loadAgreementOptions(searchKey);
        } else if (selectedValues) {
            this.handleSelectResult(selectedValues);
        }
    }

    async handleSelectResult(id) {
        const found = this.searchOptions.find(o => o.value === id);
        if (!found) return;

        if (this.mode === 'agreement') {
            try {
                const gridId = await getGridFromAgreement({ agreementId: id });
                if (!gridId) {
                    this.errors = ['No approved grid found on the selected agreement.'];
                    return;
                }
                this.selectedGridId = gridId;
                this.selectedLabel  = found.label;
            } catch (e) {
                this.errors = [reduceError(e)];
                return;
            }
        } else {
            this.selectedGridId = id;
            this.selectedLabel  = found.label;
        }

        this.loadComparison();
    }

    handleClearSelection() {
        this.selectedGridId    = null;
        this.selectedLabel     = null;
        this.errors            = [];
        this.overviewRows      = [];
        this.mergedRows        = [];
        this.discrepanciesOnly = false;
    }

    handleRefresh() {
        if (this.selectedGridId) this.loadComparison();
    }

    async loadComparison() {
        if (!this.recordId || !this.selectedGridId) return;
        this.isLoading = true;
        this.errors    = [];
        try {
            const data = await getComparisonData({ currentGridId: this.recordId, selectedGridId: this.selectedGridId });
            const currentRows  = data?.current?.rows   || [];
            const selectedRows = data?.selected?.rows  || [];
            this.errors       = [...(data?.current?.errors  || []), ...(data?.selected?.errors || [])];
            this.overviewRows = this.buildOverview(currentRows, selectedRows);
            this.mergedRows   = this.buildMergedRows(currentRows, selectedRows);
        } catch (e) {
            this.errors       = [reduceError(e)];
            this.overviewRows = [];
            this.mergedRows   = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Overview getters ──
    get overviewSectionClass() { return `slds-section${this.overviewOpen ? ' slds-is-open' : ''}`; }
    get overviewHidden()       { return !this.overviewOpen; }

    // ── Overview handlers ──
    handleToggleOverview() { this.overviewOpen = !this.overviewOpen; }

    // ── Overview logic ──
    buildOverview(currentRows, selectedRows) {
        // AUM is a locale-formatted integer string (e.g. "1,234,567") — strip non-digits for weight
        const parseAum = s => {
            if (!s) return 0;
            const n = parseFloat(s.replace(/[^0-9]/g, ''));
            return isNaN(n) ? 0 : n;
        };

        const wgtAvg = (rows, aumFn, valueFn) => {
            let sumWV = 0, sumAum = 0;
            for (const r of rows) {
                const aum = parseAum(aumFn(r));
                const val = parsePct(valueFn(r));
                if (aum > 0 && val != null) {
                    sumWV  += val * aum;
                    sumAum += aum;
                }
            }
            return sumAum > 0 ? sumWV / sumAum : null;
        };

        const fmt     = v => v != null ? v.toFixed(2) + '%' : '–';
        const fmtDiff = (a, b) => {
            if (a == null || b == null) return '–';
            const d = a - b;
            return (d > 0 ? '+' : '') + d.toFixed(2) + '%';
        };

        const cFee = wgtAvg(currentRows,  r => r.aum, r => r.effMgtFee);
        const sFee = wgtAvg(selectedRows, r => r.aum, r => r.effMgtFee);
        const cRR  = wgtAvg(currentRows,  r => r.aum, r => r.rebateRate);
        const sRR  = wgtAvg(selectedRows, r => r.aum, r => r.rebateRate);
        const cNM  = cFee != null && cRR != null ? cFee - cRR : null;
        const sNM  = sFee != null && sRR != null ? sFee - sRR : null;
        const cPR  = cFee != null && cFee !== 0 && cNM != null ? (cNM / cFee * 100) : null;
        const sPR  = sFee != null && sFee !== 0 && sNM != null ? (sNM / sFee * 100) : null;

        return [
            { key: 'current',  label: 'Current',  rowClass: 'ov-current',  fee: fmt(cFee), rr: fmt(cRR), nm: fmt(cNM), pr: fmt(cPR) },
            { key: 'selected', label: 'Selected', rowClass: 'ov-selected', fee: fmt(sFee), rr: fmt(sRR), nm: fmt(sNM), pr: fmt(sPR) },
            { key: 'diff',     label: 'Diff',     rowClass: 'ov-diff',     fee: fmtDiff(cFee, sFee), rr: fmtDiff(cRR, sRR), nm: fmtDiff(cNM, sNM), pr: fmtDiff(cPR, sPR) }
        ];
    }

    // ── Detail getters ──
    get hasRows()            { return this.mergedRows.length > 0; }
    get detailSectionClass() { return `slds-section${this.detailOpen ? ' slds-is-open' : ''}`; }
    get detailHidden()       { return !this.detailOpen; }

    get visibleRows() {
        if (!this.discrepanciesOnly) return this.mergedRows;
        return this.mergedRows.filter(r => r.rowType !== 'SAME_EXACT');
    }

    // ── Detail handlers ──
    handleToggleDetail() { this.detailOpen = !this.detailOpen; }

    // ── Detail logic ──
    buildMergedRows(currentRows, selectedRows) {
        const byScId = new Map();

        for (const r of currentRows) {
            byScId.set(r.shareClassId, { curr: r });
        }
        for (const r of selectedRows) {
            const entry = byScId.get(r.shareClassId) || {};
            entry.sel = r;
            byScId.set(r.shareClassId, entry);
        }

        const rows = [];
        for (const [, { curr, sel }] of byScId) {
            let rowType = (curr && sel)? ((curr.standardGridDetailId === sel.standardGridDetailId)? 'SAME_EXACT' : 'SAME_DIFF') : (curr)? 'CURRENT_ONLY' : 'SELECTED_ONLY';
            const ref    = curr || sel;
            // eslint-disable-next-line no-console
            console.log('[GridComparison] row:', ref.shareClass, '| aum:', ref.aum, '| curr.rebateRate:', curr?.rebateRate, '| sel.rebateRate:', sel?.rebateRate, '| rowType:', rowType);
            const currRR = parsePct(curr?.rebateRate);
            const selRR  = parsePct(sel?.rebateRate);
            const currNM = parsePct(curr?.netMargin);
            const selNM  = parsePct(sel?.netMargin);
            const currPR = parsePct(curr?.profitability);
            const selPR  = parsePct(sel?.profitability);

            const aumNum  = parseFloat((ref.aum || '').replace(/[^0-9]/g, '')) || 0;
            const calcAmt = pct => (pct != null && aumNum) ? pct * aumNum / 100 : null;
            const cRRAmt  = calcAmt(currRR), sRRAmt = calcAmt(selRR);
            const cNMAmt  = calcAmt(currNM), sNMAmt = calcAmt(selNM);
            const cPRAmt  = calcAmt(currPR), sPRAmt = calcAmt(selPR);

            rows.push({
                key             : ref.shareClassId,
                rowType,
                rowClass        : ROW_TYPE_CSS[rowType],
                portfolio       : ref.portfolio,
                shareClass      : ref.shareClass,
                isin            : ref.isin,
                aum             : ref.aum,
                effMgtFee       : ref.effMgtFee,
                currentStdGrid  : curr?.stdGridName  ?? '',
                selectedStdGrid : sel?.stdGridName   ?? '',
                currRR          : curr?.rebateRate   ?? '',
                currRRAmt       : fmtAmt(cRRAmt),
                selRR           : sel?.rebateRate    ?? '',
                selRRAmt        : fmtAmt(sRRAmt),
                diffRR          : formatDiff(currRR, selRR),
                diffRRClass     : diffCls(currRR, selRR, true),
                diffRRAmt       : fmtDiffAmt(cRRAmt != null && sRRAmt != null ? cRRAmt - sRRAmt : null),
                diffRRAmtClass  : diffCls(currRR, selRR, true),
                currNM          : curr?.netMargin    ?? '',
                currNMAmt       : fmtAmt(cNMAmt),
                selNM           : sel?.netMargin     ?? '',
                selNMAmt        : fmtAmt(sNMAmt),
                diffNM          : formatDiff(currNM, selNM),
                diffNMClass     : diffCls(currNM, selNM, false),
                diffNMAmt       : fmtDiffAmt(cNMAmt != null && sNMAmt != null ? cNMAmt - sNMAmt : null),
                diffNMAmtClass  : diffCls(currNM, selNM, false),
                currPR          : curr?.profitability ?? '',
                currPRAmt       : fmtAmt(cPRAmt),
                selPR           : sel?.profitability  ?? '',
                selPRAmt        : fmtAmt(sPRAmt),
                diffPR          : formatDiff(currPR, selPR),
                diffPRClass     : diffCls(currPR, selPR, false),
                diffPRAmt       : fmtDiffAmt(cPRAmt != null && sPRAmt != null ? cPRAmt - sPRAmt : null),
                diffPRAmtClass  : diffCls(currPR, selPR, false)
            });
        }
        return rows;
    }
}