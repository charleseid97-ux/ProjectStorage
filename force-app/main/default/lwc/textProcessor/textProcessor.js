import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getProducts from '@salesforce/apex/CTL_MeetingNotes.getProducts';
import getProducts from '@salesforce/apex/CTL_TextProcessor.getDemoProducts';
import correctErrors from '@salesforce/apex/CTL_TextProcessor.correctErrors';
import productOverview from '@salesforce/apex/CTL_TextProcessor.productOverview';
import getPositiveResponse from '@salesforce/apex/CTL_TextProcessor.getPositiveResponse';
import getNegativeResponse from '@salesforce/apex/CTL_TextProcessor.getNegativeResponse';
import getCrossCountryGlobalResponse from '@salesforce/apex/CTL_TextProcessor.getCrossCountryGlobalResponse';

export default class TextProcessor extends LightningElement {
    @track inputText = ''; // User's rich text input
    @track outputText = ''; // Corrected rich text from Apex
    @track outputValue = ''; // Corrected rich text from Apex
    @track processedData = {}; // Processed errors and details
    @track error = null; // Error message
    @track hasErrors = false;
    @track errorCount = 0;
    @track selectedUseCase = 'Writing Assistant';
    @track isWrittingAssistant = true;
    @track isProductOverview = false;
    @track isRAG = false;
    @track allProducts;
    @track selectedProduct ;
    @track isLoading = false;

    @api typoAssistant = false;
    @api productOverview = false;

    productOverviewResult='';
    selectedProductLabel = '';
    selectedPeriod ='';
    selectedCountry ='All';
    productSearchFields = ['code'];
    @track activeTab = 'writingAssistant'; // Default active tab

    useCaseOptions = [
        { label: 'Typo Assistant', value: 'writingAssistant' },
        { label: 'Product Overview', value: 'Product Overview' },
        { label: 'RAG', value: 'RAG' }
    ];

    periodOptions = [
        { label: 'One week', value: 'One week' },
        { label: 'One month', value: 'One month' },
        { label: 'Three months', value: 'Three months' },
        { label: 'YTD', value: 'YTD' },
        { label: 'One year', value: 'One year' },
        { label: 'Full', value: 'Full' },
    ];
    
    countryOptions = [
        { label: 'All', value:'All'},
        { label: 'Germany', value:'Germany'},
        { label: 'Belgium', value:'Belgium'},
        { label: 'France' , value:'France'},
        { label: 'Switzerland', value:'Switzerland'},
        { label: 'Spain', value:'Spain'},
        { label: 'United Kingdom', value:'United Kingdom'},
        { label: 'Italy', value:'Italy'},
        { label: 'Netherlands', value:'Netherlands'},
        { label: 'Luxembourg', value:'Luxembourg'},
        { label: 'Japan', value:'Japan'},
        { label: 'International', value:'International'}
    ];

        // Germany
        // Belgium
        // France
        // Switzerland
        // Spain
        // United Kingdom
        // Italy
        // Netherlands
        // LATAM
        // Nordics
        // Luxembourg
        // International
        // Japan

    @track positiveResponse;
    @track negativeResponse;
    @track globalResponse;

