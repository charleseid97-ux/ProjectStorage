import { LightningElement, api } from 'lwc';
import { LABELS } from 'c/gridBuilderUtils';

export default class GridSelectionDisplayPanel extends LightningElement {
    @api columns = [];
    @api rows = [];
    @api allRows = [];
    @api criteriaList = [];
    @api isOpen = false;
    @api showExcludedOnly = false;

    labels = LABELS;
    openProductIds = [];
    showCriteriaHistory = false;

    get productSelectedCount() {
        return this.includedProducts.length;
    }

    get productExcludedCount() {
        return this.excludedProducts.length;
    }

    get includedToggleLabel() {
        return this.includedAllExpanded ? this.labels.UI_CollapseAll : this.labels.UI_ExpandAll;
    }

    get excludedToggleLabel() {
        return this.excludedAllExpanded ? this.labels.UI_CollapseAll : this.labels.UI_ExpandAll;
    }

    get backdropClass() {
        return `selection-panel-backdrop ${this.isOpen ? 'is-open' : ''}`;
    }

    get selectedIds() {
        return new Set((this.rows || []).map(r => r.id));
    }

    get productGroups() {
        const rows = (this.allRows && this.allRows.length) ? this.allRows : (this.rows || []);
        const selectedIds = this.selectedIds;
        const criteriaNumberMap = this.buildCriteriaNumberMap();
        const selectedRowMap = this.buildSelectedRowMap();
        const groupMap = new Map();

        rows.forEach(row => {
            const selectedRow = selectedRowMap.get(row.id);
            const effectiveRow = selectedRow ? { ...row, ...selectedRow } : row;
            const productId = row.productId || 'unknown';
            const productLabel = row.productLabel || this.labels.Grid_ProductNameLabel;
            if (!groupMap.has(productId)) {
                groupMap.set(productId, {
                    productId: productId,
                    productLabel: productLabel,
                    shareClasses: [],
                    gridLabels: new Set(),
                    selectedCount: 0,
                    totalShareClasses: 0
                });
            }
            const group = groupMap.get(productId);
            const isSelected = selectedIds.has(effectiveRow.id);
            const criteriaNumber = isSelected ? this.getCriteriaNumber(effectiveRow.criteriaRefId, criteriaNumberMap) : '';
            group.totalShareClasses += 1;
            if (isSelected) {
                group.selectedCount += 1;
                const gridLabel = effectiveRow.gridLabel || (effectiveRow.cells || []).find(c => c.label === 'Grid')?.value || '';
                if (gridLabel) {
                    group.gridLabels.add(gridLabel);
                }
            }
            group.shareClasses.push({
                ...effectiveRow,
                isSelected: isSelected,
                criteriaNumber: criteriaNumber,
                rowClass: isSelected ? '' : 'row-unselected'
            });
        });

        const openSet = new Set(this.openProductIds);
        return Array.from(groupMap.values()).map(group => {
            group.shareClasses.sort((left, right) => {
                const leftSelected = left.isSelected ? 1 : 0;
                const rightSelected = right.isSelected ? 1 : 0;
                return rightSelected - leftSelected;
            });
            const isOpen = openSet.has(group.productId);
            return {
                ...group,
                gridLabelText: Array.from(group.gridLabels).join(', '),
                isOpen: isOpen,
                toggleIconName: isOpen ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    get includedProducts() {
        return this.productGroups.filter(p => p.selectedCount > 0);
    }

    get excludedProducts() {
        return this.productGroups.filter(p => p.selectedCount === 0);
    }

    get includedAllExpanded() {
        const ids = this.includedProducts.map(p => p.productId);
        return ids.length > 0 && ids.every(id => this.openProductIds.includes(id));
    }

    get excludedAllExpanded() {
        const ids = this.excludedProducts.map(p => p.productId);
        return ids.length > 0 && ids.every(id => this.openProductIds.includes(id));
    }

    get criteriaHistory() {
        const criteriaEntries = this.criteriaList || [];
        return criteriaEntries.map((entry, index) => {
            const number = index + 1;
            const gridLabel = entry.gridLabel || '';
            const criteria = entry.criteria || {};
            const logicType = criteria.FilterLogic__c || '';
            const logicExpression = criteria.FilterLogicExpression__c || '';
            const details = (entry.criteriaDetails || []).map(detail => this.formatCriteriaDetail(detail)).filter(detail => detail);
            const userDetails = details.filter(detail => detail.techOrigin !== 'System');
            const systemDetails = details.filter(detail => detail.techOrigin === 'System');
            const shareTypes = Array.isArray(entry.shareTypes) ? entry.shareTypes : [];
            return {
                number,
                gridLabel,
                logicType,
                logicExpression,
                userDetails,
                systemDetails,
                shareTypesText: shareTypes.length ? shareTypes.join('; ') : this.labels.UI_NA
            };
        });
    }

    get hasCriteriaHistory() {
        return this.criteriaHistory.length > 0;
    }

    get disabledCriteriaHistory() {
        return !this.hasCriteriaHistory;
    }

    handleToggleProduct(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) {
            return;
        }
        this.handleToggle([{ productId: id }], this.openProductIds.includes(id));
    }

    handleToggleIncluded() {
        this.handleToggle(this.includedProducts, this.includedAllExpanded);
    }

    handleToggleExcluded() {
        this.handleToggle(this.excludedProducts, this.excludedAllExpanded);
    }

    handleToggle(products, isAllExpanded) {
        const ids = products.map(p => p.productId);
        const next = new Set(this.openProductIds);
        if (isAllExpanded) {
            ids.forEach(id => next.delete(id));
        }
        else {
            ids.forEach(id => next.add(id));
        }
        this.openProductIds = Array.from(next);
    }

    handleRemoveProduct(event) {
        event.stopPropagation();
        const productId = event.currentTarget.dataset.id;
        if (!productId) {
            return;
        }
        this.dispatchEvent(new CustomEvent('removeproduct', {
            detail: { productId: productId }
        }));
    }

    toggleCriteriaHistory() {
        this.showCriteriaHistory = !this.showCriteriaHistory;
    }

    closeCriteriaHistory() {
        this.showCriteriaHistory = false;
    }

    handleClose() {
        this.showCriteriaHistory = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('selection-panel-backdrop')) {
            this.handleClose();
        }
    }

    buildCriteriaNumberMap() {
        const map = new Map();
        (this.criteriaList || []).forEach((entry, index) => {
            if (entry?.id) {
                map.set(entry.id, index + 1);
            }
        });
        return map;
    }

    getCriteriaNumber(criteriaRefId, mapRef) {
        if (!criteriaRefId || !mapRef) {
            return '';
        }
        return mapRef.get(criteriaRefId) || '';
    }

    formatCriteriaDetail(detail) {
        if (!detail) {
            return null;
        }
        const rawObjectLabel = detail.objectLabel ?? detail.ObjectLabel__c;
        const rawFieldLabel = detail.fieldLabel ?? detail.FieldLabel__c;
        const objectLabel = rawObjectLabel || this.labels.UI_UnknownObject;
        let fieldLabel = rawFieldLabel || this.labels.UI_UnknownField;
        const objectBlank = !rawObjectLabel || !rawObjectLabel.trim();
        const fieldBlank = !rawFieldLabel || !rawFieldLabel.trim();
        if ((objectBlank && fieldBlank) || (objectLabel === this.labels.UI_UnknownObject && fieldLabel === this.labels.UI_UnknownField)) {
            return null;
        }
        const objectApi = detail.Object__c || detail.objectApi || '';
        const fieldApi = detail.Field__c || detail.fieldApi || '';
        const operatorText = detail.Logic__c || detail.operator || detail.Operator__c || detail.logic || '';
        const value = detail.Value__c || detail.value || '';
        let displayValue = value && value.trim() ? value : this.labels.UI_NA;
        const techOrigin = detail.TECHOrigin__c || detail.techOrigin || '';

        if (objectApi === 'Product__c' && fieldApi === 'ProductName__c') {
            fieldLabel = this.getInternalShortNameLabel();
            const nameMap = this.buildProductNameToShortNameMap();
            if (nameMap.size > 0) {
                const separator = '; ';
                displayValue = displayValue.split(separator).map(v => nameMap.get(v.trim()) || v.trim()).join(separator);
            }
        }

        const keyParts = [objectLabel, fieldLabel, operatorText, displayValue, techOrigin].filter(part => part);
        const operatorClassMap = {'=': 'op-positive', 'IN': 'op-positive', 'LIKE': 'op-positive',
                                  '!=': 'op-negative', 'NOT IN': 'op-negative', 'NOT LIKE': 'op-negative'};
        return {
            key: keyParts.join('|'),
            objectLabel: objectLabel,
            fieldLabel: fieldLabel,
            operatorText: operatorText,
            operatorClass: `criteria-operator ${operatorClassMap[operatorText] || 'op-neutral'}`,
            valueText: displayValue,
            techOrigin: techOrigin
        };
    }

    buildProductNameToShortNameMap() {
        const cols = this.columns || [];
        const productNameCol = cols.find(c => c.apiName === 'Fund__r.ProductName__c');
        const shortNameCol = cols.find(c => c.apiName === 'Fund__r.InternalShortName__c');
        if (!productNameCol || !shortNameCol) return new Map();

        const map = new Map();
        const rows = (this.allRows && this.allRows.length) ? this.allRows : (this.rows || []);
        rows.forEach(row => {
            const pnCell = (row.cells || []).find(c => c.label === productNameCol.label);
            const snCell = (row.cells || []).find(c => c.label === shortNameCol.label);
            if (pnCell?.value && snCell?.value) {
                map.set(pnCell.value, snCell.value);
            }
        });
        return map;
    }

    getInternalShortNameLabel() {
        const col = (this.columns || []).find(c => c.apiName === 'Fund__r.InternalShortName__c');
        return col ? col.label : 'Internal Short Name';
    }

    buildSelectedRowMap() {
        const map = new Map();
        (this.rows || []).forEach(row => {
            if (row?.id) {
                map.set(row.id, row);
            }
        });
        return map;
    }
}