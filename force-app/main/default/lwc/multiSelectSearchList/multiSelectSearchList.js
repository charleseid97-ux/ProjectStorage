/* eslint-disable @lwc/lwc/no-api-reassignments */
/**
 * @description	:
 * @author		: Thanina YAYA
 * @history
 * [25-10-2024]		[SILA Nicolas]
 * [16-12-2025]		[EID Charles]	  [Add showValuesWhenNotSelecting feature]
 * [23-01-2025]		[EID Charles]	  [Add enableSelectAll feature]
**/
import { LightningElement, api, track } from 'lwc';

export default class MultiSelectSearchList extends LightningElement {
   
    @api width = 100;
    @api variant = '';
    @api monoSelect = false;
    @api initDataTable;
    @api selectedVals=[];
    @api value = [];
    @api dropdownLength = 10;
    @api options=[];
    @api label;
    @api helptext='';
    @api requiredLabel = false;
    @api moreSearchingFields=[];
    @api disabled =false;
    @api enableSelectAll = false;

    @api pillIcon = '';
    @api disPillsAsLink = false;
    @api diplayPills = false;

    @api isTranslationComponent = false;

    @api showValuesWhenNotSelecting = false;
	  @api dropdownValueSeparator = ';';

    //@track pills=[];
    @track optionsSaved = [];

    selectedLabel='';
    inDropdown = false;
    isOpen = false;
    searchKey;
	  savedSearchKey;
    isListMouseEnt = false;
    isListMouseLeav = false;
    isDivMouseEnt = false;
    isDivMouseLeav = false;
   
 
    get labelStyle() {
      return this.variant === 'label-hidden' ? ' slds-hide' : ' slds-form-element__label ' ;
    }
 
    get dropdownOuterStyle(){
      return 'slds-var-p-left_x-small slds-dropdown slds-dropdown_fluid slds-dropdown_length-' + this.dropdownLength;
    }

    get mainDivClass(){
      let style = ' slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
      return this.isOpen ? ' slds-is-open ' + style : style;
    }
 
    get showPills(){
      if(this.diplayPills && this.pills && this.pills.length) return true;
      return false;
    }

    get showSelectAll(){
      return this.enableSelectAll && !this.monoSelect;
    }

    get selectAllLabel(){
      return this.isAllSelected ? 'Deselect all' : 'Select all';
    }

    get isAllSelected(){
      const allValues = this.getAllOptionValues();
      if (!allValues.length) {
        return false;
      }
      const selected = Array.isArray(this.value) ? this.value : [];
      return allValues.every(val => selected.includes(val));
    }

    get pills(){
       let listPills = [];
       if(!this.monoSelect && this.value.length){
          listPills = [...this.selectionPills(this.options,this.pillIcon,this.value,this.disPillsAsLink)];  
      } else listPills = undefined;
       return listPills;
    }
	
	connectedCallback() {
		if(this.showValuesWhenNotSelecting) {
			this.searchKey = this.value.join(this.dropdownValueSeparator);
		}
	}
   
    renderedCallback(){
		if(!(this.optionsSaved && this.optionsSaved.length)){
			this.optionsSaved = [...this.options];
      	}
    }
   
    @api refreshOptions(newoptions){
        this.optionsSaved = [...newoptions];
    }

    @api reset() {
        this.value = [];
        this.searchKey = '';
        this.savedSearchKey = '';
    }
 
   
 
    openDropdown(){
		this.isOpen = true;
		if(this.showValuesWhenNotSelecting) {
			this.searchKey = this.savedSearchKey;
		}
    }
    closeDropdown(event){
		if(this.showValuesWhenNotSelecting) {
			this.isOpen = (event?.type === 'focus');
			this.savedSearchKey = this.searchKey;
			this.searchKey = this.value.join(this.dropdownValueSeparator);
		} 
		else {
			this.isOpen = false;
		}
    }
 
