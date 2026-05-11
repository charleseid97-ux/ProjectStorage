import { LightningElement, wire, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadStyle } from "lightning/platformResourceLoader";
import { createRecord } from "lightning/uiRecordApi";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import getProducts from "@salesforce/apex/CaseTranslationProcess.getProducts";

export default class CaseESGCreation extends NavigationMixin(
  LightningElement
){
    @track recordId;
    recordTypeId;
    showSpinner = false;
    @track funds = [];
    @track selectedFunds = [];
    requestType = "";
    showFunds = false;


    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    handleObjectInfo({ error, data }) {
        if (data) {
        const rtis = data.recordTypeInfos;
        // 012Aa000002YAevIAG
        this.recordTypeId = Object.keys(rtis).find(
            (rti) => rtis[rti].name === "ESG"
        );
        }
    }

    getAllProducts() {
        getProducts()
        .then((result) => {
            if (result.length > 0) {
            let products = [];
            let mapProducts = {};
            result.forEach((product) => {
                products.push({
                label: product.Name + " | " + product.Product_Name__c,
                value: product.Id,
                code: product.Name
                });
                mapProducts[product.Id] = product;
            });
            this.funds = [...products];
            this.mapProducts = mapProducts;
            }
        })
        .catch((error) => {
            console.log("Error : ", error);
        });
    }

    handleProducts(e) {
        this.selectedFunds = [...e.detail.selectedValues];
    }

    handleRequestType(e) {
        this.requestType = e.target.value;
        this.showFunds = e.target.value === "Product ESG";
        this.getAllProducts();
    }

    handleUploadFinished(event) {
        // Get the list of uploaded files
        //const uploadedFiles = event.detail.files;
    
    }

    handleCancel() {
        window.location = '/lightning/o/Case/list?filterName=__Recent';
    }

    handleSubmit() {
        let isValid = true;
        let inputFields = this.template.querySelectorAll("lightning-input-field");
        inputFields.forEach((inputField) => {
    
        if (!inputField.reportValidity()) {
    
            isValid = false;
            console.log('isValid 1' +isValid);
        }
        });
        let filesLength = this.template
        .querySelector("c-file-upload-multi-l-w-c")
        .getExistingFileData();
        console.log('filesLength : '+filesLength);

        

        if(!isValid){
            let msg = 'Please fill all the required fields' ;
            
            msg += ' and then try again.' ;
            this.showToast(
                "Error",
                msg,
                "error",
                "dismissable"
            );
            return;
        }

        this.showSpinner = true;
        // event.preventDefault(); // Prevent the default form submission
        const fields = {}; // Populate this with the actual field values from your form
    
        this.template.querySelectorAll("lightning-input-field").forEach((field) => {
        fields[field.fieldName] = field.value;
        });
    
        fields.RecordTypeId = this.recordTypeId;
        if (this.selectedFunds.length > 0) {
            let listOfFunds = "";
            this.selectedFunds.forEach((fund) => {
                listOfFunds += this.mapProducts[fund].Name + ";";
            });
            fields.Funds__c = listOfFunds;
        }

        const recordInput = { apiName: CASE_OBJECT.objectApiName, fields };
        createRecord(recordInput)
        .then((caseRecord) => {
            this.recordId = caseRecord.id; // Set the record ID so the file upload component knows where to attach the files

            this.template
            .querySelector("c-file-upload-multi-l-w-c")
            .uploadFiles(this.recordId);
            this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                actionName: "view"
            }
            });
            this.showSpinner = false;
        })
        .catch((error) => {
            console.log(error);
            this.showSpinner = false;
            // Handle record creation error
        });
    }

    showToast(title, message, variant, mode) {
        const evt = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
        mode: mode
        });
        this.dispatchEvent(evt);
    }
}