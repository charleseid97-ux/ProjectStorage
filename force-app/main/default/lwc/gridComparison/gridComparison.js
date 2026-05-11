import { LightningElement, api, track } from 'lwc';
import { reduceError, parsePct, parseAum, fmtAmt, fmtDiffAmt, wgtAvgAndAmt } from 'c/gridBuilderUtils';
import getComparisonData           from '@salesforce/apex/GridComparisonController.getComparisonData';
import searchGrids                 from '@salesforce/apex/GridComparisonController.searchGrids';
import searchAgreements            from '@salesforce/apex/GridComparisonController.searchAgreements';
import getActiveGridForCurrentGrid from '@salesforce/apex/GridComparisonController.getActiveGridForCurrentGrid';

const MODE_GRID        = 'grid';
const MODE_AGREEMENT   = 'agreement';
const MODE_ACTIVE_GRID = 'activeGrid';

const STATUS_IS_CURRENT = 'IS_CURRENT';
const STATUS_NONE       = 'NONE';
const STATUS_HAS_ACTIVE = 'HAS_ACTIVE';

const ROW_TYPE_CSS = {
    SAME_EXACT    : 'row-green',
    SAME_DIFF     : 'row-red',
    CURRENT_ONLY  : 'row-blue',
    SELECTED_ONLY : 'row-gray'
};

