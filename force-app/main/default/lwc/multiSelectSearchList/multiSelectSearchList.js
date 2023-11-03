/* eslint-disable @lwc/lwc/no-api-reassignments */
/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 04-09-2023
 * @last modified by  : Thanina YAYA
**/
import { LightningElement, api, track } from 'lwc';

export default class MultiSelectSearchList extends LightningElement {
    
    @api width = 100;
    @api variant = '';
    @api monoSelect = false;
    @api myData;
    @api initDataTable;
    @api selectedVals=[];
    @api value = [];
    @api dropdownLength = 10;
    @api options=[];
    @api label;
    @api moreSearchingFields=[];

    @track optionsSaved = [];

    selectedLabel='';
    inDropdown = false;
    isOpen = false;
    searchKey;
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
      var style = ' slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
      return this.isOpen ? ' slds-is-open ' + style : style;
    }

    connectedCallback() {
      this.optionsSaved = JSON.parse(JSON.stringify(this.options));
    
    }
    openDropdown(){
      this.isOpen = true;
    }
    closeDropdown(){
      this.isOpen = false;
    }

    handleClick(event){

      if(this.isOpen === true) this.closeDropdown();
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

    /*handleClose = (event) => {
      event.stopPropagation();
      this.closeDropdown();
      window.removeEventListener('click', this.handleClose);
    }*/

    selectedLabelFind()
    {
        if(this.monoSelect){
              const index = this.options.findIndex(opt => opt.value === this.value);
              if(index > -1) this.selectedLabel = this.options[index].label;
        }
    }
    // Selection changed ...
    handleChange(event) {
            this.value = event.detail.value;
            if(this.monoSelect) this.selectedLabelFind(); //needed only in monoSelect Case;
            this.searchKey = '';
            this.options = JSON.parse(JSON.stringify(this.optionsSaved));
            this.dispatchSearchChange(event);
    }

    handleChangeSearch(event)
    {
      this.searchKey = event.target.value;
      if(this.isOpen === false) this.openDropdown();

          const rows = [...this.optionsSaved];
          if(this.searchKey !== undefined && this.searchKey.length > 0  )
          {
            let filteredData = rows.filter( word =>
              (!this.monoSelect && ( word.value === this.value.find(element => element === word.value )))
              || (this.monoSelect && ( word.value === this.value))
              || !this.searchKey ||
              ((word.label).toLowerCase().indexOf(this.searchKey.trim().toLowerCase()) > -1)
              //need to search on all fields
              || (this.moreSearchingFields.length > 0 && this.searchInOtherFields(word,this.searchKey.trim()))
            );
              this.options = filteredData;
          }
          else{
            this.options = JSON.parse(JSON.stringify(this.optionsSaved));
            }
            this.dispatchSearchChange(event);
      }

      searchInOtherFields(word,key)
      {
        let bolAll = false;
        this.moreSearchingFields.forEach(field => {
            if((word[field])?.toLowerCase().indexOf(key.toLowerCase()) > -1) bolAll = true;
        });
        return bolAll;
      }

      dispatchSearchChange(event){
              event.preventDefault();
              event.stopPropagation();
              const selectedEvent = new CustomEvent('change', { detail: {searchKey: this.searchKey,selectedValues: this.value,selectedLabel: this.selectedLabel} } );
              this.dispatchEvent(selectedEvent);
      }
}