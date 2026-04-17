/*
    Created Date : 05/08/2022
    Description :  A Component to display a Lookup field similar to the standard but with the Field Filter Criteria
    Referenced In : lwc_preferencecenter
    APEX Controller : LookUpFilterCriteriaController
    IMPORTANT NOTES : 
        - This component dispatches an event - Lookup_InputField_Value_Change_Event to send the value of the Lookup input field to the parent. 
            - To retrieve the value, simply handle the event listener in the parent component's constructer and set the value in a variable to use it.
*/
import { LightningElement, api, track, wire } from 'lwc';
//Lightning Imports
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//Salesforce Apex Imports
import getFieldAndObjectPluralLabels from '@salesforce/apex/LookUpFilterCriteriaController.getFieldAndObjectPluralLabels';
import getLookUpFieldValues from '@salesforce/apex/LookUpFilterCriteriaController.getLookUpFieldValues';

const REGEX_SOSL_RESERVED = /(\?|&|\||!|\{|\}|\[|\]|\(|\)|\^|~|\*|:|"|\+|-|\\)/g;
const DELAY = 300; // dealy apex callout timing in miliseconds  

export default class Lwc_lookupfield_filtercriteria extends LightningElement {
    //START : Component Parameters ---------------------------------------------------
    //Takes the api of object in which the look up has been created
    @api referenced_object_api = '';
    //Takes the api of the lookup object 
    @api lookup_origin_object_api = '';
    //Takes the api of the LookUp field to query
    @api lookup_field_api = '';
    //The field value to display in the subheader of the search results container
    @api subheader_field = '';
    @api get empty_lookupfield() {}
    //Gets the dependent value from the parent component
    @api get dependent_value() {}
    //Takes the dependent field condition to add the soql query
    @api dependent_query = '';
    //The icon name to display in the search values section : same as the one in the Object's tab
    @api icon_name;
    //END : Component Parameters ---------------------------------------------------------

    //START : Component Variables' Attributes --------------------------------------------
    //Obtaining the contact Id from the Contact Record Page
    @api record_id;

    dependentValue;

    @track lookupInputValue = '';
    //Shows the selected search value section in the input field
    showSelectedOption = false;
    //Stores the record's name in the selection option 
    selectedOptionLabel = '';
    //END : Component Variables' Attributes --------------------------------------------

    //START : Server initialized Variables ---------------------------------------------------------
    lookupFieldLabel = '';
    objectPluralNamePlaceholder = '';
    lookupObjectPluralLabel = '';
    //Stores the returned values for the Lookup Search Values List
    @track serverReturnedValuesArray = [];
    //END : Server initialized Variables -----------------------------------------------------------

    //START : Lifecycle Methods........................................
    //When the component loads
    connectedCallback() {
        //Description : This method returns the field's label, the lookup object's plural label
        //Parameters : 
        // - referencedObjectAPI : Takes the api of object in which the look up has been created to know which object to query to get the field label
        // - fieldAPI : Take the api of the LookUp field to query to return the label
        // - lookUpOriginObjectAPI : Takes the api of the lookup object to get the plural label of the object
        getFieldAndObjectPluralLabels({ referencedObjectAPI: this.referenced_object_api, fieldAPI: this.lookup_field_api, lookUpOriginObjectAPI: this.lookup_origin_object_api })
            .then((result) => {
                for (let key in result) {
                    this.lookupFieldLabel = key;
                    this.objectPluralNamePlaceholder = 'Search ' + result[key] + '...';
                    this.lookupObjectPluralLabel = result[key];
                }
            })
            .catch((error) => {
                console.log('TEST : LUFCC : Error Message => ', error.body.message);
            });
    }
    //END : Lifecycle Methods.........................................

    //START : Methods communicating with APEX..................
    //Description : This method handles the actions to follow when Lookup field value changes
  /*  searchLookUpFieldValues(event) {
        //Displaying the dropdown section that contains the searched values
      //  this.template.querySelector('div[data-id="lookup_input_container"]').classList.add("slds-is-open");
        getLookUpFieldValues({ lookupObjectAPI: this.lookup_origin_object_api, lookupSearchKey: event.target.value, additionalField : this.subheader_field, dependentFieldQuery: this.dependent_query, dependentFieldValue: this.dependentValue })
            .then(result => {
                if (result.length > 0) {
                    let searchValuesArr = [];

                    result.forEach(eachObject => {
                        searchValuesArr.push({
                            Id: eachObject.Id,
                            LookUpName: eachObject.Name,
                            LookUpSubHeaderField : eachObject[this.subheader_field],
                            displayFieldAsSubHeader : this.subheader_field != "" ? true : false
                        });
                    });

                    this.serverReturnedValuesArray = searchValuesArr;
                }
            })
            .catch(error => {
                console.log('TEST : LUFCC : Error Message => ', error.body.message);
            });
    }*/
    //END : Methods communicating with APEX..................
    finalSearchKey = '';
    isSearchLoading = false;

    searchLookUpFieldValues(event) {
        this.isSearchLoading = true;
        window.clearTimeout(this.delayTimeout);
        const newCleanSearchTerm = event.target.value.trim().replace(REGEX_SOSL_RESERVED, '?');
        this.delayTimeout = setTimeout(() => {
            this.finalSearchKey = newCleanSearchTerm.replace(/\?/g, '');
        }, DELAY);
    }

    @wire(getLookUpFieldValues, { lookupObjectAPI: '$lookup_origin_object_api', lookupSearchKey: '$finalSearchKey', additionalField: '$subheader_field', dependentFieldQuery: '$dependent_query', dependentFieldValue: '$dependentValue', contactIdParam: '$record_id' })
    wiredgetLookUpFieldValues(value) {
        const { data, error } = value; 
        this.isSearchLoading = false;
        if (data) {
            //Check to avoid LWC wired method value provisioning error
           // if (data.length > 0) {
                this.serverReturnedValuesArray = JSON.parse(JSON.stringify(data));
          //  }
        } else if (error) {
            this.showNotification('Data Operation', JSON.stringify(error.body.message), 'error');
            //this.alertTypesInitialArr = undefined;
            console.log('TEST : wiredAlertTypes : error => ', JSON.stringify(error));
        }
    }
    
    //Description : Actions to perform when an option is selected in the searched values
    setLookupInputValue(event) {
        //Displays the selected option section
        this.showSelectedOption = true;
        //Displays the record's name in the selection option 
        this.selectedOptionLabel = event.currentTarget.dataset.name;
        //Adding the focus on the Lookup input field
        this.template.querySelector('div[data-id="lookup_input_container"]').firstChild.focus();
        //Hiding the searched values container
        this.template.querySelector('div[data-id="lookup_input_container"]').classList.remove("slds-is-open");
        //Dispatching an event to communicate with the Parent Component
        //Sending the Lookup input value to the parent component
        const lookupValueShareEvnt = new CustomEvent('Lookup_InputField_Value_Change_Event', { detail: event.currentTarget.dataset.id, bubbles: true });
        this.dispatchEvent(lookupValueShareEvnt);
    }

    //Description : Actions to perform when the selected value is removed from the Lookup input
    removeSelectedOption() {
        //Displays back the input field
        this.showSelectedOption = false;
        //Resetting the Lookup input field's value to null
        this.lookupInputValue = '';
    }

    //START : Setters
    //Description : Empties the Lookup Field's value
    set empty_lookupfield(value) {
        if (value) {
            this.removeSelectedOption();
        }
    }

    set dependent_value(value) {
        this.dependentValue = value;
    }
    //END : Setters

    //START : Utility Methods ------------------------
    //Description : Displays a notification/toast
    showNotification(toastTitle, toastMessage, toastVariant) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMessage,
            variant: toastVariant, //Possible Values : info (default), success, warning, and error.
        });
        this.dispatchEvent(event);
    }
    //END : Utility Methods ------------------------

    toggleResult(event){
        this.template.querySelector('div[data-id="lookup_input_container"]').classList.add("slds-is-open");
    }
}