/**
 * @description       :
 * @author            : SILA Nicolas
 * @group             :
 *
 * @last modified on  : 29-04-2025
 * @last modified by  : Khadija EL GDAOUNI
 **/
import { LightningElement, wire, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadStyle } from "lightning/platformResourceLoader";
import { createRecord } from "lightning/uiRecordApi";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import fileSelectorStyle from "@salesforce/resourceUrl/FileUploadLargeDropZone";
import getShareClassesByFunds from "@salesforce/apex/CaseTranslationProcess.getShareClassesByFunds";
import getProducts from "@salesforce/apex/CaseTranslationProcess.getProducts";
import TARGET_LANGUAGES from "@salesforce/schema/Case.Target_languages__c";
import DESTINATION_DEP from "@salesforce/schema/Case.Destination_department__c";
import WEBSITE_SUBTYPE from "@salesforce/schema/Case.Website_SubType__c";
import FORM_FACTOR from "@salesforce/client/formFactor";
import getTargetWebsiteOptions from "@salesforce/apex/CaseTranslationProcess.getTargetWebsiteOptions";
import getWebsiteSubTypeAndPriority from "@salesforce/apex/CaseTranslationProcess.getWebsiteSubTypeAndPriority";
import getPriorityAndDueDateDelay from "@salesforce/apex/CaseTranslationProcess.getPriorityAndDueDateDelay";
import publicationURL from "@salesforce/label/c.Publication_Library_Link";
import monthlyURL from "@salesforce/label/c.Comment_process_planning";
import TooltipTargetLanguage from '@salesforce/label/c.ToolTip_Target_Language';
import MonthlyCommentsDeadline from '@salesforce/label/c.MonthlyCommentsDeadline';


/*import {
  FlowAttributeChangeEvent,
  FlowNavigationNextEvent
} from "lightning/flowSupport";*/

