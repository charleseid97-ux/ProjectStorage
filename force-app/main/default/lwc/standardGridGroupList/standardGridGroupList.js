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

function buildResolvedDetail(rule) {
    switch (rule.resolvedRuleToApply) {
        case RULE_POF:  return `${RULE_POF}: ${formatRate(rule.resolvedGridRate)}`;
        case RULE_OST:  return `${RULE_OST}: ${rule.resolvedOtherShareType || ''}`;
        case RULE_OSTF: return `${RULE_OSTF}: ${rule.resolvedOtherShareType || ''} | ${formatRate(rule.resolvedGridRate)}`;
        default:        return rule.resolvedRuleToApply || '';
    }
}

function buildRuleDetail(rule) {
    switch (rule.ruleToApply) {
        case RULE_POF:  return `${RULE_POF}: ${formatRate(rule.gridRate)}`;
        case RULE_OST:  return `${RULE_OST}: ${rule.otherShareType || ''}`;
        case RULE_OSTF: return `${RULE_OSTF}: ${rule.otherShareType || ''} | ${formatRate(rule.gridRate)}`;
        case RULE_OGR:  return `${RULE_OGR}: ${rule.otherGridRule || ''}`;
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
                hasHoverData: !!hoverData && ((hoverData.legalForms || []).length > 0 || (hoverData.rules || []).length > 0),
                hoverLegalForms: hoverData && (hoverData.legalForms || []).length > 0 ? `Below only applies for ${hoverData.legalForms.join(', ')}` : null,
                hoverRules: (hoverData?.rules || []).map((rule, k) => ({
                    key: k,
                    boldLabel: `${rule.shareType} - ${(rule.internalShortNames || []).join(', ')}`,
                    ruleDetail: buildRuleDetail(rule),
                    colorClass: RULE_COLOR_CLASS[rule.ruleToApply] || '',
                    hasResolvedDetail: !!rule.resolvedRuleToApply,
                    resolvedDetail: rule.resolvedRuleToApply ? buildResolvedDetail(rule) : null
                }))
            };
        });
    }
}