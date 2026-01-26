import { LightningElement, api } from 'lwc';

export default class GridSelectionDisplayPanel extends LightningElement {
    @api columns = [];
    @api rows = [];
    @api allRows = [];
    @api criteriaList = [];
    @api isOpen = false;
    @api showExcludedOnly = false;
    openProductIds = [];
    showCriteriaHistory = false;

    get productSelectedCount() {
        return this.includedProducts.length;
    }

    get productExcludedCount() {
        return this.excludedProducts.length;
    }

    get includedToggleLabel() {
        return this.includedAllExpanded ? 'Collapse All' : 'Expand All';
    }

    get excludedToggleLabel() {
        return this.excludedAllExpanded ? 'Collapse All' : 'Expand All';
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
            const productLabel = row.productLabel || 'Product';
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
                shareTypesText: shareTypes.length ? shareTypes.join('; ') : 'N/A'
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
        const objectLabel = rawObjectLabel || 'Unknown Object';
        const fieldLabel = rawFieldLabel || 'Unknown Field';
        const objectBlank = !rawObjectLabel || !rawObjectLabel.trim();
        const fieldBlank = !rawFieldLabel || !rawFieldLabel.trim();
        if ((objectBlank && fieldBlank) || (objectLabel === 'Unknown Object' && fieldLabel === 'Unknown Field')) {
            return null;
        }
        const operatorText = detail.Logic__c || detail.operator || detail.Operator__c || detail.logic || '';
        const value = detail.Value__c || detail.value || '';
        const displayValue = value && value.trim() ? value : 'N/A';
        const techOrigin = detail.TECHOrigin__c || detail.techOrigin || '';
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