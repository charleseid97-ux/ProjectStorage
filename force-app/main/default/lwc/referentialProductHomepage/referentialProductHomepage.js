/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 30-04-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
import { LightningElement, api, track, wire } from 'lwc';
import getProductHierarchy from '@salesforce/apex/productHierarchyController.getProductHierarchy';
import getAllProductHierarchy from '@salesforce/apex/ReferentialProductHomepageCtrl.getAllProducts';
import getPickListValues from '@salesforce/apex/PicklistController.getPickListValuesCustomContries';
import logClick from '@salesforce/apex/ReferentialProductHomepageCtrl.logClick';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation';
import ReportHomeProductCatalog from '@salesforce/label/c.ReportHomeProductCatalog';
import DataDicURL from '@salesforce/label/c.DataDicURL';
import NAVCalendar from '@salesforce/label/c.NAVCalendar';

import STRATEGY from '@salesforce/schema/Strategy__c';
import ASSETCLASSFIELD from '@salesforce/schema/Strategy__c.AssetClass__c';
import COUNTRY from '@salesforce/schema/Country__c';
import COUNTRYFIELD from '@salesforce/schema/Country__c.Country__c';
import FUND from '@salesforce/schema/Product__c';
import LEGALFORMFIELD from '@salesforce/schema/Product__c.LegalForm__c';
import FUNDTYPE from '@salesforce/schema/Product__c.VehicleType__c';
import SFDR from '@salesforce/schema/Product__c.SFDRcategory__c';
import SHARECLASS from '@salesforce/schema/Share_Class__c';
import CURRENCY from '@salesforce/schema/Share_Class__c.Currency__c';
import SHARECLASSTYPE from '@salesforce/schema/Share_Class__c.Type__c';
import DIVIDENDPOLICY from '@salesforce/schema/Share_Class__c.DividendPolicy__c';


export default class ReferentialProductHomepage extends NavigationMixin(LightningElement) 
{
    fieldName = 'Country__c';
    objectName = 'Share_Class__c';
    
    @track countries;
    @track noResults = false;
    @track reportId = ReportHomeProductCatalog;
    @track dataDicURL = DataDicURL;
    @track navCalendar = NAVCalendar;
    assetClassOptions = [];
    legalFormOptions = [];
    fundTypeOptions = [];
    currencyOptions = [];
    sfdrOptions = [];
    shareClassTypeOptions = [];
    dividendpolicyOptions = [];

    @track items = [];

    @api recordId;

    selectedCountry = 'All countries';
    selectedAssetClass = '';
    selectedLegalForm = '';
    selectedFundType = '';
    selectedCurrency = '';
    selectedSFDR = '';
    selectedSCType = '';
    selectedDividendP = '';
    searchKey = '';
    isActiveProducts = true;
    isRI = false;

    // value of show SRI checkbox
    showSRI = false;
    // value of show regional focus checkbox
    showRF = false;
    // value of show asset class checkbox
    showAC = false;
    // whether the product is a regional focus or an asset class
    ishighlevel = false;

    // --- Debounce & request guard ---
    debounceTimer;
    static DEBOUNCE_MS = 300; // ajuste à 250–500ms selon ton besoin
    requestCounter = 0;       // incrémenté à chaque requête
    lastAppliedCounter = 0;   // dernière réponse acceptée

