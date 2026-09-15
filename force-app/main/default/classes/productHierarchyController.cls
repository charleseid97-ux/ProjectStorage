public with sharing class productHierarchyController {

    /* ----------- DTO for product ----------- */
    public class ItemDTO {
        public String label {get; set;} // label is the name of the product (the shown title on tree)
        public String type {get; set;} // the record type of the product
        public String name {get; set;} // the name of the product 
        public String href {get; set;} // link to the product page in the org
        public String investstyle {get; set;} // investment style for product of type strategy only
        public String isin {get; set;} // isin code for share classes
        public Boolean currentproduct {get; set;} // whether the selected product is the current product shown to the user or not
        public Boolean isvalid {get; set;} // whether the item is valid or not (Validty__c)
        public Boolean isproduct {get; set;} // whether the item is a product or a share class 
        public Boolean expanded {get; set;} // whether the item is expanded (on tree) or not
        public List<ItemDTO> items {get; set;} // items related to the selected item (tree architecture)
        public Boolean ishighlevel {get; set;}
        public String regionalFocusId {get; set;}
        public String assetClassId {get; set;}
        public String id {get; set;}
        public String assetclass {get; set;}
        public String regionalfocus {get; set;}
        public String ytdnet {get; set;}
        public String aum {get; set;}
        public String lastaum {get; set;}
        
        public ItemDTO(){}

        public ItemDTO(String label, String type, String name, String href, String investstyle, String isin, Boolean currentproduct, Boolean isvalid, Boolean isproduct, Boolean expanded, List<ItemDTO> items) {
            this.label = label;
            this.type = type;
            this.name = name;
            this.href = href;
            this.investstyle = investstyle;
            this.isin = isin;
            this.currentproduct = currentproduct;
            this.isvalid = isvalid;
            this.isproduct = isproduct;
            this.expanded = expanded;
            this.items =  items;
        }
    }
}