import { LightningElement, api } from 'lwc';

function formatRate(rate) {
    if (rate == null) return '';
    return `${Number(rate).toFixed(2)}%`;
}

function parseStyle(jsonStr) {
    if (!jsonStr) return '';
    try {
        const obj = JSON.parse(jsonStr);
        return Object.entries(obj)
            .map(([k, v]) => `${k.replace(/([A-Z])/g, m => `-${m.toLowerCase()}`)}: ${v}`)
            .join('; ');
    } catch {
        return '';
    }
}

export default class StandardGridGroupList extends LightningElement {
    @api groups;

    get processedGroups() {
        return (this.groups || []).map((group, i) => {
            const hoverData = group.hoverData;
            const hoverRules = (hoverData?.rules || []).map((rule, k) => ({
                key: k,
                text: rule.internalShortName ? `${rule.shareType || ''} | ${rule.internalShortName}: ${rule.ruleText || ''}` : `${rule.shareType || ''}: ${rule.ruleText || ''}`,
                style: parseStyle(rule.style)
            }));
            return {
                key: i,
                gridName: group.gridName,
                productCount: (group.products || []).length,
                products: (group.products || []).map((p, j) => ({
                    key: `${i}-${j}`,
                    value: p.shortName,
                    tooltip: Object.entries(p.shareClassRates || {}).map(([name, rate]) => rate != null ? `${name} - Rebate: ${formatRate(rate)}` : name).join('\n')
                })),
                hasHoverData: hoverRules.length > 0,
                hoverRules
            };
        });
    }

    handleBadgeEnter(event) {
        const fund = event.currentTarget.dataset.fund;
        this.dispatchEvent(new CustomEvent('fundhover', { bubbles: true, composed: true, detail: fund }));
    }

    handleBadgeLeave() {
        this.dispatchEvent(new CustomEvent('fundhover', { bubbles: true, composed: true, detail: null }));
    }

    @api
    applyHighlight(fund) {
        this.template.querySelectorAll('[data-fund]').forEach(el => {
            el.classList.remove('badge-fund-highlight');
            if (fund && el.dataset.fund === fund) el.classList.add('badge-fund-highlight');
        });
    }
}