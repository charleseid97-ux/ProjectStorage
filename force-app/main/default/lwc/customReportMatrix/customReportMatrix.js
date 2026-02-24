import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMatrixData from '@salesforce/apex/CustomReportMatrixController.getMatrixData';
import LABEL_CONFIG_NOT_FOUND from '@salesforce/label/c.Matrix_ConfigNotFound';
import LABEL_QUERY_ERROR from '@salesforce/label/c.Matrix_QueryError';
import LABEL_NO_DATA from '@salesforce/label/c.Matrix_NoData';

const STICKY_COL_WIDTH = 150;
const STICKY_BG_BASE   = 243; // rgb(243,243,243) ≈ #f3f2f2 at depth 0
const STICKY_BG_STEP   = 2.4; // reaches white (255) at depth 5

function parseBgColor(inlineStyle) {
    if (!inlineStyle) return null;
    const m = inlineStyle.match(/background-color\s*:\s*(#[0-9a-fA-F]{6})/i);
    return m ? m[1].slice(1).toUpperCase() : null;
}

export default class CustomReportMatrix extends LightningElement {
    @api configName;

    @track matrixData          = null;
    @track isLoading           = false;
    @track errors              = [];
    @track filteredDisplayRows = [];
    @track allowExcelExport    = false;
    @track allowFilter         = false;
    @track filterTerm          = '';
    @track isFiltering            = false;
    @track isReloading            = false;
    @track filterSelections       = {};
    @track pendingFilterSelections = {};
    @track filterOptions          = [];

    sheetJsLoaded = false;
    sheetJsReady  = false;
    allDisplayRows = [];
    filterTimeout  = null;

    labels = {
        configNotFound: LABEL_CONFIG_NOT_FOUND,
        queryError: LABEL_QUERY_ERROR,
        noData: LABEL_NO_DATA
    };

    connectedCallback() {
        this.loadMatrix();
    }

    renderedCallback() {
        if (this.sheetJsLoaded) return;
        this.sheetJsLoaded = true;
        loadScript(this, XlsxJsStyle).then(() => { this.sheetJsReady = true; }).catch(() => {});
    }

    async loadMatrix(isInitialLoad = true) {
        if (!this.configName) {
            this.errors = [this.labels.configNotFound];
            return;
        }
        this.errors = [];
        if (isInitialLoad) {
            this.isLoading  = true;
            this.matrixData = null;
        } else {
            this.isReloading = true;
        }
        try {
            const result             = await getMatrixData({ configName: this.configName, filterSelectionsJson: JSON.stringify(this.filterSelections), isInitialLoad });
            this.matrixData          = result;
            this.allDisplayRows     = this.getDisplayRows();
            this.filteredDisplayRows = this.allDisplayRows;
            this.allowExcelExport    = result.allowExcelExport;
            this.allowFilter         = result.allowFilters ?? false;
            if (isInitialLoad) {
                this.filterOptions          = result.filterOptions || [];
                this.filterSelections       = {};
                this.pendingFilterSelections = {};
                this.filterTerm             = '';
            }
        }
        catch (error) {
            const msg = error?.body?.message || error?.message || this.labels.queryError;
            this.errors = [msg];
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: msg, variant: 'error'}));
        }
        finally {
            this.isLoading   = false;
            this.isReloading = false;
        }
    }

    // ─── Row flattening ─────────────────────────────────────────────────────────
    getDisplayRows() {
        const rows = [];
        this.flattenNodes(this.matrixData?.rowTree || [], 0, [], rows);
        return rows;
    }

    /**
     * Recursively flattens the RowNode tree into a flat array of table rows.
     * Each row carries a `groupCells` array — one entry per depth level.
     * Only cells where `isFirst = true` are rendered; the others are covered by the rowspan above.
     *
     * `parentEntries` is an array of { base, firstRow } objects — one per ancestor depth level.
     * `isFirst` is computed lazily at leaf-placement time: true iff the current row index equals
     * the row index at which the ancestor cell first appeared. This correctly handles N levels
     * where a non-leaf's first child may itself produce multiple leaf rows.
     */
    flattenNodes(nodes, depth, parentEntries, rows) {
        nodes.forEach(node => {
            const entry = {
                base: {
                    key:         `gc-d${depth}-r${rows.length}`,
                    label:       node.label,
                    rowspan:     node.rowspan,
                    cssClass:    'row-group-cell sticky-col',
                    stickyStyle: this.stickyStyle(depth, true)
                },
                firstRow: rows.length
            };
            if (node.isLeaf) {
                const ri         = rows.length;
                const allEntries = [...parentEntries, entry];
                rows.push({
                    key:      `row-${ri}`,
                    rowClass: ri > 0 && allEntries[0].firstRow === ri ? 'matrix-row group-boundary' : 'matrix-row',
                    groupCells: allEntries.map(e => ({ ...e.base, isFirst: ri === e.firstRow })),
                    values:     (node.values || []).map((v, vi) => ({
                        key:         `cell-${ri}-${vi}`,
                        value:       v.value || '',
                        cssClass:    `value-cell cell-c${vi}`,
                        inlineStyle: v.inlineStyle || ''
                    }))
                });
            } 
            else {
                (node.children || []).forEach(child => {
                    this.flattenNodes([child], depth + 1, [...parentEntries, entry], rows);
                });
            }
        });
    }

    // ─── Filter ──────────────────────────────────────────────────────────────────
    handleFilterChange(event) {
        this.filterTerm  = event.target.value;
        this.isFiltering = true;
        clearTimeout(this.filterTimeout);
        this.filterTimeout = setTimeout(() => {
            this.applyFilter(this.filterTerm);
            this.isFiltering = false;
        }, 300);
    }

    applyFilter(term) {
        if (!term || !term.trim()) {
            this.filteredDisplayRows = this.allDisplayRows;
            return;
        }
        const lc    = term.toLowerCase();
        const match = str => str && str.toLowerCase().includes(lc);

        // Step 1 — keep rows where any row-group label or any value cell matches
        const filtered = this.allDisplayRows.filter(row =>
            row.groupCells.some(gc => match(gc.label)) ||
            row.values.some(v  => match(v.value))
        );

        // Step 2 — recount how many filtered rows each group-cell key appears in
        const keyCounts = {};
        filtered.forEach(row => {
            row.groupCells.forEach(gc => {
                keyCounts[gc.key] = (keyCounts[gc.key] || 0) + 1;
            });
        });

        // Step 3 — recompute isFirst, rowspan, and rowClass for the filtered set
        const seen = new Set();
        this.filteredDisplayRows = filtered.map((row, idx) => {
            const newGroupCells = row.groupCells.map(gc => {
                const isFirst = !seen.has(gc.key);
                if (isFirst) seen.add(gc.key);
                return { ...gc, isFirst, rowspan: isFirst ? keyCounts[gc.key] : gc.rowspan };
            });
            return {
                ...row,
                rowClass: idx > 0 && newGroupCells[0].isFirst ? 'matrix-row group-boundary' : 'matrix-row',
                groupCells: newGroupCells
            };
        });
    }

    // ─── Column header rows ──────────────────────────────────────────────────────
    /**
     * Builds N header rows from the ColNode tree.
     * Non-last rows show a merged corner + grouped column headers (with colspan).
     * The last row shows individual row-group label headers + leaf column headers.
     */
    get columnHeaderRows() {
        const colGroupLabels = this.matrixData?.colGroupLabels || [];
        const N = colGroupLabels.length || 1;
        const levelCells = [];
        this.collectColCells(this.matrixData?.colTree || [], 0, levelCells);

        return (levelCells.length > 0 ? levelCells : [[]]).map((cells, depth) => ({
            key:         `hr-${depth}`,
            isLast:      depth === N - 1,
            showCorner:  depth < N - 1,
            cornerLabel: depth < N - 1 ? (colGroupLabels[depth] || '') + ' \u2192' : '',
            cells
        }));
    }

    /** Depth-first traversal of the ColNode tree — populates levelCells[depth] arrays. */
    collectColCells(nodes, depth, levelCells) {
        if (!levelCells[depth]) { levelCells[depth] = []; }
        nodes.forEach(node => {
            levelCells[depth].push({
                key:      `ch-${depth}-${node.key || node.label}`,
                label:    node.label,
                colspan:  node.colspan,
                cssClass: depth === 0 ? 'col-group1-header sticky-header' : 'col-group2-header sticky-header'
            });
            if (!node.isLeaf && node.children) {
                this.collectColCells(node.children, depth + 1, levelCells);
            }
        });
    }

    // ─── Event handlers ──────────────────────────────────────────────────────────
    handleMultiFilterChange(event) {
        const fieldPath      = event.target.dataset.fieldPath;
        const selectedValues = event.detail.selectedValues;
        this.pendingFilterSelections = { ...this.pendingFilterSelections, [fieldPath]: selectedValues };
    }

    handleApplyFilters() {
        this.filterSelections = { ...this.pendingFilterSelections };
        this.loadMatrix(false);
    }

    handleRefresh() {
        this.loadMatrix(true);
    }

    handleExport() {
        if (!this.matrixData) return;
        if (!window.XLSX) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Export not ready', message: 'Excel library is still loading. Please try again.', variant: 'warning' }));
            return;
        }
        const d            = this.matrixData;
        const leftColCount = d.rowGroupLabels?.length || 1;
        const colDepth     = d.colGroupLabels?.length || 1;
        const headerRowCount = colDepth;

        const aoa    = [];
        const styles = {};
        const merges = [];

        const border    = { top: { style: 'thin', color: { rgb: 'DDDBDA' } }, bottom: { style: 'thin', color: { rgb: 'DDDBDA' } }, left: { style: 'thin', color: { rgb: 'DDDBDA' } }, right: { style: 'thin', color: { rgb: 'DDDBDA' } } };
        const hdrStyle1 = { fill: { fgColor: { rgb: 'E8E8E8' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };
        const hdrStyle2 = { fill: { fgColor: { rgb: 'F0F0F0' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };
        const rg1Style  = { fill: { fgColor: { rgb: 'F3F2F2' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };
        const rg2Style  = { fill: { fgColor: { rgb: 'F9F9F9' } },                       alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };

        this.buildExcelHeaderRows(d, leftColCount, colDepth, hdrStyle1, hdrStyle2, aoa, styles, merges);
        this.buildExcelDataRows(leftColCount, headerRowCount, rg1Style, rg2Style, border, aoa, styles, merges);

        const ws = this.buildWorksheet(aoa, merges, styles, d, leftColCount);
        const wb = window.XLSX.utils.book_new();
        window.XLSX.utils.book_append_sheet(wb, ws, (d.title || 'Matrix').slice(0, 31));
        window.XLSX.writeFile(wb, `${d.title || this.configName || 'matrix'}.xlsx`);
    }

    buildExcelHeaderRows(d, leftColCount, colDepth, hdrStyle1, hdrStyle2, aoa, styles, merges) {
        const levelCells = [];
        this.collectColCells(d.colTree || [], 0, levelCells);

        for (let hr = 0; hr < colDepth; hr++) {
            const isLast   = hr === colDepth - 1;
            const rowStyle = isLast ? hdrStyle2 : hdrStyle1;
            const row      = [];

            if (!isLast) {
                // Merged corner spanning all left cols
                row.push((d.colGroupLabels?.[hr] || '') + ' \u2192');
                for (let c = 0; c < leftColCount; c++) {
                    styles[`${hr},${c}`] = rowStyle;
                }
                if (leftColCount > 1) {
                    merges.push({ s: { r: hr, c: 0 }, e: { r: hr, c: leftColCount - 1 } });
                }
            } 
            else {
                // Individual row-group label headers
                (d.rowGroupLabels || []).forEach((lbl, i) => {
                    row.push(lbl + ' \u2193');
                    styles[`${hr},${i}`] = rowStyle;
                });
            }

            // Column headers at this depth
            let cur = leftColCount;
            (levelCells[hr] || []).forEach(cell => {
                row.push(cell.label);
                for (let c = 0; c < cell.colspan; c++) { styles[`${hr},${cur + c}`] = rowStyle; }
                if (cell.colspan > 1) { merges.push({ s: { r: hr, c: cur }, e: { r: hr, c: cur + cell.colspan - 1 } }); }
                cur += cell.colspan;
            });
            aoa.push(row);
        }
    }

    buildExcelDataRows(leftColCount, headerRowCount, rg1Style, rg2Style, border, aoa, styles, merges) {
        this.filteredDisplayRows.forEach((row, ri) => {
            const excelRow = [];
            const absRow   = headerRowCount + ri;

            row.groupCells.forEach((gc, ci) => {
                excelRow.push(gc.isFirst ? (gc.label || '') : null);
                styles[`${absRow},${ci}`] = ci === 0 ? rg1Style : rg2Style;
                if (gc.isFirst && gc.rowspan > 1) {
                    merges.push({ s: { r: absRow, c: ci }, e: { r: absRow + gc.rowspan - 1, c: ci } });
                }
            });

            (row.values || []).forEach((v, vi) => {
                excelRow.push(v.value || '');
                const bg = parseBgColor(v.inlineStyle) || 'FFFFFF';
                styles[`${absRow},${leftColCount + vi}`] = {
                    fill: { fgColor: { rgb: bg } },
                    alignment: { horizontal: 'center', vertical: 'center' },
                    border
                };
            });
            aoa.push(excelRow);
        });
    }

    buildWorksheet(aoa, merges, styles, d, leftColCount) {
        const ws = window.XLSX.utils.aoa_to_sheet(aoa);
        ws['!merges'] = merges;
        const totalCols = leftColCount + (d.columnKeys || []).length;
        ws['!cols'] = Array.from({ length: totalCols }, (_, i) => ({ wch: i < leftColCount ? 25 : 12 }));
        Object.keys(styles).forEach(key => {
            const [r, c] = key.split(',').map(Number);
            const addr = window.XLSX.utils.encode_cell({ r, c });
            if (!ws[addr]) ws[addr] = { v: '', t: 's' };
            ws[addr].s = styles[key];
        });
        return ws;
    }

    // ─── Getters ─────────────────────────────────────────────────────────────────
    get hasFilterOptions() {
        return this.filterOptions && this.filterOptions.length > 0;
    }

    get noPendingFilters() {
        return !(JSON.stringify(this.pendingFilterSelections) !== JSON.stringify(this.filterSelections));
    }

    get displayFilterOptions() {
        return this.filterOptions.map(fo => ({ ...fo, selectedValues: this.pendingFilterSelections[fo.fieldPath] || []}));
    }

    get isExportDisabled() {
        return !this.hasData;
    }

    get title() {
        return this.matrixData?.title || this.configName || '';
    }

    get hasErrors() {
        return this.errors && this.errors.length > 0;
    }

    get hasData() {
        return this.matrixData && this.matrixData.rowTree && this.matrixData.rowTree.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasErrors && !this.hasData;
    }

    /** One header entry per row-group level, used in the last thead <tr>. */
    get rowGroupHeaders() {
        return (this.matrixData?.rowGroupLabels || []).map((label, i) => ({
            key:         `rgh-${i}`,
            label:       label + ' \u2193',
            cssClass:    'corner-cell sticky-col sticky-header col-group2-header',
            stickyStyle: this.stickyStyle(i, false)
        }));
    }

    get cornerStickyStyle() {
        return `left: 0px; background-color: rgb(${STICKY_BG_BASE}, ${STICKY_BG_BASE}, ${STICKY_BG_BASE});`;
    }

    stickyStyle(depth, isBodyCell) {
        const left = depth * STICKY_COL_WIDTH;
        const v    = Math.min(255, Math.round(STICKY_BG_BASE + depth * STICKY_BG_STEP));
        const bg   = `rgb(${v}, ${v}, ${v})`;
        let style  = `left: ${left}px; width: ${STICKY_COL_WIDTH}px; min-width: ${STICKY_COL_WIDTH}px; max-width: ${STICKY_COL_WIDTH}px; background-color: ${bg};`;
        if (isBodyCell) {
            style += ` font-weight: ${depth === 0 ? 700 : 500};`;
            style += (depth === 0)? ' border-right: 2px solid #dddbda;' : '';
        }
        return style;
    }

    /** Number of sticky left columns = number of active row-group levels. */
    get cornerColspan() {
        return this.matrixData?.rowGroupLabels?.length || 1;
    }
}