function formatDiff(a, b) {
    if (a == null || b == null) return null;
    const d = (a - b);
    const sign = d > 0 ? '+' : '';
    return sign + d.toFixed(2) + '%';
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
    @track searchOptions   = [];
    @track selectedGridId  = null;
    @track selectedLabel   = null;
    @track mode            = MODE_GRID;
    @track errors          = [];
    @track isLoading      = false;
    @track activeGridInfo = null;

    // ── Overview state ──
    @track overviewRows = [];
    @track overviewOpen = true;

    // ── Detail state ──
    @track mergedRows        = [];
    @track discrepanciesOnly = true;
    @track detailOpen        = true;
    @track sortField         = 'diffRRAmt';
    @track sortDir           = 'desc';

    // ── Lifecycle ──
    connectedCallback() {
        this.loadActiveGridInfo();
    }

    // ── Header getters ──
    get hasErrors()              { return this.errors.length > 0; }
    get isModeGrid()             { return this.mode === MODE_GRID; }
    get isModeAgreement()        { return this.mode === MODE_AGREEMENT; }
    get byGridVariant()          { return this.mode === MODE_GRID        ? 'brand' : 'neutral'; }
    get byAgreementVariant()     { return this.mode === MODE_AGREEMENT   ? 'brand' : 'neutral'; }
    get activeGridVariant()      { return this.mode === MODE_ACTIVE_GRID ? 'brand' : 'neutral'; }
    get isActiveGridDisabled()   { return this.activeGridInfo?.status !== STATUS_HAS_ACTIVE; }
    get activeGridTitle() {
        if (this.activeGridInfo?.status === STATUS_IS_CURRENT) return 'Current Grid is the Active Grid of the Agreement';
        if (this.activeGridInfo?.status === STATUS_NONE)       return 'No Active Grid found on current Agreement';
        return '';
    }
    get showAllVariant()         { return this.discrepanciesOnly ? 'neutral' : 'brand'; }
    get discrepanciesVariant()   { return this.discrepanciesOnly ? 'brand'   : 'neutral'; }

    get rowCountLabel() {
        const total   = this.mergedRows.length;
        const visible = this.visibleRows.length;
        return `${visible} of ${total} item${total === 1 ? '' : 's'}`;
    }

    // ── Header handlers ──
    handleModeByGrid() {
        if (this.mode === MODE_GRID) return;
        this.mode = MODE_GRID;
        this.searchOptions = [];
        this.loadGridOptions();
    }

    handleModeByAgreement() {
        if (this.mode === MODE_AGREEMENT) return;
        this.mode = MODE_AGREEMENT;
        this.searchOptions = [];
        this.loadAgreementOptions();
    }

    handleModeByActiveGrid() {
        if (this.mode === MODE_ACTIVE_GRID || this.activeGridInfo?.status !== STATUS_HAS_ACTIVE) return;
        this.mode           = MODE_ACTIVE_GRID;
        this.searchOptions  = [];
        this.selectedGridId = this.activeGridInfo.activeGridId;
        this.selectedLabel  = this.activeGridInfo.activeGridName;
        this.loadComparison();
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
            this.refreshSearchList();
        } catch (e) {
            this.errors = [reduceError(e)];
        }
    }

    async loadAgreementOptions(searchTerm = '') {
        try {
            const results = await searchAgreements({ searchTerm });
            this.searchOptions = (results || []).map(r => ({
                label  : r.name + (r.subtitle ? ' – ' + r.subtitle : ''),
                value  : r.id,
                gridId : r.gridId
            }));
            this.refreshSearchList();
        } catch (e) {
            this.errors = [reduceError(e)];
        }
    }

    async loadActiveGridInfo() {
        try {
            const info = await getActiveGridForCurrentGrid({ currentGridId: this.recordId });
            this.activeGridInfo = info;
            if (info?.status === STATUS_HAS_ACTIVE) {
                this.mode           = MODE_ACTIVE_GRID;
                this.selectedGridId = info.activeGridId;
                this.selectedLabel  = info.activeGridName;
                this.loadComparison();
            } else {
                this.loadGridOptions();
            }
        } catch (e) {
            this.errors = [reduceError(e)];
            this.loadGridOptions();
        }
    }

    refreshSearchList() {
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

    handleSelectResult(id) {
        const found = this.searchOptions.find(o => o.value === id);
        if (!found) return;

        if (this.mode === MODE_AGREEMENT) {
            if (!found.gridId) {
                this.errors = ['No approved grid found on the selected agreement.'];
                return;
            }
            this.selectedGridId = found.gridId;
            this.selectedLabel  = found.label;
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
        this.discrepanciesOnly = true;
        if (this.mode === MODE_ACTIVE_GRID) {
            this.mode = MODE_GRID;
            this.searchOptions = [];
            this.loadGridOptions();
        }
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
            const currentRows  = data?.current?.rows  || [];
            const selectedRows = data?.selected?.rows || [];
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
        const fmt          = v       => v == null ? '–' : v.toFixed(2) + '%';
        const fmtOvAmt     = v       => fmtAmt(v) ?? '–';
        const fmtDiffPct   = (a, b)  => {
            if (a == null || b == null) return '–';
            const d = a - b;
            return (d > 0 ? '+' : '') + d.toFixed(2) + '%';
        };
        const fmtDiffOvAmt = (a, b)  => {
            if (a == null || b == null) return '–';
            return fmtDiffAmt(a - b) ?? '–';
        };

        const cFee = wgtAvgAndAmt(currentRows,  r => r.aum, r => r.effMgtFee);
        const sFee = wgtAvgAndAmt(selectedRows, r => r.aum, r => r.effMgtFee);
        const cRR  = wgtAvgAndAmt(currentRows,  r => r.aum, r => r.rebateRate);
        const sRR  = wgtAvgAndAmt(selectedRows, r => r.aum, r => r.rebateRate);

        const cNMpct = cFee.pct != null && cRR.pct != null ? cFee.pct - cRR.pct : null;
        const sNMpct = sFee.pct != null && sRR.pct != null ? sFee.pct - sRR.pct : null;
        const cNMamt = cFee.amt != null && cRR.amt != null ? cFee.amt - cRR.amt : null;
        const sNMamt = sFee.amt != null && sRR.amt != null ? sFee.amt - sRR.amt : null;

        const cPRpct = cFee.pct != null && cFee.pct !== 0 && cNMpct != null ? (cNMpct / cFee.pct * 100) : null;
        const sPRpct = sFee.pct != null && sFee.pct !== 0 && sNMpct != null ? (sNMpct / sFee.pct * 100) : null;

        return [
            {
                key: 'current',  label: 'Current',  rowClass: 'ov-current',
                fee: fmt(cFee.pct), feeAmt: fmtOvAmt(cFee.amt),
                rr:  fmt(cRR.pct),  rrAmt:  fmtOvAmt(cRR.amt),
                nm:  fmt(cNMpct),   nmAmt:  fmtOvAmt(cNMamt),
                pr:  fmt(cPRpct)
            },
            {
                key: 'selected', label: 'Selected', rowClass: 'ov-selected',
                fee: fmt(sFee.pct), feeAmt: fmtOvAmt(sFee.amt),
                rr:  fmt(sRR.pct),  rrAmt:  fmtOvAmt(sRR.amt),
                nm:  fmt(sNMpct),   nmAmt:  fmtOvAmt(sNMamt),
                pr:  fmt(sPRpct)
            },
            {
                key: 'diff',     label: 'Diff',     rowClass: 'ov-diff',
                fee: fmtDiffPct(cFee.pct, sFee.pct), feeAmt: fmtDiffOvAmt(cFee.amt, sFee.amt),
                rr:  fmtDiffPct(cRR.pct,  sRR.pct),  rrAmt:  fmtDiffOvAmt(cRR.amt,  sRR.amt),
                nm:  fmtDiffPct(cNMpct,   sNMpct),   nmAmt:  fmtDiffOvAmt(cNMamt,   sNMamt),
                pr:  fmtDiffPct(cPRpct,   sPRpct)
            }
        ];
    }

    // ── Detail getters ──
    get hasRows()            { return this.mergedRows.length > 0; }
    get detailSectionClass() { return `slds-section${this.detailOpen ? ' slds-is-open' : ''}`; }
    get detailHidden()       { return !this.detailOpen; }

    get sortIndicators() {
        const cols = ['portfolio','shareClass','isin','aum','effMgtFee','currentStdGrid','selectedStdGrid',
                      'currRR','selRR','diffRRAmt','diffRR','currNM','selNM','diffNMAmt','diffNM',
                      'currPR','selPR','diffPRAmt','diffPR'];
        return Object.fromEntries(
            cols.map(c => [c, this.sortField === c ? (this.sortDir === 'asc' ? '↑' : '↓') : ''])
        );
    }

    get visibleRows() {
        const TEXT_FIELDS = new Set(['portfolio', 'shareClass', 'isin', 'currentStdGrid', 'selectedStdGrid']);
        let rows = this.discrepanciesOnly ? this.mergedRows.filter(r => r.isDiscrepancy) : this.mergedRows;

        if (this.sortField) {
            const field  = this.sortField;
            const rawKey = field + 'Raw';
            const dir    = this.sortDir === 'asc' ? 1 : -1;
            rows = [...rows].sort((a, b) => {
                if (TEXT_FIELDS.has(field)) {
                    return dir * String(a[field] || '').localeCompare(String(b[field] || ''), 'fr');
                }
                const va = a[rawKey] ?? 0;
                const vb = b[rawKey] ?? 0;
                return dir * (Math.abs(va) - Math.abs(vb));
            });
        }

        return rows;
    }

    // ── Detail handlers ──
    handleToggleDetail() { this.detailOpen = !this.detailOpen; }

    handleSort(e) {
        const field = e.currentTarget.dataset.sort;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDir   = 'asc';
        }
    }

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
        return [...byScId.values()].map(({ curr, sel }) => this.buildMergedRow(curr, sel));
    }

    getRowType(curr, sel) {
        if (curr && sel) {
            return curr.standardGridDetailId === sel.standardGridDetailId ? 'SAME_EXACT' : 'SAME_DIFF';
        }
        return curr ? 'CURRENT_ONLY' : 'SELECTED_ONLY';
    }

    buildMergedRow(curr, sel) {
        const rowType = this.getRowType(curr, sel);
        const ref     = curr || sel;
        const currRR  = curr ? parsePct(curr.rebateRate) : 0;
        const selRR   = sel  ? parsePct(sel.rebateRate)  : 0;
        const currNM  = parsePct(curr?.netMargin);
        const selNM   = parsePct(sel?.netMargin);
        const currPR  = parsePct(curr?.profitability);
        const selPR   = parsePct(sel?.profitability);
        const aumNum  = parseAum(ref.aum);

        const calcAmt     = pct => (pct != null && aumNum) ? pct * aumNum / 100 : null;
        const cRRAmt      = calcAmt(currRR), sRRAmt = calcAmt(selRR);
        const cNMAmt      = calcAmt(currNM), sNMAmt = calcAmt(selNM);
        const cPRAmt      = calcAmt(currPR), sPRAmt = calcAmt(selPR);
        const diffRRAmtVal = cRRAmt != null && sRRAmt != null ? cRRAmt - sRRAmt : null;
        const diffNMAmtVal = cNMAmt != null && sNMAmt != null ? cNMAmt - sNMAmt : null;
        const diffPRAmtVal = cPRAmt != null && sPRAmt != null ? cPRAmt - sPRAmt : null;

        return {
            key             : ref.shareClassId,
            rowType,
            rowClass        : ROW_TYPE_CSS[rowType],
            isDiscrepancy   : (currRR ?? 0) !== (selRR ?? 0),
            portfolio       : ref.portfolio,
            shareClass      : ref.shareClass,
            isin            : ref.isin,
            aum             : fmtAmt(aumNum) ?? (ref.aum || ''),
            effMgtFee       : ref.effMgtFee,
            currentStdGrid  : curr?.stdGridName  ?? '',
            selectedStdGrid : sel?.stdGridName   ?? '',
            currRR          : curr ? (curr.rebateRate ?? '') : '0.00%',
            currRRAmt       : fmtAmt(cRRAmt),
            selRR           : sel  ? (sel.rebateRate  ?? '') : '0.00%',
            selRRAmt        : fmtAmt(sRRAmt),
            diffRR          : formatDiff(currRR, selRR),
            diffRRClass     : diffCls(currRR, selRR, true),
            diffRRAmt       : fmtDiffAmt(diffRRAmtVal),
            diffRRAmtClass  : diffCls(currRR, selRR, true),
            currNM          : curr?.netMargin    ?? '',
            currNMAmt       : fmtAmt(cNMAmt),
            selNM           : sel?.netMargin     ?? '',
            selNMAmt        : fmtAmt(sNMAmt),
            diffNM          : formatDiff(currNM, selNM),
            diffNMClass     : diffCls(currNM, selNM, false),
            diffNMAmt       : fmtDiffAmt(diffNMAmtVal),
            diffNMAmtClass  : diffCls(currNM, selNM, false),
            currPR          : curr?.profitability ?? '',
            currPRAmt       : fmtAmt(cPRAmt),
            selPR           : sel?.profitability  ?? '',
            selPRAmt        : fmtAmt(sPRAmt),
            diffPR          : formatDiff(currPR, selPR),
            diffPRClass     : diffCls(currPR, selPR, false),
            diffPRAmt       : fmtDiffAmt(diffPRAmtVal),
            diffPRAmtClass  : diffCls(currPR, selPR, false),
            aumRaw          : aumNum,
            effMgtFeeRaw    : parsePct(ref.effMgtFee),
            currRRRaw       : currRR,
            selRRRaw        : selRR,
            diffRRRaw       : (currRR ?? 0) - (selRR ?? 0),
            diffRRAmtRaw    : diffRRAmtVal,
            currNMRaw       : currNM,
            selNMRaw        : selNM,
            diffNMRaw       : currNM != null && selNM != null ? currNM - selNM : null,
            diffNMAmtRaw    : diffNMAmtVal,
            currPRRaw       : currPR,
            selPRRaw        : selPR,
            diffPRRaw       : currPR != null && selPR != null ? currPR - selPR : null,
            diffPRAmtRaw    : diffPRAmtVal
        };
    }
}