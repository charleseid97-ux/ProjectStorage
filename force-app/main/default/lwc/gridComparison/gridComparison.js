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

const DEBOUNCE_DELAY = 300;

// Parse a formatted percent string like "2.50%" → 2.50 (or null)
function parsePct(str) {
    if (!str) return null;
    const n = parseFloat(str.replace('%', ''));
    return isNaN(n) ? null : n;
}

function formatDiff(a, b) {
    if (a == null || b == null) return null;
    const d = (a - b);
    const sign = d > 0 ? '+' : '';
    return sign + d.toFixed(2) + '%';
}

export default class GridComparison extends LightningElement {
    @api recordId;
    @api iconName = 'utility:table';

    // ── State ──
    @track searchTerm        = '';
    @track searchResults     = [];
    @track selectedGridId    = null;
    @track selectedLabel     = null;
    @track mode              = 'grid';   // 'grid' | 'agreement'
    @track mergedRows        = [];
    @track errors            = [];
    @track isLoading         = false;
    @track discrepanciesOnly = false;

    _searchTimer = null;

    // ── Getters ──
    get hasRows()              { return this.mergedRows.length > 0; }
    get hasErrors()            { return this.errors.length > 0; }
    get hasSearchResults()     { return this.searchResults.length > 0; }
    get searchPlaceholder()    { return this.mode === 'grid' ? 'Search grids…' : 'Search agreements…'; }
    get byGridVariant()        { return this.mode === 'grid'      ? 'brand' : 'neutral'; }
    get byAgreementVariant()   { return this.mode === 'agreement' ? 'brand' : 'neutral'; }
    get showAllVariant()       { return !this.discrepanciesOnly   ? 'brand' : 'neutral'; }
    get discrepanciesVariant() { return this.discrepanciesOnly ? 'brand' : 'neutral'; }

    get rowCountLabel() {
        const total   = this.mergedRows.length;
        const visible = this.visibleRows.length;
        return `${visible} of ${total} item${total === 1 ? '' : 's'}`;
    }

    get visibleRows() {
        if (!this.discrepanciesOnly) return this.mergedRows;
        return this.mergedRows.filter(r => r.rowType !== 'SAME_EXACT');
    }

    // ── Mode toggle ──
    handleModeByGrid() {
        if (this.mode === 'grid') return;
        this.mode = 'grid';
        this.resetSearch();
    }

    handleModeByAgreement() {
        if (this.mode === 'agreement') return;
        this.mode = 'agreement';
        this.resetSearch();
    }

    resetSearch() {
        this.searchTerm    = '';
        this.searchResults = [];
    }

    // ── Discrepancy toggle ──
    handleShowAll()          { this.discrepanciesOnly = false; }
    handleShowDiscrepancies(){ this.discrepanciesOnly = true;  }

    // ── Search ──
    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchTimer);
        if (!this.searchTerm || this.searchTerm.length < 1) {
            this.searchResults = [];
            return;
        }
        this._searchTimer = setTimeout(() => this.runSearch(), DEBOUNCE_DELAY);
    }

    async runSearch() {
        try {
            if (this.mode === 'grid') {
                this.searchResults = await searchGrids({ searchTerm: this.searchTerm, currentGridId: this.recordId });
            } else {
                this.searchResults = await searchAgreements({ searchTerm: this.searchTerm });
            }
        } 
        catch (e) {
            this.errors = [reduceError(e)];
            this.searchResults = [];
        }
    }

    async handleSelectResult(event) {
        const id = event.currentTarget.dataset.id;
        const found = this.searchResults.find(r => r.id === id);
        if (!found) return;

        this.searchResults = [];
        this.searchTerm    = '';

        if (this.mode === 'agreement') {
            // Resolve the grid from the agreement
            try {
                const gridId = await getGridFromAgreement({ agreementId: id });
                if (!gridId) {
                    this.errors = ['No approved grid found on the selected agreement.'];
                    return;
                }
                this.selectedGridId = gridId;
                this.selectedLabel = found.name + ' → ' + (found.subtitle || '');
            } catch (e) {
                this.errors = [reduceError(e)];
                return;
            }
        } else {
            this.selectedGridId = id;
            this.selectedLabel  = found.name + (found.subtitle ? ' (' + found.subtitle + ')' : '');
        }

        this.loadComparison();
    }

    handleClearSelection() {
        this.selectedGridId    = null;
        this.selectedLabel     = null;
        this.mergedRows        = [];
        this.errors            = [];
        this.discrepanciesOnly = false;
    }

    handleRefresh() {
        if (this.selectedGridId) {
            this.loadComparison();
        }
    }

    // ── Data loading ──
    async loadComparison() {
        if (!this.recordId || !this.selectedGridId) return;
        this.isLoading = true;
        this.errors    = [];
        try {
            const data = await getComparisonData({ currentGridId: this.recordId, selectedGridId: this.selectedGridId });
            const currentRows  = data?.current?.rows   || [];
            const selectedRows = data?.selected?.rows  || [];
            this.errors = [...(data?.current?.errors  || []), ...(data?.selected?.errors || [])];
            this.mergedRows = this.buildMergedRows(currentRows, selectedRows);
        } catch (e) {
            this.errors     = [reduceError(e)];
            this.mergedRows = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Merge logic ──
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
            const ref      = curr || sel;
            const currRR   = parsePct(curr?.rebateRate);
            const selRR    = parsePct(sel?.rebateRate);
            const currNM   = parsePct(curr?.netMargin);
            const selNM    = parsePct(sel?.netMargin);
            const currPR   = parsePct(curr?.profitability);
            const selPR    = parsePct(sel?.profitability);

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
                selRR           : sel?.rebateRate    ?? '',
                diffRR          : formatDiff(currRR, selRR),
                currNM          : curr?.netMargin    ?? '',
                selNM           : sel?.netMargin     ?? '',
                diffNM          : formatDiff(currNM, selNM),
                currPR          : curr?.profitability ?? '',
                selPR           : sel?.profitability  ?? '',
                diffPR          : formatDiff(currPR, selPR)
            });
        }
        return rows;
    }
}