    @wire(getObjectInfo, { objectApiName: COUNTRY }) countryObjectInfo;
    @wire(getObjectInfo, { objectApiName: STRATEGY }) strategyObjectInfo;
    @wire(getObjectInfo, { objectApiName: FUND }) fundObjectInfo;
    @wire(getObjectInfo, { objectApiName: SHARECLASS }) shareclassObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$countryObjectInfo.data.defaultRecordTypeId',
        fieldApiName: COUNTRYFIELD
    })
    setCountryValues({ data, error }) {
        if (data) {
            this.countries = data.values;
            
        } else if (error) {
            console.error('Erreur récupération des valeurs de Country:', error);
        }
    }

    // Récupère les valeurs du champ picklist
    @wire(getPicklistValues, {
        recordTypeId: '$strategyObjectInfo.data.defaultRecordTypeId',
        fieldApiName: ASSETCLASSFIELD
    })
    setAssetClassValues({ data, error }) {
        if (data) {
            this.assetClassOptions = data.values;
            
        } else if (error) {
            console.error('Erreur récupération des valeurs de Asset Class:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$fundObjectInfo.data.defaultRecordTypeId',
        fieldApiName: LEGALFORMFIELD
    })
    setLegalFormValues({ data, error }) {
        if (data) {
            this.legalFormOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de Legal Form:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$fundObjectInfo.data.defaultRecordTypeId',
        fieldApiName: FUNDTYPE
    })
    setFundTypeValues({ data, error }) {
        if (data) {
            this.fundTypeOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de Vehicule Type:', error);
        }
    }
    

    @wire(getPicklistValues, {
        recordTypeId: '$fundObjectInfo.data.defaultRecordTypeId',
        fieldApiName: SFDR
    })
    setSFDRValues({ data, error }) {
        if (data) {
            this.sfdrOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de SFDR Category:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$shareclassObjectInfo.data.defaultRecordTypeId',
        fieldApiName: CURRENCY
    })
    setCurrencyValues({ data, error }) {
        if (data) {
            this.currencyOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de Currency:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$shareclassObjectInfo.data.defaultRecordTypeId',
        fieldApiName: SHARECLASSTYPE
    })
    setSCTypeValues({ data, error }) {
        if (data) {
            this.shareClassTypeOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de Share Class Type:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$shareclassObjectInfo.data.defaultRecordTypeId',
        fieldApiName: DIVIDENDPOLICY
    })
    setDividendPolicyValues({ data, error }) {
        if (data) {
            this.dividendpolicyOptions = data.values;
        } else if (error) {
            console.error('Erreur récupération des valeurs de Dividend Policy :', error);
        }
    }

    // whether to show the countries picklist or not
    get isStrategiesVersion()
    {
        if(this.recordId == null){return true;}
        else{return false;}
    }
    

    // refresh tasks list on components updates
    async connectedCallback() 
    {
        //const record = this.recordId;

        /*getPickListValues(
        {
            objApiName: this.objectName,
            fieldName: this.fieldName
        })
        .then(data => 
        {
            this.countries = data;
        })
        .catch(error => 
        {
            this.displayError(error);
        });*/

        this.refreshProductHierarchy();
         
    }

    refreshProductHierarchy() {
        // incrémente le compteur pour cette requête
        const currentReqId = ++this.requestCounter;
        
        getAllProductHierarchy({
        showSRI: this.showSRI,
        showRF: this.showRF,
        showAC: this.showAC,
        country: this.selectedCountry,
        assetClass: this.selectedAssetClass,
        SCType: this.selectedSCType,
        dividendPolicy : this.selectedDividendP,
        legalForm: this.selectedLegalForm,
        fundType: this.selectedFundType,
        selectedCurrency: this.selectedCurrency,
        searchKey: this.searchKey,
        isActiveProducts: this.isActiveProducts,
        sfdr: this.selectedSFDR
        })
        .then(result => {
            // si une requête plus récente existe, on ignore cette réponse
            if (currentReqId < this.requestCounter) return;

            this.lastAppliedCounter = currentReqId;

            if (result == null) {
                this.items = [];
                this.noResults = true;
                return;
            }

            console.log('result: '+ result);
            if(result == null)
            {
                this.items = [];
                this.noResults = true
                return;
            }
            this.items = [JSON.parse(result)];
            this.items = this.items.filter(item => item.items != null);
            
            this.noResults = false;
        })
            .catch(error => {
                 // idem: ignore les erreurs “tardives” si une req plus récente est partie
                if (currentReqId < this.requestCounter) return;
                this.noResults = true;
                console.error('Erreur getAllProductHierarchy:', error);
        });
        
    }

    handleSearch(e) {
        const value = e.target.value;
        console.log('handleSearchKey:', value);

        window.clearTimeout(this.debounceTimer);
        this.debounceTimer = window.setTimeout(() => {
            const trimmed = (value || '').trim();

            // Évite un appel si la valeur n'a pas changé
            if (trimmed === this.searchKey) return;

            this.searchKey = trimmed;
            this.refreshProductHierarchy();
            console.log('after:', value);
        }, this.constructor.DEBOUNCE_MS);
      }

    handleAssetClassChange(event) {
        this.selectedAssetClass = event.target.value;
        console.log('Asset Class selected:'+ this.selectedAssetClass);
        this.refreshProductHierarchy();
    }
    handleCSTypeChange(event) {
        this.selectedSCType = event.target.value;
        console.log('Shareclass Type selected:'+ this.selectedSCType);
        this.refreshProductHierarchy();
    }

    handleDividendPChange(event) {
        this.selectedDividendP = event.target.value;
        console.log('Dividend Policy selected:'+ this.selectedDividendP);
        this.refreshProductHierarchy();
    }

    handleLegalFormChange(event) {
        this.selectedLegalForm = event.target.value;
        console.log('Legal Form selected:'+ this.selectedLegalForm);
        this.refreshProductHierarchy();
    }

    handleFundTypeChange(event) {
        this.selectedFundType = event.target.value;
        console.log('Fund Type selected:'+ this.selectedFundType);
        this.refreshProductHierarchy();
    }

    handleCurrencyChange(event) {
        this.selectedCurrency = event.target.value;
        console.log('Currency selected:'+ this.selectedCurrency);
        this.refreshProductHierarchy();
    }

    handleSFDRChange(event) {
        this.selectedSFDR = event.target.value;
        console.log('selectedSFDR :'+ this.selectedSFDR);
        this.refreshProductHierarchy();
    }

    handleActiveProductsChange(event) {
        this.isActiveProducts = event.target.checked;
        console.log('isActiveProducts :'+ this.isActiveProducts);
        this.refreshProductHierarchy();
    }

    handleCountryChange(event)
    {
        this.selectedCountry = event.target.value;
        console.log('selected country : ' +this.selectedCountry);
        this.refreshProductHierarchy();
    }

    handleResetFilters() {
        this.selectedCountry = 'All countries';
        this.selectedAssetClass = '';
        this.selectedLegalForm = '';
        this.selectedFundType = '';
        this.selectedCurrency = '';
        this.selectedSFDR = '';
        this.selectedSCType = '';
        this.selectedDividendP = '';
        this.searchKey = '';
        this.isActiveProducts = true;
        this.isRI = false;
        
        // Réinitialiser les inputs dans le DOM (si nécessaire)
        const selects = this.template.querySelectorAll('select');
        selects.forEach(select => {
            const dataId = select.dataset.id;
            if(dataId === 'countrySelect') {
                select.value = 'All countries';
            }else{
                select.value = '';
            }
        });

        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            const dataId = input.dataset.id;
            if (input.type === 'checkbox' && dataId === 'isRI') {
                input.checked = false;
            }else if (input.type === 'checkbox' && dataId === 'isActiveProducts') {
                input.checked = true;
            } else if (input.name === 'searchAll') {
                input.value = '';
            }
        });
        
        this.refreshProductHierarchy();
    }
        
    handleExport() {
        // Exemple simplifié : à adapter selon ton besoin réel
        console.log('Export des données');
        // Implémente ici la logique réelle d’export
        //00Obd000000qZPtEAM Part
        //00Obd000000oK5BEAU dev
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/lightning/r/Report/' + this.reportId + '/view' 
            }
        }, false);
        console.log('Export des données Fin');
    }

    handleOpenDataDic() {
        // Loggue d’abord le clic
        logClick({ 
            buttonType: 'Data Dictionary'
        })
        .then(() => {
            // Ensuite, ouvre le lien
            window.open(this.dataDicURL, '_blank');
        })
        .catch(error => {
            console.error('Erreur lors du log:', error);
            // On ouvre quand même le lien même en cas d’erreur
            window.open(this.dataDicURL, '_blank');
        });
        
    }

    handleOpenNavCalendar() {
        window.open(this.navCalendar, '_blank');
    }

}