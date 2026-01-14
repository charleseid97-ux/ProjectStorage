import { LightningElement, api } from 'lwc';

export default class GridSelectionDisplayPanel extends LightningElement {
    @api columns = [];
    @api rows = [];
    @api allRows = [];
    @api isOpen = false;
    openProductIds = [];

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
        const groupMap = new Map();

        rows.forEach(row => {
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
            const isSelected = selectedIds.has(row.id);
            group.totalShareClasses += 1;
            if (isSelected) {
                group.selectedCount += 1;
                const gridLabel = row.gridLabel || (row.cells || []).find(c => c.label === 'Grid')?.value || '';
                if (gridLabel) {
                    group.gridLabels.add(gridLabel);
                }
            }
            group.shareClasses.push({
                ...row,
                rowClass: isSelected ? 'row-selected' : ''
            });
        });

        const openSet = new Set(this.openProductIds);
        return Array.from(groupMap.values()).map(group => {
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

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('selection-panel-backdrop')) {
            this.handleClose();
        }
    }
}