    handleClick(event){
		if(this.isOpen === true) {
			this.closeDropdown();
		} 
		else {
			event.stopImmediatePropagation();
			this.openDropdown();
		}
    }
    handleMouseEntDiv(){
       this.isDivMouseEnt = true;
       this.isDivMouseLeav = false;
    }
    handleMouseEntList(){
       this.isListMouseEnt = true;
       this.isListMouseLeav = false;
    }
    handleMouseLeavDiv(){
      this.isDivMouseLeav = true;
      this.isDivMouseEnt = false;
      if(!this.isListMouseEnt) this.closeDropdown();
      else this.openDropdown();
    }
    handleMouseLeavList(){
      this.isListMouseLeav = true;
      this.isListMouseEnt = false;
      if(!this.isDivMouseEnt) this.closeDropdown();
      else this.openDropdown();
    }
 
    selectedLabelFind()
    {
        if(this.monoSelect){
              const index = this.options.findIndex(opt => opt.value === this.value);
              if(index > -1) this.selectedLabel = this.options[index].label;
        }
    }
    // Selection changed ...
    handleChange(event) {
            //let listPills = [];
            this.value = event.detail.value;
            if(this.monoSelect) this.selectedLabelFind(); //needed only in monoSelect Case;
            this.searchKey = this.showValuesWhenNotSelecting && !this.isOpen? this.value.join(this.dropdownValueSeparator) : '';
            this.options = [...this.optionsSaved];
            this.dispatchSearchChange(event, false);
    }

    handleSelectAllToggle(event) {
      if (this.disabled) {
        return;
      }
      const checked = event.target.checked;
      const allValues = this.getAllOptionValues();
      this.value = checked ? [...allValues] : [];
      this.searchKey = this.showValuesWhenNotSelecting && !this.isOpen ? this.value.join(this.dropdownValueSeparator) : '';
      this.options = [...this.optionsSaved];
      this.dispatchSearchChange(event, false);
    }

    getAllOptionValues() {
      const source = (this.optionsSaved && this.optionsSaved.length) ? this.optionsSaved : (this.options || []);
      return source.map(option => option.value);
    }
 
    handleChangeSearch(event)
    {
      this.searchKey = event.target.value;
      if(this.isOpen === false) this.openDropdown();
      const rows = [...this.optionsSaved];
      if(this.searchKey !== undefined && this.searchKey.length > 0  )
          {
            let filteredData = [];
            filteredData = rows.filter( word =>
              (!this.monoSelect && (this.value && (word.value === this.value.find(element => element === word.value ))))
              || (this.monoSelect && ( word.value === this.value))
              || !this.searchKey ||
              ((word.label).toLowerCase().indexOf(this.searchKey.trim().toLowerCase()) > -1)
              //need to search on all fields
              || (this.moreSearchingFields && this.moreSearchingFields.length > 0 && this.searchInOtherFields(word,this.searchKey.trim()))
            );
              this.options = [...filteredData];
      }
      else{
          this.options = [...this.optionsSaved];
      }
      this.dispatchSearchChange(event, true);
      }
 
      searchInOtherFields(word,key)
      {
        let bolAll = false;
        this.moreSearchingFields.forEach(field => {
            if((word[field])?.toLowerCase().indexOf(key.toLowerCase()) > -1) bolAll = true;
        });
        return bolAll;
      }
 
      selectionPills(allData,icon,selectedOnes,isLink){
        let items= [];
        selectedOnes.forEach(cont =>{
            items.push({type: 'icon',
                        label: (allData.find(e => e.value === cont))?.label,
                        name: cont,
                        iconName: icon,
                        alternativeText: 'contact',
                        isLink: isLink,
                        href: isLink?'/'+cont:''
                    });
        });
        return items;
      }
 
      handleItemRemove(e){
        const index = e.detail.index;
        let valueCopy = [...this.value];
        valueCopy.splice(index,1);
        this.value = [...valueCopy];
        this.dispatchSearchChange(e, false);
      }
 
      dispatchSearchChange(event, isSearchChange){
              event.preventDefault();
              event.stopPropagation();
              const selectedEvent = new CustomEvent('change', { detail: {searchKey: this.searchKey, selectedValues: this.value, selectedLabel: this.selectedLabel, isSearchChange: isSearchChange} } );
              this.dispatchEvent(selectedEvent);
      }
}