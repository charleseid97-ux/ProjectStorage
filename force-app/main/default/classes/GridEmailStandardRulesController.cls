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
        for (GridRecapHelper.StandardGridGroup g : GridRecapHelper.buildStandardGridGroups(gridId, false)) {
            GroupWrapper w = new GroupWrapper();
            w.gridName     = g.gridName;
            w.productCount = g.products.size();
            w.products     = g.products;
            result.add(w);
        }
        return result;
    }

    public class GroupWrapper {
        public String gridName                             { get; set; }
        public Integer productCount                        { get; set; }
        public List<GridRecapHelper.ProductEntry> products { get; set; }
    }
}