export default class TranslationCaseCreation extends NavigationMixin(
  LightningElement
) {
  @track recordId;
  @api parentCase;
  recordTypeId;
  pubURL = publicationURL;
  tooltipTargetLang = TooltipTargetLanguage;
  monthlyCommentsDeadline = Number(MonthlyCommentsDeadline);
  montlyCommentsURL= monthlyURL;
  priority;
  csvData;
  showSpinner = false;
  acceptedFormats = ".pdf, .docx, .xlsx, .csv"; // Add any file formats you expect for attachments
  isMonthlyComm = false;
  isDeeplPro = false;
  isPressRelease = false;
  dueDateDefaultValue;
  FinalDueDateDefaultValue;
  defaultTranslationDueDateValue;
  isTranslationAgency = false;
  isArticle = false;
  isNewsletter = false;
  showErrorLang = false;
  isFundPromotion = false;
  @track sourceLanguageValue = "";
  @track funds = [];
  @track selectedFunds = [];
  @track mapProducts = {};
  @track shareClasses = [];
  @track selectedShareCls = [];
  @track mapShareCls = {};
  @track targetWebsiteOptions = [];
  @track selectedWebsites = [];
  @track selectedLanguages = [];
  @track selectedLanguagesTrans = [];
  @track mdtWebsiteSubPrio = [];
  @track mdtPrioDueDate = [];
  targetResult;
  isFindalSpecificDisclaimer = true;
  disabled = true;
  required = true;
  PickWebsiteDisabled = true;
  picklistFundDisabled = true;
  priority = "";
  defaultStatus = "";
  docType = "";
  reqType = "";
  WebSiteType = "";
  WebSiteSubType = "";
  isTransOnly = false;
  isPubOnly = false;
  isPubAndTrans = false;
  isPubOrPubTrans = false;
  monthlyCommentDate;
  targetLang;
  destinationDep;
  pickListTargetLang = [];
  pickListDestinationDep;
  websiteSubTypeLabels;
  minDate;
  businessDays = 0;

  connectedCallback() {
    this.minDate = this.formatDateTime(new Date());
    Promise.all([loadStyle(this, fileSelectorStyle)]);

  }

  @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
  handleObjectInfo({ error, data }) {
    if (data) {
      const rtis = data.recordTypeInfos;
      // 012Aa000002YAevIAG
      this.recordTypeId = Object.keys(rtis).find(
        (rti) => rtis[rti].name === "Translation Request"
      );
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: TARGET_LANGUAGES
  })
  picklistTargetResults({ error, data }) {
    this.targetResult = data;

    if (data) {
      let tmpArray = [];
      data.values.forEach((element) => {
        tmpArray.push(element.value);
        this.pickListTargetLang.push({
          label: element.value,
          value: element.value
        });
      });

      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.pickListTargetLang = undefined;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: WEBSITE_SUBTYPE
  })
  picklistWebsiteSubType({ error, data }) {
    if (data) {
      this.websiteSubTypeLabels = data.values;
    } else if (error) {
      this.websiteSubTypeLabels = undefined;
    }
  }
  getLabel(apiName) {
    if (this.websiteSubTypeLabels) {
      const option = this.websiteSubTypeLabels.find(
        (opt) => opt.value === apiName
      );
      return option ? option.label : "";
    }
    return "";
  }

  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: DESTINATION_DEP
  })
  picklistDestinationResults({ error, data }) {
    if (data) {
      let tmpArray = [];
      data.values.forEach((element) => {
        tmpArray.push(element.value);
      });

      this.pickListDestinationDep = tmpArray.join(";");
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.pickListDestinationDep = undefined;
    }
  }

  @wire(getTargetWebsiteOptions, { target_languages: "$selectedLanguages" })
  getTargetWebsiteOpt({ error, data }) {
    if (data) {
      let websites = [];
      data.forEach((item) => {
        websites.push({ label: item, value: item });
      });
      let tmpSelectedWS = [];
      websites.forEach((website) => {
        var found = false;
        for (let i = 0; i < this.targetWebsiteOptions.length; i++) {
          if (this.targetWebsiteOptions[i].value == website.value) {
            found = true;
            break;
          }
        }
        if (!found) {
          this.selectedWebsites.push(website.value);
        }
      });
      this.targetWebsiteOptions = [...websites];
      //To update selected website when a target language item is removed
      tmpSelectedWS = [];
      this.targetWebsiteOptions.forEach((element) => {
        if (this.selectedWebsites.includes(element.value)) {
          tmpSelectedWS.push(element.value);
        }
      });
      this.selectedWebsites = [...tmpSelectedWS];
      if (this.targetWebsiteOptions.length > 0) {
        this.PickWebsiteDisabled = false;
      } else {
        this.PickWebsiteDisabled = true;
      }
      if (this.targetWebsiteOptions.length > 0) {
        this.template
          .querySelector("c-multi-select-search-list[data-id=TargetWebsiteId]")
          .refreshOptions(this.targetWebsiteOptions);
      }
    } else if (error) {
      console.log("Error : ", error);
    }
  }

  @wire(getWebsiteSubTypeAndPriority)
  WebsiteSubTypeAndPriority({ error, data }) {
    if (data) {
      this.mdtWebsiteSubPrio = data;
    } else if (error) {
      console.log("Error : ", error);
    }
  }

  @wire(getPriorityAndDueDateDelay)
  PriorityAndDueDateDelay({ error, data }) {
    if (data) {
      this.mdtPrioDueDate = data;
    } else if (error) {
      console.log("Error : ", error);
    }
  }

  handleSourceLanguage(e) {
    this.sourceLanguageValue = e.target.value;
  }

  handleSourceLanguagePubAndTrans(e) {
    this.sourceLanguageValue = e.target.value;
    console.log('source lang : '+this.sourceLanguageValue);
    if(this.sourceLanguageValue!=null && this.sourceLanguageValue!=''){
      var found = false;
      for(let i = 0; i < this.selectedLanguages.length; i++){
        if (this.selectedLanguages[i] == this.sourceLanguageValue) {
          found = true;
          break;
        }
      }
      if (!found) {
        let tmpSelectedLang = [...this.selectedLanguages];
        tmpSelectedLang.push(this.sourceLanguageValue);
        this.selectedLanguages = [...tmpSelectedLang];
      }
    }
   
  }
 
  handleFundPromotion(e) {
    this.isFundPromotion = e.target.checked;
    this.picklistFundDisabled = !this.isFundPromotion;
    this.getAllProducts();
  }
  handleFinalDisclaimer(e) {
    this.isFindalSpecificDisclaimer = !e.target.checked;
  }

  handleWebsiteSelection(e) {
    this.selectedWebsites = [...e.detail.selectedValues];
  }

  handleProducts(e) {
    this.selectedFunds = [...e.detail.selectedValues];
    this.getSpecificShareCls(this.selectedFunds);
  }

  handleProducts2(e) {
    this.selectedFunds = [...e.detail.selectedValues];
    this.getSpecificShareCls2(this.selectedFunds);
  }

  handleShareCls(e) {
    this.selectedShareCls = [...e.detail.selectedValues];
  }

  handleTransRequestType(event) {
    if (this.reqType != event.target.value) {
      this.selectedLanguagesTrans = [];
      this.selectedLanguages = [];
      this.selectedShareCls = [];
      this.selectedWebsites = [];
      this.selectedFunds = [];
      this.docType = '';
      this.isMonthlyComm = false;
    }
    this.reqType = event.target.value;
    if (event.target.value == "Translation Only") {
      this.isTransOnly = true;
      this.isPubOnly = false;
      this.isPubAndTrans = false;
      this.isPubOrPubTrans = false;
      this.defaultStatus = "Work in progress";
    }
    if (event.target.value == "Publication Only") {
      this.isPubOnly = true;
      this.isTransOnly = false;
      this.isPubAndTrans = false;
      this.isPubOrPubTrans = true;
      this.defaultStatus = "Publication in Progress";
    }
    if (event.target.value == "Publication and Translation") {
      this.isPubAndTrans = true;
      this.isPubOnly = false;
      this.isTransOnly = false;
      this.isPubOrPubTrans = true;
      this.defaultStatus = "Work in progress";
    }
  }

  handleMonthlyCommentDateChange(event) {
    this.monthlyCommentDate = event.target.value;
  }
  handleDocTypeChange(event) {
    if (this.docTyp != event.target.value) {
      this.selectedLanguagesTrans = [];
      this.selectedLanguages = [];
    }
    this.docType = event.target.value;

    if (
      this.docType === "Press Release" &&
      (this.isTransOnly || this.isPubAndTrans)
    ) {
      this.isPressRelease = true;
      this.isMonthlyComm = false;
    } else if (this.docType === "Monthly comments" || this.docType === "IS Monthly Comments") {
      this.isPressRelease = false;
      this.isMonthlyComm = true;

      this.dueDateDefaultValue = this.calculateDateTimePlusDays(this.monthlyCommentsDeadline);
      //this.defaultTranslationDueDateValue = this.calculateTranslationDueDate(this.dueDateDefaultValue);

      // this.addPortugueseIfNotExist('Portuguese');
      this.targetLang = this.pickListTargetLang;

      let tmpSelectedTLang = [];
      if(this.docType === "Monthly comments"){
        this.pickListTargetLang.forEach((element) => {
          tmpSelectedTLang.push(element.value);
        });
      }
      else {
        const languages = [ 'English', 'French', 'Italian'];
        this.pickListTargetLang.forEach((element) => {
          if(languages.includes(element.value)){
            tmpSelectedTLang.push(element.value);
          }
        });
      }

      if (this.isTransOnly) {
        this.selectedLanguagesTrans = [...tmpSelectedTLang];
        this.selectedLanguages = [];
      } else {
        this.selectedLanguages = [...tmpSelectedTLang];
        this.selectedLanguagesTrans = [];
 
      }
 
    } else {
      this.isMonthlyComm = false;
      this.isPressRelease = false;
    }
  }
 
  handleWebSiteTypeChange(event) {
    this.WebSiteType = event.target.value;
    if (this.WebSiteType === "Article") {
      this.isArticle = true;
      this.isNewsletter = false;
    } else if (this.WebSiteType === "Newsletter") {
      this.isNewsletter = true;
      this.isArticle = false;
    } else if (this.WebSiteType === "Corporate") {
      this.isNewsletter = false;
      this.isArticle = false;
    } else {
      this.isNewsletter = false;
      this.isArticle = false;
    }
  }
 
  handleSubTypeChange(event) {
    this.WebSiteSubType = event.target.value;
    this.priority = "";
    for (let i = 0; i < this.mdtWebsiteSubPrio.length; i++) {
      if (this.mdtWebsiteSubPrio[i].Website_SubType__c == this.WebSiteSubType) {
        this.priority = this.mdtWebsiteSubPrio[i].Priority__c;
        break;
      }
    }
  }
 
  handlePriority(event) {
    
    if(this.isPubAndTrans){
      this.FinalDueDateDefaultValue=null;
      console.log("here 4",this.dueDateDefaultValue);
      for (let i = 0; i < this.mdtPrioDueDate.length; i++) {
        if (this.mdtPrioDueDate[i].Priority__c === event.target.value) {
          console.log('mdtPrioDueDate[i].Priority__c',this.mdtPrioDueDate[i].Priority__c);
          this.priority = this.mdtPrioDueDate[i].Priority__c;
          
          this.FinalDueDateDefaultValue = this.calculateTranslationDueDate(this.dueDateDefaultValue,
            this.mdtPrioDueDate[i].DueDate__c
          );
          this.minDate = this.FinalDueDateDefaultValue;
          break;
        }
      }
    }
    if(this.isPubOnly){
      this.dueDateDefaultValue = null;
      for (let i = 0; i < this.mdtPrioDueDate.length; i++) {
        if (this.mdtPrioDueDate[i].Priority__c == event.target.value) {
          this.priority = this.mdtPrioDueDate[i].Priority__c;
          this.dueDateDefaultValue = this.calculateDateTimePlusDays(
            this.mdtPrioDueDate[i].DueDate__c
          );
          this.minDate = this.dueDateDefaultValue;
          break;
        }
      }
    }
    
    //this.defaultTranslationDueDateValue = this.calculateTranslationDueDate(this.dueDateDefaultValue);

  }

  calculateBusinessDaysAndHours(startDate, endDate) { 
    let businessDays = 0; 
    // Créer des copies des dates pour ne pas modifier les originales 
    const start = new Date(startDate); 
    const end = new Date(endDate); 
    // Calculer les jours ouvrables 
    const currentDate = new Date(start); 
    while (currentDate < end) { 
      // Exclure les samedis (6) et dimanches (0) 
      const dayOfWeek = currentDate.getDay(); 
      if (dayOfWeek !== 0 && dayOfWeek !== 6) { 
        businessDays++; 
      } currentDate.setDate(currentDate.getDate() + 1); 
    } // Calculer la différence totale en heures 
    const totalHoursDiff = Math.abs(Math.round((end - start) / (1000 * 60 * 60))); 
    return { days: businessDays, hours: totalHoursDiff }; }

  calculateBusinessDays (startDate, endDate)  { 
    console.log(startDate)
    console.log(endDate)
    let days = 0; 
    const currentDate = new Date(startDate); 
    while (currentDate < endDate) { 
      console.log("inferier")
      // Exclure les samedis (6) et dimanches (0) 
      if (currentDate.getDay() !== 0 && currentDate.getDay() !== 6) {
        console.log("not weekend")
         days++; 
         console.log("nbr days "+days)
      } 
      currentDate.setDate(currentDate.getDate() + 1);
      console.log("next day"+currentDate) 
    } 
    return days; 
  }; 

  handleTransOrPubDueDate(event) { 
    const dueDateFinal = new Date(this.FinalDueDateDefaultValue); 
    const dueDateDefaut = new Date(this.dueDateDefaultValue); 
    const currentDueDate = new Date(event.target.value); 
    
    var errorMsg = '';
    var changeDate = false;
    var result ;
    if(event.target.dataset.id === 'translationDueDate'){ 
      this.dueDateDefaultValue = event.target.value;
      this.businessDays = this.calculateBusinessDays(currentDueDate, dueDateFinal); 
      result = this.calculateBusinessDaysAndHours(currentDueDate, dueDateFinal); 
      console.log('result hours :'+result.hours); 
      changeDate = true;
      
    } else { 
      this.FinalDueDateDefaultValue = event.target.value;
      this.businessDays = this.calculateBusinessDays(dueDateDefaut, currentDueDate); 
      result = this.calculateBusinessDaysAndHours(dueDateDefaut, currentDueDate); 
      console.log('result hours :'+result.hours); 
      errorMsg = "\n Please adjust the the publication date."
       
    } 
    //add cette partie qui met a jour la date
    console.log('this.priority',this.priority);
    for (let i = 0; i < this.mdtPrioDueDate.length; i++) {
        if (this.mdtPrioDueDate[i].Priority__c === this.priority) {
          let tmpMinDate = this.calculateTranslationDueDate(this.dueDateDefaultValue,
            this.mdtPrioDueDate[i].DueDate__c
          );
          
          console.log('this.FinalDueDateDefaultValue',this.FinalDueDateDefaultValue);

          if(result.hours < this.mdtPrioDueDate[i].DueDate__c*24){
            this.showToast(
              "Error",
              "The due dates you entered are not compatible with the required processing times.\n Publication must start only after translation is complete, with a minimum of "+this.mdtPrioDueDate[i].DueDate__c+" days for preparation. "+errorMsg,
              "error",
              "dismissable"
            );
            const dateField = this.template.querySelector('[data-id="finalDueDate"]');
            if(changeDate){
              this.FinalDueDateDefaultValue = tmpMinDate;
            }
            
            console.log('this.FinalDueDateDefaultValue',this.FinalDueDateDefaultValue);
            
          }
          break;
        }
      }
    
  }

  formatDateTime(date) {
    console.log("format debut ");
    var tmpDate = new Date(date);
    const year = tmpDate.getFullYear();
    const month = String(tmpDate.getMonth() + 1).padStart(2, '0');
    const day = String(tmpDate.getDate()).padStart(2, '0');
    const hours = String(tmpDate.getHours()).padStart(2, '0');
    const minutes = String(tmpDate.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
}
 
  handleTargetLangChange(event) {
    this.selectedLanguages = [...event.detail.selectedValues];
  }
 
  handleTargetLangTransChange(event) {
    this.selectedLanguagesTrans = [...event.detail.selectedValues];
  }
 
  removeFromPicklist(valueToRemove) {
    // Create a new array without the element to remove
    this.pickListTargetLang = this.pickListTargetLang.filter(item => item.value !== valueToRemove);
  }
  // addPortugueseIfNotExist(value) {
  //     const portugueseOption = {
  //         label: value,
  //         value: value
  //     };
 
  //     // Check if Portuguese already exists in the array
  //     const portugueseExists = this.pickListTargetLang.some(lang => lang.value === value);
 
  //     if (!portugueseExists) {
  //         // Add Portuguese to the array
  //         this.pickListTargetLang = [...this.pickListTargetLang, portugueseOption];
  //     }
  // }
  // handlePortogueseExeption(){
  //   if (this.isDeeplPro) {
  //     this.addPortugueseIfNotExist('Portuguese');
  //   } else {
  //     this.removeFromPicklist('Portuguese');
  //   }
  // }
  handleTranslationModeChange(event) {
    if (this.isMonthlyComm) {
      this.isDeeplPro = true;
      this.isTranslationAgency = false;
      this.dueDateDefaultValue = this.calculateDateTimePlusDays(this.monthlyCommentsDeadline);
    } else if (event.target.value === "IA only") {
        this.isDeeplPro = true;
        this.isTranslationAgency = false;
        this.dueDateDefaultValue = this.calculateDateTimePlusDays(2);
    } else {
      this.isDeeplPro = false;
      this.isTranslationAgency = true;
      this.dueDateDefaultValue = this.calculateDateTimePlusDays(3);
      
    }
    // this.handlePortogueseExeption();
    //this.defaultTranslationDueDateValue = this.calculateTranslationDueDate(this.dueDateDefaultValue);
    
    
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
 
  getSpecificShareCls(Ids) {
    getShareClassesByFunds({ FundIds: Ids })
      .then((result) => {
        if (result.length > 0) {
          let shareCls = [];
          let mapShareCls = {};
          result.forEach((sc) => {
            shareCls.push({ label: sc.Name, value: sc.Id });
            mapShareCls[sc.Id] = sc;
          });
          this.shareClasses = [...shareCls];
          let tmpSelectedSC = [];
         
          this.shareClasses.forEach((element) => {
            if (this.selectedShareCls.includes(element.value)) {
              tmpSelectedSC.push(element.value);
            }
          });
 
          this.selectedShareCls = [...tmpSelectedSC];
          if (this.shareClasses.length > 0) {
            this.template
              .querySelector("c-multi-select-search-list[data-id=shareClassId]")
              .refreshOptions(this.shareClasses);
            this.mapShareCls = mapShareCls;
          }
 
          this.disabled = false;
        } else {
          this.disabled = true;
          this.selectedShareCls = [];
        }
      })
      .catch((error) => {
        console.log("Error : ", error);
      });
  }
 
  getSpecificShareCls2(Ids) {
    getShareClassesByFunds({ FundIds: Ids })
      .then((result) => {
        if (result.length > 0) {
          let shareCls = [];
          let mapShareCls = {};
          result.forEach((sc) => {
            shareCls.push({ label: sc.Name, value: sc.Id });
            mapShareCls[sc.Id] = sc;
          });
          this.shareClasses = [...shareCls];
          let tmpSelectedSC = [];
          this.shareClasses.forEach((element) => {
 
            if (this.selectedShareCls.includes(element.value)) {
              tmpSelectedSC.push(element.value);
            }
          });
          this.selectedShareCls = [...tmpSelectedSC];
          if (this.shareClasses.length > 0) {
              this.template
              .querySelector("c-multi-select-search-list[data-id=shareClassId2]")
              .refreshOptions(this.shareClasses);
            this.mapShareCls = mapShareCls;
          }
 
          this.disabled = false;
        } else {
          this.disabled = true;
          this.selectedShareCls = [];
        }
      })
      .catch((error) => {
        console.log("Error : ", error);
      });
  }
 
  get reqTitle() {
    if (this.docType === "Monthly comments") {
 
      let monthlyDate = new Date(this.monthlyCommentDate);
 
      if (!this.monthlyCommentDate) {
        monthlyDate = this.getLastBusinessDayOfLastMonth();
      }
 
 
      const year = monthlyDate?.getFullYear();
      const month = (monthlyDate?.getMonth() + 1).toString().padStart(2, "0");
      return year + " " + month + " " + this.docType;
    }
    let todayDate = new Date();
    const year = todayDate?.getFullYear();
    const month = (todayDate?.getMonth() + 1).toString().padStart(2, "0");
    const day = todayDate?.getDate();
    if (this.isTransOnly) {
      return year + " " + month + " " + this.docType;
    } else {
      return (
        year +
        month +
        day +
        " " +
        this.WebSiteType +
        " " +
        this.getLabel(this.WebSiteSubType)
      );
    }
  }
 


  calculateTranslationDueDate(dueDate,days) {
      if (!dueDate) {
          return null; // Handle cases where dueDate is not defined
      }
      console.log("here 1");
      const dueDateObj = new Date(dueDate);
    let addedDays = 0;
    console.log("here 2");
    while (addedDays < days) {
      dueDateObj.setDate(dueDateObj.getDate() + 1);
        if (dueDateObj.getDay() !== 0 && dueDateObj.getDay() !== 6) {
            addedDays++;
        }
    }
    console.log("here 3");
      
      //dueDateObj.setDate(dueDateObj.getDate() - 1); // Subtract 1 day

      const year = dueDateObj.getFullYear();
      const month = String(dueDateObj.getMonth() + 1).padStart(2, "0");
      const day = String(dueDateObj.getDate()).padStart(2, "0");
      const hours = String(dueDateObj.getHours()).padStart(2, "0");
      const minutes = String(dueDateObj.getMinutes()).padStart(2, "0");
      const seconds = String(dueDateObj.getSeconds()).padStart(2, "0");
      console.log('calculateTranslationDueDate',dueDate);
      console.log('test',`${year}-${month}-${day}T${hours}:${minutes}:${seconds}`);
      return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`;
    }

  get productIconSize() {
    if (FORM_FACTOR === "Small" || FORM_FACTOR === "Medium") return "small";
    return "medium";
  }
 
  getLastBusinessDayOfLastMonth() {
    let today = new Date();
    let firstDayOfCurrentMonth = new Date(
      today.getFullYear(),
      today.getMonth(),
      1
    );
    let lastDayOfLastMonth = new Date(today.getFullYear(), today.getMonth(), 0);
 
    let dayOfWeek = lastDayOfLastMonth.getDay(); // Get the day of the week: 0 (Sun) to 6 (Sat)
 
    // Adjust the date based on the day of the week
    if (dayOfWeek === 0) {
      // Sunday
      lastDayOfLastMonth.setDate(lastDayOfLastMonth.getDate() - 2); // Go to Friday
    } else if (dayOfWeek === 6) {
      // Saturday
      lastDayOfLastMonth.setDate(lastDayOfLastMonth.getDate() - 1); // Go to Friday
    }
    // No adjustment needed if it's a weekday (Monday to Friday)
 
    return lastDayOfLastMonth;
  }
 
  calculateDateTimePlusDays(days) {
 
    let now = new Date();
    let addedDays = 0;
 
    while (addedDays < days) {
      now.setDate(now.getDate() + 1);
        if (now.getDay() !== 0 && now.getDay() !== 6) {
            addedDays++;
        }
    }
 
    //let now = new Date();
    //now.setDate(now.getDate() + days); // Add 2 hours to the current time
    // Format to datetime-local input format YYYY-MM-DDTHH:MM
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");
    const hours = String(now.getHours()).padStart(2, "0");
    const minutes = String(now.getMinutes()).padStart(2, "0");
    const secondes = String(now.getSeconds()).padStart(2, "0");
 
    return `${year}-${month}-${day}T${hours}:${minutes}:${secondes}`;
  }
 
 
  handleUploadFinished(event) {
    // Get the list of uploaded files
    const uploadedFiles = event.detail.files;
 
  }
 
  getFieldValue(fieldId) {
    // Get the lightning-input-field using data-id

    const field = this.template.querySelector('[data-id="' + fieldId + '"]');
    
    if (field) {
        return field.value; // Returns the field value
    } 
}
  isInputValid() {
    let isValid = true;
    let isDateValid=true;
    const dueDate = this.getFieldValue('dueDate');
    const finalDueDate = this.getFieldValue('finalDueDate');
    const translationDueDate = this.getFieldValue('translationDueDate');
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
    if(this.isPubOnly && this.WebSiteSubType ==='Homepage update'){
      filesLength = 1;
      
    }
    
    console.log('this.dueDate',dueDate);
    console.log('this.finalDueDate',finalDueDate);
    console.log('translationDueDate',translationDueDate);
    console.log('this.defaultTranslationDueDateValue > this.dueDateDefaultValue',translationDueDate > dueDate);
    var result = this.calculateBusinessDaysAndHours(new Date(translationDueDate), new Date(finalDueDate));
    var requiredDays= 0;
    if(this.isPubAndTrans){
      for (let i = 0; i < this.mdtPrioDueDate.length; i++) {
        if (this.mdtPrioDueDate[i].Priority__c === this.priority) {
          
          console.log('requiredDays : ',this.mdtPrioDueDate[i].DueDate__c);
          if(result.hours < this.mdtPrioDueDate[i].DueDate__c*24){
            requiredDays = this.mdtPrioDueDate[i].DueDate__c;
            isDateValid = false;
            console.log('not valid');
          }
          break;
        }
      }
    }
    
    // add condition for target lang(for all), target website(isPubOrPubTrans ), fund(isFundPromotion) and file upload
    if (
      (this.selectedLanguages.length === 0 && this.isPubOrPubTrans) ||
      (this.selectedLanguagesTrans.length === 0 && this.isTransOnly) ||
      (this.selectedWebsites.length === 0 && this.isPubOrPubTrans) ||
      (this.selectedFunds.length === 0 && this.isFundPromotion) || !isDateValid ||
      filesLength === 0
    ) {
      isValid = false;
      console.log('isValid 2' +isValid);
    }
    if(!isValid){
      let msg = 'Please fill all the required fields' ;
      if(!isDateValid){
        msg = "Warning: The due dates you entered are incompatible with the required processing times.\n Publication must start only after translation is complete, with a minimum of "+requiredDays+" days for preparation." ;
        this.showToast(
          "Error",
          msg,
          "error",
          "dismissable"
        );
        return;
      }
      if(filesLength === 0){
        msg += ' and select a file' ;
      }
      msg += ' and then try again.' ;
      this.showToast(
        "Error",
        msg,
        "error",
        "dismissable"
      );
    }else{      
      this.handleSubmit(filesLength)
    }
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
 
  subtractOneHour(timeString) { 
    let dateSub = new Date (timeString);

    dateSub.setHours(dateSub.getHours() - 1);
    
    const year = dateSub.getFullYear();
    const month = String(dateSub.getMonth() + 1).padStart(2, "0");
    const day = String(dateSub.getDate()).padStart(2, "0");
    const hours = String(dateSub.getHours()).padStart(2, "0");
    const minutes = String(dateSub.getMinutes()).padStart(2, "0");
    const secondes = String(dateSub.getSeconds()).padStart(2, "0");
 
    return `${year}-${month}-${day}T${hours}:${minutes}:${secondes}`;
  }

  handleSubmit(filesLength) {
    this.showSpinner = true;
    // event.preventDefault(); // Prevent the default form submission
    const fields = {}; // Populate this with the actual field values from your form
 
    this.template.querySelectorAll("lightning-input-field").forEach((field) => {
      fields[field.fieldName] = field.value;
    });
 
    fields.RecordTypeId = this.recordTypeId;
    fields.Tech_NbrSourceFiles__c = filesLength;
    
    //fields.Translation_Due_Date__c = fields.Translation_Due_Date__c!=null? this.subtractOneHour(fields.Translation_Due_Date__c):null;
    //fields.DueDate__c = fields.DueDate__c!=null? this.subtractOneHour(fields.DueDate__c):null;
    // Loop through the fields and check if any of them is empty
  console.log('Translation_Due_Date__c submitted : '+fields.Translation_Due_Date__c);
  console.log('DueDate__c submitted : '+fields.DueDate__c);
    if (this.selectedWebsites.length > 0) {
      fields.TargetWebsite__c = this.selectedWebsites.join(";");
    }
    if (this.selectedLanguagesTrans.length > 0) {
      fields.Target_languages__c = this.selectedLanguagesTrans.join(";");
    }
   
    if (this.selectedFunds.length > 0) {
      let listOfFunds = "";
      this.selectedFunds.forEach((fund) => {
        listOfFunds += this.mapProducts[fund].Name + ";";
      });
      fields.Article_Funds__c = listOfFunds;
    }
    if (this.selectedShareCls.length > 0) {
      let listOfSC = "";
      this.selectedShareCls.forEach((shareClass) => {
        listOfSC += this.mapShareCls[shareClass].Name + ";";
      });
      fields.Article_ShareClass__c = listOfSC;
    }
    if (this.selectedLanguages.length > 0) {
      
      fields.Target_languages__c = this.selectedLanguages.join(";");
 
      if(!this.selectedLanguages.includes(this.sourceLanguageValue) && this.isPubAndTrans){
        // Afficher le message de confirmation
        if (confirm("You haven't selected a publication website for the source language [" + this.sourceLanguageValue + "]. As a result, no publication request will be created for this language.\nTo submit the request, click OK; otherwise, click Cancel.")) {
          // L'utilisateur a cliqué sur "Proceed"
          this.createCaseRecord(fields);
        } else {
            // L'utilisateur a cliqué sur "Cancel"
            this.showSpinner = false;
        }
      } else {
        // Si la langue source est incluse, soumettre directement
        this.createCaseRecord(fields);
      }
    }else {
      // Si aucune langue n'est sélectionnée, soumettre directement
      this.createCaseRecord(fields);
    }
    
  }
 
  createCaseRecord(fields){
    // Create the Case record
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
}