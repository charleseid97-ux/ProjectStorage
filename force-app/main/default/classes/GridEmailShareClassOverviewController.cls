/** ──────────────────────────────────────
 * @description VF component controller for the Share Class Overview section
 *              of the GridAmendmentPendingApprovalV2 email template.
 *              Delegates data fetching to StandardGridProductAndRulesController
 *              and exposes VF-friendly wrapper objects with the same
 *              filteredUnrestricted logic as the LWC.
 * @author Charles EID
────────────────────────────────────── */
public with sharing class GridEmailShareClassOverviewController {

    public Id gridId { get; set; }

    private StandardGridProductAndRulesController.ShareClassComposition cachedComp;
    private StandardGridProductAndRulesController.ShareClassComposition comp {
        get {
            if (cachedComp == null && gridId != null) {
                cachedComp = StandardGridProductAndRulesController.getShareClassComposition(gridId);
            }
            return cachedComp;
        }
    }

    public Boolean getHasExcluded() {
        return comp != null && !comp.excludedFundShortNames.isEmpty();
    }

    public Boolean getHasRestricted() {
        return comp != null && !comp.restricted.isEmpty();
    }

    public Boolean getHasUnrestricted() {
        return comp != null && !comp.unrestricted.isEmpty();
    }

    public List<String> getExcluded() {
        return comp != null ? comp.excludedFundShortNames : new List<String>();
    }

    public List<StandardGridProductAndRulesController.ShareTypeGroup> getRestricted() {
        return comp != null ? comp.restricted : new List<StandardGridProductAndRulesController.ShareTypeGroup>();
    }

    public List<ShareTypeGroupWrapper> getFilteredUnrestricted() {
        if (comp == null) return new List<ShareTypeGroupWrapper>();
        Set<String> excluded = new Set<String>(comp.excludedFundShortNames);
        List<ShareTypeGroupWrapper> result = new List<ShareTypeGroupWrapper>();
        for (StandardGridProductAndRulesController.ShareTypeGroup g : comp.unrestricted) {
            ShareTypeGroupWrapper w = new ShareTypeGroupWrapper();
            w.shareType   = g.shareType;
            w.isAllFunds  = g.isAllFunds;
            w.products    = new List<String>();
            for (String p : g.productShortNames) {
                if (!excluded.contains(p)) w.products.add(p);
            }
            w.missing = new List<String>();
            for (String p : g.missingShortNames) {
                if (!excluded.contains(p)) w.missing.add(p);
            }
            w.hasProducts = !w.products.isEmpty();
            w.hasMissing  = !w.missing.isEmpty();
            result.add(w);
        }
        return result;
    }

    public class ShareTypeGroupWrapper {
        public String shareType       { get; set; }
        public Boolean isAllFunds     { get; set; }
        public List<String> products  { get; set; }
        public List<String> missing   { get; set; }
        public Boolean hasProducts    { get; set; }
        public Boolean hasMissing     { get; set; }
    }
}