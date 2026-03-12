import { LightningElement, api } from 'lwc';

const RULE_POF  = 'Percentage of Fees';
const RULE_OST  = 'Take Rebates Rate - Other Share Type';
const RULE_OSTF = 'Take Rebates Rate - Other Share Type + Fees';
const RULE_OGR  = 'Take Rebates Rate - Other Grid Rule';

const RULE_COLOR_CLASS = {
    [RULE_POF]:  'rule-pof',
    [RULE_OST]:  'rule-ost',
    [RULE_OSTF]: 'rule-ostf',
    [RULE_OGR]:  'rule-ogr'
};

function formatRate(rate) {
    if (rate == null) return '';
    return `${Number(rate).toFixed(2)}%`;
}

function buildRuleRow(rule, gi, k) {
    const inNames    = (rule.inCriteria    || []).flatMap(v => v.split(';')).map(v => v.trim()).filter(v => v);
    const notInNames = (rule.notInCriteria || []).flatMap(v => v.split(';')).map(v => v.trim()).filter(v => v);
    return {
        key: `${gi}-${k}`,
        boldLabel: inNames.length > 0 ? `${rule.shareType || ''} - ${inNames.join(', ')}` : (rule.shareType || ''),
        ruleDetail: buildRuleDetail(rule),
        colorClass: RULE_COLOR_CLASS[rule.ruleToApply] || '',
        hasNotInCriteria: notInNames.length > 0,
        notInCriteriaText: notInNames.join(', ')
    };
}

function buildHoverRuleGroups(hoverData) {
    const groupsMap = new Map();
    (hoverData?.rules || []).forEach(rule => {
        const lf = (rule.legalForms || []).slice().sort();
        const key = lf.join(';');
        if (!groupsMap.has(key)) groupsMap.set(key, { lf, rules: [] });
        groupsMap.get(key).rules.push(rule);
    });
    return Array.from(groupsMap.entries())
        .sort(([a], [b]) => (b ? -1 : 1) - (a ? -1 : 1))
        .map(([, grp], gi) => ({
            key: gi,
            hasLegalForms: true,
            legalFormsText: grp.lf.length > 0 ? `Below only applies to ${grp.lf.join(', ')}` : 'Below applies to all legal forms',
            rules: grp.rules.map((rule, k) => buildRuleRow(rule, gi, k))
        }));
}

function buildRuleDetail(rule) {
    if (rule.finalRebateRate != null) {
        return `${Number(rule.finalRebateRate).toFixed(2)}% rebates`;
    }
    switch (rule.ruleToApply) {
        case RULE_POF:  return `${formatRate(rule.gridRate)} of MF`;
        case RULE_OST:  return `Rebates${rule.otherShareType || ''}`;
        case RULE_OSTF: return `Rebates${rule.otherShareType || ''} + Fees(${rule.shareType}-${rule.otherShareType || ''})*${formatRate(rule.gridRate)}`;
        case RULE_OGR:  return `Rebates - Other Grid: ${rule.otherGridRule || ''}`;
        default:        return rule.ruleToApply || '';
    }
}

export default class StandardGridGroupList extends LightningElement {
    @api groups;

    get processedGroups() {
        return (this.groups || []).map((group, i) => {
            const hoverData = group.hoverData;
            return {
                key: i,
                gridName: group.gridName,
                productCount: (group.products || []).length,
                products: (group.products || []).map((p, j) => ({
                    key: `${i}-${j}`,
                    value: p.shortName,
                    tooltip: Object.entries(p.shareClassRates || {}).map(([name, rate]) => rate != null ? `${name} - Rebate: ${formatRate(rate)}` : name).join('\n')
                })),
                hasHoverData: !!hoverData && (hoverData.rules || []).length > 0,
                hoverRuleGroups: buildHoverRuleGroups(hoverData)
            };
        });
    }
}