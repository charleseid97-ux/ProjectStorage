import { LightningElement, api, track } from 'lwc';
import { LABELS } from 'c/gridBuilderUtils';

export default class ResultsTable extends LightningElement {
    @api columns = [];
    @api rows = [];
    @api selectedShareClasses = [];
    @api paginationInfo = {};
    @track openProductIds = new Set();

    labels = LABELS;

    get productGroups() {
        const selectedIds = new Set((this.selectedShareClasses || []).map(row => row.id));
        const selectedProductIds = new Set((this.selectedShareClasses || []).map(row => row.productId));
        const map = new Map();
        (this.rows || []).forEach(row => {
            const productId = row.productId || 'unknown';
            const productLabel = row.productLabel || this.labels.Grid_ProductNameLabel;
            if (!map.has(productId)) {
                map.set(productId, {
                    productId,
                    productLabel,
                    shareClasses: [],
                    hasSelected: false
                });
            }
            const group = map.get(productId);
            const isAlreadySelected = selectedIds.has(row.id);
            group.shareClasses.push({ ...row, isAlreadySelected: isAlreadySelected });
            if (isAlreadySelected || selectedProductIds.has(productId)) {
                group.hasSelected = true;
            }
        });
        return Array.from(map.values()).map(prod => {
            const isOpen = this.openProductIds.has(prod.productId);
            return {
                ...prod,
                isOpen,
                toggleIconName: isOpen ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    get showTable() {
        return this.productGroups && this.productGroups.length > 0;
    }

    get allExpanded() {
        const ids = this.allProductIds;
        return ids.length > 0 && ids.every(id => this.openProductIds.has(id));
    }

    get toggleAllLabel() {
        return this.allExpanded ? this.labels.UI_CollapseAll : this.labels.UI_ExpandAll;
    }

    get allProductIds() {
        const ids = new Set();
        (this.rows || []).forEach(row => {
            ids.add(row.productId || 'unknown');
        });
        return Array.from(ids);
    }

    handleToggleProduct(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.openProductIds);
        if (next.has(id)) {
            next.delete(id);
        }
        else {
            next.add(id);
        }
        this.openProductIds = next;
    }

    handleToggleAll() {
        if (this.allExpanded) {
            this.openProductIds = new Set();
        }
        else {
            this.openProductIds = new Set(this.allProductIds);
        }
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

    @api resetProductExpansions() {
        this.openProductIds = new Set();
    }
}