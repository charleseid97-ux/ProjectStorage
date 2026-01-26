import { LightningElement, api, track } from 'lwc';

export default class ResultsTable extends LightningElement {
    @api columns = [];
    @api rows = [];
    @api selectedShareClasses = [];
    @api paginationInfo = {};
    @track openProductIds = new Set();

    get productGroups() {
        const selectedIds = new Set((this.selectedShareClasses || []).map(row => row.id));
        const map = new Map();
        (this.rows || []).forEach(row => {
            const productId = row.productId || 'unknown';
            const productLabel = row.productLabel || 'Product';
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
            if (isAlreadySelected) {
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
        return this.allExpanded ? 'Collapse All' : 'Expand All';
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