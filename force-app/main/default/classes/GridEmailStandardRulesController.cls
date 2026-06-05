/** ──────────────────────────────────────
 * @description VF component controller for the Standard Grid Rules section
 *              of the GridAmendmentPendingApprovalV2 email template.
 *              Delegates data fetching to StandardGridProductAndRulesController
 *              and exposes VF-friendly wrapper objects.
 * @author Charles EID
────────────────────────────────────── */
public with sharing class GridEmailStandardRulesController {

    public Id gridId { get; set; }

    private List<GroupWrapper> cachedGroups;
    public List<GroupWrapper> groups {
        get {
            if (cachedGroups == null) {
                cachedGroups = buildGroups();
            }
            return cachedGroups;
        }
    }

    public Boolean getHasGroups() {
        return !groups.isEmpty();
    }

    private List<GroupWrapper> buildGroups() {
        List<GroupWrapper> result = new List<GroupWrapper>();
        if (gridId == null) return result;
        for (GridRecapHelper.StandardGridGroup g : StandardGridProductAndRulesController.getStandardGridData(gridId)) {
            GroupWrapper w   = new GroupWrapper();
            w.gridName       = g.gridName;
            w.productCount   = g.products.size();
            w.products       = g.products;
            w.rules          = new List<RuleWrapper>();
            if (g.hoverData != null) {
                for (GridRecapHelper.RuleEntry r : g.hoverData.rules) {
                    RuleWrapper rw = new RuleWrapper();
                    rw.text = String.isNotBlank(r.internalShortName) ? r.shareType + ' | ' + r.internalShortName + ': ' + r.ruleText : r.shareType + ': ' + r.ruleText;
                    w.rules.add(rw);
                }
            }
            w.hasRules = !w.rules.isEmpty();
            result.add(w);
        }
        return result;
    }

    public class GroupWrapper {
        public String gridName                            { get; set; }
        public Integer productCount                       { get; set; }
        public List<GridRecapHelper.ProductEntry> products { get; set; }
        public List<RuleWrapper> rules                    { get; set; }
        public Boolean hasRules                           { get; set; }
    }

    public class RuleWrapper {
        public String text { get; set; }
    }
}