    connectedCallback() {
        // Automatically select the first available tab
        if (this.productOverview) {
            this.activeTab = 'productOverview';
        } else if (this.typoAssistant) {
            this.activeTab = 'typoAssistant';
        } else {
            this.activeTab = null; // No tabs available
        }
    }
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
    processProductOverview() {
        this.isLoading = true;
        this.error = null;
        this.positiveResponse = null;
        this.negativeResponse = null;
        this.globalResponse = null;

        console.log('Fetching Positive Response...');
        getPositiveResponse({ strategyId: this.selectedProduct, period: this.selectedPeriod, country : this.selectedCountry })
            .then((positiveResult) => {
                console.log('Positive Response: ', positiveResult);
                this.positiveResponse = positiveResult;

                console.log('Fetching Negative Response...');
                return getNegativeResponse({ strategyId: this.selectedProduct, period: this.selectedPeriod, country : this.selectedCountry });
            })
            .then((negativeResult) => {
                console.log('Negative Response: ', negativeResult);
                this.negativeResponse = negativeResult;

                console.log('Fetching Global Response...');
                return getCrossCountryGlobalResponse({ positiveResp: this.positiveResponse, negativeResp: this.negativeResponse });
            })
            .then((globalResult) => {
                console.log('Global Response: ', globalResult);
                this.productOverviewResult = globalResult;
            })
            .catch((error) => {
                console.error('Error:', error);
                this.error = error.body ? error.body.message : error.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handlePeriodChange(event) {
        this.selectedPeriod = event.target.value;
    }
    
    handleCountryChange(event) {
        this.selectedCountry = event.target.value;
    }

    handleProducts(e){
        //construct Pills part
        this.selectedProduct =e.detail.selectedValues;
        this.selectedProductLabel = e.detail.selectedLabel;
    }

    handleRemoveSelectedStrat(){
        this.selectedProduct = null;
        this.selectedProductLabel = '';
    
    }
    
    @wire (getProducts,{statFilter:''})
    products({data,error}){
        if(data && data.length){ 
            let products =[];
            let mapProducts = {};
            data.forEach(product =>{
                products.push({label:product.Name+" | "+product.Product_Name__c,value:product.Id,code:product.Name});
                mapProducts[product.Id] = product;
            });
            this.allProducts = [...products];
            this.mapProducts = mapProducts;
        }
        else if(error){
            console.log('@Error: Get Products',error);
        }
    }

    handleUseCaseChange(event) {
        this.selectedUseCase = event.target.value;
        if (this.selectedUseCase === 'RAG') {
            this.isWrittingAssistant = false;
            this.isProductOverview = false;
            this.isRAG = true;
        } else if (this.selectedUseCase === 'productOverview') {
            this.isWrittingAssistant = false;
            this.isProductOverview = true;
            this.isRAG = false;
        } else if (this.selectedUseCase === 'writingAssistant') {
            this.isWrittingAssistant = true;
            this.isProductOverview = false;
            this.isRAG = false;            
        }
    }
    // Handle rich text input changes
    handleInputChange(event) {
        console.log(event.target.value);
        console.log(event.target);
        console.log(event);
        this.inputText = event.target.value;
    }

    // Call Apex method to process the text
    processText() {
        this.isLoading = true;
        this.error = null; // Clear previous errors
        this.outputText = ''; // Clear previous output
        this.processedData = {}; // Clear previous results
        this.hasErrors = true;
        this.errorCount = 0;
        correctErrors({ inputText: this.inputText })
            .then((result) => {
                console.log('Apex Result: ', result);
                this.outputText = result.corrected_text_with_errors; // Update corrected text
                this.outputValue = result.corrected_text; // Update corrected text
                this.processedData = result; // Store processed data (errors, etc.)
                this.hasErrors = this.processedData.errors.length > 0;
                this.errorCount = this.processedData.errors.length;
                this.isLoading = false;
                this.resize();
                const topDiv = this.template.querySelector('[data-id="outputCorrected"]');
                topDiv.scrollIntoView({behavior: "smooth", block: "center", inline: "nearest"});
            })
            .catch((err) => {
                console.error('Error: ', err);
                this.isLoading = false;
                this.error = err.body ? err.body.message : err.message;
            });
            
    }

    copyToClipboard() {
        const outputElement = this.template.querySelector('[data-id="outputValue"]');
        if (!outputElement) {
            this.showToast('Error', 'Unable to find output text.', 'error');
            return;
        }
    
        const outputHTML = outputElement.value;
        if (!outputHTML) {
            this.showToast('Error', 'No output to copy.', 'error');
            return;
        }
    
        // Sanitize HTML to remove any background styles that Word may interpret
        const sanitizedHTML = outputHTML.replace(/background(-color)?:[^;"]+;?/gi, '');
    
        // Create a temporary element
        const tempDiv = document.createElement('div');
        tempDiv.style.position = 'absolute';
        tempDiv.style.left = '-9999px';
        tempDiv.style.backgroundColor = 'white'; // Force neutral background
        tempDiv.style.color = 'black';
        tempDiv.innerHTML = sanitizedHTML;
    
        document.body.appendChild(tempDiv);
    
        const range = document.createRange();
        range.selectNodeContents(tempDiv);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
    
        try {
            const successful = document.execCommand('copy');
            this.showToast(
                successful ? 'Success' : 'Error',
                successful ? 'Formatted text copied to clipboard!' : 'Failed to copy formatted text.',
                successful ? 'success' : 'error'
            );
        } catch (err) {
            console.error('Copy failed:', err);
            this.showToast('Error', 'Copy operation failed.', 'error');
        }
    
        document.body.removeChild(tempDiv);
        selection.removeAllRanges();
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
    resize() {
        document.documentElement.style.setProperty('--rtf-size', '100%');
    }
}