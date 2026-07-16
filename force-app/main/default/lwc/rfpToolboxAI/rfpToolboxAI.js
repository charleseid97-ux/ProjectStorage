import { LightningElement, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getSubCategories from '@salesforce/apex/RFP_Helper.getSubCategories';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FLOW_API_NAME = 'AL_RFP_Search';
const OBJECT_API = 'RFP_Library__c';
const FIELD1 = 'RFP_Library__c.Category__c';
const INPUT_VAR_1 = 'Category';
const INPUT_VAR_2 = 'SubCategory';
const INPUT_VAR_3 = 'UserQuery';
const OUTPUT_VAR = 'PromptResponse';

export default class RfpToolboxAI extends LightningElement {
    @track picklist1Options = [];
    @track picklist1Value = '';
    @track subCategoryOptions = [];
    @track subCategoryValue = '';
    @track textValue = '';
    @track htmlOutput = '';
    @track errorMessage = '';
    @track isRunning = false;

    showFlow = false;     // control visibility
    flowStarted = false;
    flowInputs = null;

    // disable button when running or no input
    get disableRun() {
        return !(this.textValue) || this.isRunning;
    }

    // === Load object info & category picklist ===
    @wire(getObjectInfo, { objectApiName: OBJECT_API }) objectInfo;

    get recordTypeId() {
        return this.objectInfo?.data?.defaultRecordTypeId;
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: FIELD1 })
    wiredCategoryPicklist({ data, error }) {
        if (data) {
            this.picklist1Options = data.values.map(v => ({ label: v.label, value: v.value }));
        } else if (error) {
            console.error('Error loading Category picklist', error);
        }
    }

    // === Category changed → load subcategories ===
    async handlePicklist1Change(e) {
        this.picklist1Value = e.detail.value;
        this.subCategoryValue = '';
        this.subCategoryOptions = [];

        if (!this.picklist1Value) return;

        try {
            const data = await getSubCategories({ category: this.picklist1Value });
            console.log('this.picklist1Value',this.picklist1Value);
            console.log('data',data);
            this.subCategoryOptions = data.map(d => ({ label: d.label, value: d.value }));
            console.log('subCategoryOptions',subCategoryOptions);

        } catch (error) {
            console.error('Error loading SubCategories', error);
            // this.showToast('Error', 'Could not load SubCategories', 'error');
        }
    }

    handleSubCategorySelect(e) {
        this.subCategoryValue = e.detail.value;
    }

    handleTextChange(e) {
        this.textValue = e.detail.value;
    }

    // === Run Flow ===
    runFlow() {
        this.errorMessage = '';
        this.htmlOutput = '';
        this.isRunning = true;

        console.log('Category (INPUT_VAR_1):', this.picklist1Value);
        console.log('SubCategory (INPUT_VAR_2):', this.subCategoryValue);
        console.log('UserQuery (INPUT_VAR_3):', this.textValue);

        this.flowInputs = [
            { name: INPUT_VAR_1, type: 'String', value: this.picklist1Value },
            { name: INPUT_VAR_2, type: 'String', value: this.subCategoryValue },
            { name: INPUT_VAR_3, type: 'String', value: this.textValue }
        ];

        // reset the flow element by toggling visibility
        this.showFlow = false;
        this.flowStarted = false;
        Promise.resolve().then(() => {
            this.showFlow = true; // triggers a new lightning-flow render
        });
    }

    renderedCallback() {
        if (this.showFlow && !this.flowStarted && this.flowInputs) {
            const flowCmp = this.template.querySelector('lightning-flow[data-id="flowHost"]');
            if (flowCmp) {
                this.flowStarted = true;
                try {
                    flowCmp.startFlow(FLOW_API_NAME, this.flowInputs);
                } catch (error) {
                    console.error('Error starting flow', error);
                    this.isRunning = false;
                    this.errorMessage = 'Could not start the Flow. Check API name and activation.';
                }
            }
        }
    }

    handleStatusChange(event) {
        const status = event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.isRunning = false;
            this.showFlow = false;

            const outputs = event.detail.outputVariables || [];
            const htmlVar = outputs.find(v => v.name === OUTPUT_VAR);
            if (htmlVar?.value) {
                this.htmlOutput = htmlVar.value;
            } else {
                this.errorMessage = `Flow finished but did not return "${OUTPUT_VAR}".`;
            }
        } else if (status === 'ERROR') {
            this.isRunning = false;
            this.showFlow = false;
            this.errorMessage = 'Flow encountered an error. Check Flow debug logs.';
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}