/**
 * @description       :
 * @author            : Thanina YAYA
 * @last modified on  : 18-02-2025
 * @last modified by  : Khadija EL GDAOUNI
 **/
import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import saveProspaceAlerts from "@salesforce/apex/CTL_SearchSubscriptionProduct.saveProspaceAlerts";
import getAlertTypes from "@salesforce/apex/CTL_SearchSubscriptionProduct.getAlertTypes";
import getShareClassesByCountryWithSub from "@salesforce/apex/CTL_SearchSubscriptionProduct.getShareClassesByCountryWithSub";
import getDistinctValues from "@salesforce/apex/CTL_SearchSubscriptionProduct.getDistinctValues";
import getFundsWithSub from "@salesforce/apex/CTL_SearchSubscriptionProduct.getFundsWithSub";

import { getRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const CONTACT_FIELDS = [
  "Contact.WebsiteCountry__c",
  "Contact.TECH_WebSiteID__c"
];
export default class SearchSubscriptionProduct extends LightningElement {
  @api alertType = "";
  @api recordId;
  @api counter;
  @api fundOnly;
  @api isPerformance;

  selectedFrequency;
  frequenciesOptions = [
    { label: "Daily", value: "daily" },
    { label: "Weekly", value: "weekly" },
    { label: "Monthly", value: "monthly" }
  ];
  currencyPills = [];
  selectedTypes = [];
  selectedCurrencies = [];
  selectedDividendPolicy = [];
  checkboxHedged = false;
  activeOnly = false;
  optionsCurrencyIsoCode = [];
  //     {label: "EUR", value: "EUR" },
  //     {label: "GPD", value: "GPD" },
  //     {label: "USD", value: "USD" },
  //     {label: "CHF", value: "CHF" },
  //     {label: "JPY", value: "JPY" },
  //     {label: "CAD", value: "CAD" }
  optionsSharestypes = [];
  //     { label: "A", value: "A" },
  //     { label: "A2", value: "A2" },
  //     { label: "B", value: "B" },
  //     { label: "F", value: "F" },
  //     { label: "AW", value: "AW" },
  //     { label: "FW", value: "FW" },
  //     { label: "IW", value: "IW" },
  //     { label: "I", value: "I" },
  //     { label: "E", value: "E" },
  //     { label: "X", value: "X" }
  //   ];
  optionsDividendPolicy = [];
  // { label: "Distribution", value: "Distribution" },
  // { label: "Accumulation", value: "Accumulation" }

  defaultOpenStrat = [];
  defaultOpenFund = [];
  isLoading = true;
  isLoadingSearch = false;
  selectionDisabled = true;
  searchKey = "";
  countryCode = "";
  techContactId = "";
  refreshRequired = null;
  @track mapFundCodeName;
  @track initGroupedData = [];
  @track selectedProducts = {}; //to save only new selected products
  @track selectedAlerts = {};
  @track existingSubscriptions = {};
  @track newSubscriptions = [];
  @track results; //product tree Strat/Fund/shareClass
  @track mapAlertTypes = {};
  @track errors;
  @track wiredResult = [];
  @track resultsFunds = [];

  @api get showSpinner() {
    return this.isLoading;
  }

  get isNav() {
    let reg = new RegExp("Nav", "gi");
    return reg.test(this.alertType);
  }
  get isReport() {
    let reg = new RegExp("Report", "gi");
    return reg.test(this.alertType);
  }
  get isFund() {
    let reg = new RegExp("Fund", "gi");
    return reg.test(this.alertType);
  }
  get isHoldings() {
    let reg = new RegExp("Holdings", "gi");
    return reg.test(this.alertType);
  }
  connectedCallback() {
    this.getAllPickListValues();
  }

  clickAll() {
    // Find all Lightning toggle inputs
    const lightningToggles = this.template.querySelectorAll("lightning-input");

    // Toggle each Lightning toggle input
    lightningToggles.forEach((toggle) => {
      if (this.selectedFrequency === toggle.value) {
        // toggle.onchange();
        if (toggle.type === "toggle") {
          toggle.checked = true;
          toggle.dispatchEvent(new CustomEvent("change"));
        }
      }
    });
  }
  unclickAll() {
    // Find all Lightning toggle inputs
    const freList = ["daily", "weekly", "monthly"];
    const lightningToggles = this.template.querySelectorAll("lightning-input");
    // Toggle each Lightning toggle input
    lightningToggles.forEach((toggle) => {
      if (this.selectedFrequency === toggle.value) {
        if (toggle.type === "toggle" && freList.includes(toggle.value)) {
          toggle.checked = false;
          toggle.dispatchEvent(new CustomEvent("change"));
        }
      }
    });
  }

  getAllPickListValues() {
    getDistinctValues()
      .then((result) => {
        console.log(result);
        let optionsCurrencyIsoCode = new Set(result.optionsCurrencyIsoCode);
        let optionsDividendPolicy = new Set(result.optionsDividendPolicy);
        let optionsSharestypes = new Set(result.optionsSharestypes);
        optionsCurrencyIsoCode.forEach((element) => {
          this.optionsCurrencyIsoCode.push({ label: element, value: element });
        });
        optionsDividendPolicy.forEach((element) => {
          this.optionsDividendPolicy.push({ label: element, value: element });
        });
        optionsSharestypes.forEach((element) => {
          this.optionsSharestypes.push({ label: element, value: element });
        });
      })
      .catch((error) => {
        console.log(error);
      });
  }

  @wire(getAlertTypes, { cat: "$alertType" })
  alertsMeta({ data, error }) {
    if (data) {
      let mapal = {};
      data.forEach((alert) => {
        mapal[alert.LWCLabel__c.toLowerCase()] = {
          label: alert.MasterLabel,
          id: alert.DeveloperName,
          webId: alert.WebsiteId__c
        };
      });
      this.mapAlertTypes = mapal;
    } else if (error) {
      console.log(error);
    }
  }

  @wire(getRecord, { recordId: "$recordId", fields: CONTACT_FIELDS })
  contactInfo({ data, error }) {
    if (data && data.fields) {
      this.countryCode = data.fields.WebsiteCountry__c?.value;
      this.techContactId = data.fields.TECH_WebSiteID__c?.value;
    } else if (error) {
      console.log(error);
    }
  }

  @wire(getShareClassesByCountryWithSub, {
    countryCode: "$countryCode",
    cat: "$alertType",
    contId: "$recordId",
    counter: "$counter"
  })
  wiredClasses(result) {
    if(this.fundOnly) return;
    console.log("@counter: 1" + this.counter);
    this.wiredResult = result;
    if (result.data) {
      let helper = {};
      let groupFund = [];
      let alerts = {};
      groupFund = result.data.reduce(function (r, o) {
        var key = o.Fund__c;
        alerts[o.Id] = {
          daily: { label: "Daily", prospId: "", active: false, checked: false },
          weekly: {
            label: "Weekly",
            prospId: "",
            active: false,
            checked: false
          },
          monthly: {
            label: "Monthly",
            prospId: "",
            active: false,
            checked: false
          },
          performance: {
            label: "Performance",
            prospId: "",
            active: false,
            checked: false
          }
        };

        let regD = new RegExp("daily", "gi");
        let regW = new RegExp("weekly", "gi");
        let regM = new RegExp("monthly", "gi");
        let regPerf = new RegExp("performance", "gi");
        let isDaily = false,
          isWeekly = false,
          isMonthly = false,
          isPerf = false;
        let ischecked = false;

        if (o.WebCommunications__r) {
          o.WebCommunications__r.forEach((alert) => {
            //check existing daily nav sub
            if (
              (regD.test(alert.AlertType__c) ||
                regD.test(alert.AlertTypeRecord__r?.Name)) &&
              !isDaily
            ) {
              ischecked = alert.IsActive__c || ischecked;
              alerts[o.Id].daily = {
                label: "Daily",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isDaily = true;
            }
            if (
              (regW.test(alert.AlertType__c) ||
                regW.test(alert.AlertTypeRecord__r?.Name)) &&
              !isWeekly
            ) {
              ischecked = alert.IsActive__c || ischecked;
              console.log("ischecked", ischecked);
              console.log("isWeekly", isWeekly);
              alerts[o.Id].weekly = {
                label: "Weekly",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isWeekly = true;
            }
            if (
              (regM.test(alert.AlertType__c) ||
                regM.test(alert.AlertTypeRecord__r?.Name)) &&
              !isMonthly
            ) {
              ischecked = alert.IsActive__c || ischecked;
              alerts[o.Id].monthly = {
                label: "Monthly",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isMonthly = true;
            }
            if (
              (regPerf.test(alert.AlertType__c) ||
              regPerf.test(alert.AlertTypeRecord__r?.Name)) &&
              !isPerf
            ) {
              ischecked = alert.IsActive__c || ischecked;
              alerts[o.Id].performance = {
                label: "Performance",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isPerf = true;
            }
          });
        }
        let newO = {
          Id: o.Id,
          Name: o.Name,
          ISIN_Code__c: o.ISIN__c,
          alertTypes: alerts[o.Id],
          type: o.Type__c,
          Hedged: o.Hedged__c,
          ischecked: ischecked,
          CurrencyIsoCode: o.Currency__c,
          IncomeAllocation: o.DividendPolicy__c
        };
        if (!helper[key]) {
          helper[key] = Object.assign(
            {
              Id: o.Fund__c,
              Code: o.Fund__r.Name,
              Name: o.Fund__r.ProductName__c,
              Strategy: {
                Id: o.Fund__r.FundStrategy__c,
                Code: o.Fund__r.FundStrategy__r.Code__c,
                Name: o.Fund__r.FundStrategy__r.Name
              }
            },
            { products: [newO] }
          ); // create a copy of o
          r.push(helper[key]);
        } else helper[key].products.push(newO);
        return r;
      }, []);
      this.selectedAlerts = alerts;
      //groupeByStrat
      this.results = groupFund.reduce(function (r, o) {
        var key = o.Strategy.Id;
        if (!helper[key]) {
          helper[key] = Object.assign(
            { Id: o.Strategy.Id, Code: o.Strategy.Code, Name: o.Strategy.Name },
            { funds: [o] }
          ); // create a copy of o
          r.push(helper[key]);
        } else helper[key].funds.push(o);
        return r;
      }, []);
      if (this.defaultOpenStrat.length === 0) {
        this.defaultOpenStrat.push(this.results[0]?.Id);
      }
      if (this.defaultOpenFund.length === 0) {
        this.defaultOpenFund.push(this.results[0]?.funds[0].Id);
      }
      this.initGroupedData = [...this.results];
      this.isLoading = false;
    } else if (result.error) {
      this.isLoading = true;
      console.log(result.error);
    }
  }

  @wire(getFundsWithSub, {
    cat: "$alertType",
    contId: "$recordId",
    counter: "$counter"
  })
  wiredFunds(result) {
    if(!this.fundOnly) return;
    console.log("@counter: 2" + this.counter);
    this.wiredResult = result;
    if (result.data) {
      let helper = {};
      let groupFund = [];
      let alerts = {};
      groupFund = result.data.reduce(function (r, o) {
        var key = o.Id;
        alerts[o.Id] = {
          fund: {
            label: "Fund",
            prospId: "",
            active: false,
            checked: false
          },
          holdings: {
            label: "Holdings",
            prospId: "",
            active: false,
            checked: false
          }
        };

        let regF = new RegExp("fund", "gi");
        let regH = new RegExp("holdings", "gi");
        
        let isF = false;
        let isH = false;
        let ischecked = false;
        let shC = null;
        if(o.Share_Classes__r){
          shC = o.Share_Classes__r[0].Id;
        }
        if (o.WebCommunications__r) {
          o.WebCommunications__r.forEach((alert) => {
            //check existing Fund Manager's Letter
            if (
              (regF.test(alert.AlertType__c) ||
              regF.test(alert.AlertTypeRecord__r?.Name)) &&
              !isF
            ) {
              console.log('fund')
              ischecked = alert.IsActive__c || ischecked;
              alerts[o.Id].fund = {
                label: "Fund",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isF = true;
            }
            if (
              (regH.test(alert.AlertType__c) ||
              regH.test(alert.AlertTypeRecord__r?.Name)) &&
              !isH
            ) {
              console.log('holdings :'+alert.IsActive__c)
              ischecked = alert.IsActive__c || ischecked;
              alerts[o.Id].holdings = {
                label: "Holdings",
                prospId: alert.Id,
                active: alert.IsActive__c,
                checked: alert.IsActive__c
              };
              isH = true;
            }
          });
        }
        
        if (!helper[key]) {
          helper[key] = Object.assign(
            {
              Id: o.Id,
              Code: o.Name,
              Name: o.ProductName__c,
              alertTypes: alerts[o.Id],
              ischecked: ischecked,
              shareClass: shC,
              Strategy: {
                Id: o.FundStrategy__c,
                Code: o.FundStrategy__r.Code__c,
                Name: o.FundStrategy__r.Name
              }
            }
          ); // create a copy of o
          r.push(helper[key]);
        } 
        return r;
      }, []);
      this.selectedAlerts = alerts;
      //groupeByStrat
      this.results = groupFund.reduce(function (r, o) {
        var key = o.Strategy.Id;
        if (!helper[key]) {
          helper[key] = Object.assign(
            { Id: o.Strategy.Id, Code: o.Strategy.Code, Name: o.Strategy.Name },
            { funds: [o] }
          ); // create a copy of o
          r.push(helper[key]);
        } else helper[key].funds.push(o);
        return r;
      }, []);
      if (this.defaultOpenStrat.length === 0) {
        this.defaultOpenStrat.push(this.results[0]?.Id);
      }
      if (this.defaultOpenFund.length === 0) {
        this.defaultOpenFund.push(this.results[0]?.funds[0].Id);
      }
      //TO DO
      this.initGroupedData = [...this.results];
      this.isLoading = false;
    } else if (result.error) {
      this.isLoading = true;
      console.log(result.error);
    }
  }

  handleSearch(e) {
    this.searchKey = e.target.value;
    this.applyFilter();
  }

  hasMatchingISIN(data, regex) {
    let matchingRows = [];

    data.forEach((row) => {
      let matchingFunds = row.funds.filter((fund) =>
        fund.products.some((product) => regex.test(product.ISIN_Code__c))
      );

      if (matchingFunds.length > 0) {
        let matchingRow = Object.assign({}, row, { funds: [] });

        matchingFunds.forEach((matchingFund) => {
          let matchingFundCopy = Object.assign({}, matchingFund, {
            products: matchingFund.products.filter((product) =>
              regex.test(product.ISIN_Code__c)
            )
          });
          matchingRow.funds.push(matchingFundCopy);
        });

        matchingRows.push(matchingRow);
      }
    });

    return matchingRows;
  }

  handlePeriodSelection(e) {
    console.log('e.target.name: '+e.target.name)
    console.log('e.target.dataset.item: '+e.target.dataset.item)
    this.selectedAlerts[e.target.name][e.target.value].checked =
      e.target.checked;
      if(!this.fundOnly){
        this.selectedProducts[e.target.name] = {
          shareClass: e.target.name,
          fund: e.target.dataset.item,
          alertType: this.selectedAlerts[e.target.name]
        };
      }else{
        this.selectedProducts[e.target.name] = {
          shareClass: e.target.dataset.item,
          fund: e.target.name,
          alertType: this.selectedAlerts[e.target.name]
        };
      }
    
    //add logique to create prospaceAlert here based on id period + compare between
  }

  dispachProspaceAlerts(event) {
    event.preventDefault();
    // Creates the event with the contact ID data.
    const selectedEvent = new CustomEvent("createAlerts", {
      detail: this.selectedProducts
    });
    // Dispatches the event.
    this.dispatchEvent(selectedEvent);
  }

  @api handleSaveSubscriptions() {
    console.log('save')
    this.isLoading = true;
    let prospaceAlerts = [];
    for (let key in this.selectedProducts) {
      if (this.selectedProducts[key]) {
        prospaceAlerts = prospaceAlerts.concat(
          this.createProspaceAlert(this.selectedProducts[key])
        );
      }
    }
    //call save apex
    if (prospaceAlerts.length > 0) {
      saveProspaceAlerts({ alerts: prospaceAlerts })
        .then(() => {
          this.showToast(
            "Subscriptions Updated",
            "All subscriptions were successfully updated",
            "success"
          );
          this.isLoading = false;
          refreshApex(this.wiredResult);
          this.dispatchEvent(new CustomEvent("subscriptionssaved"));
          return true;
        })
        .catch((error) => {
          console.log("@error: " + JSON.stringify(error));
          this.showToast(
            "Subscriptions Not Updated",
            "An error occured while updating your subscriptions. Please try again.",
            "error"
          );
          this.isLoading = false;
        });
    } else {
      this.isLoading = false;
    }
    return false;
  }

  cancelSubscriptions() {
    this.isLoading = true;
    this.results = [...this.initGroupedData];
    this.isLoading = false;
  }

  createProspaceAlert(prod) {
    console.log('here')
    let prospaceAlerts = [];
    let alerts = prod.alertType;
    for (let key in alerts) {
      if (alerts[key] && alerts[key].checked !== alerts[key].active) {
        console.log('alerts[key]:'+alerts[key].checked)
        if (alerts[key].prospId !== "") {
          console.log('prospId not null :'+alerts[key].prospId)
          console.log('prod.shareClass :'+prod.shareClass)
          prospaceAlerts.push({
            ShareClass__c: prod.shareClass,
            Fund__c: prod.fund,
            Contact__c: this.recordId,
            AlertType__c: this.mapAlertTypes[key].webId,
            IsActive__c: alerts[key].checked,
            Id: alerts[key].prospId
          });
        } else {
          console.log('prospId null :'+alerts[key].prospId)
          console.log('prod.shareClass :'+prod.shareClass)
          console.log('prod.Fund__c :'+prod.fund)
          console.log('alert type :'+this.mapAlertTypes[key].webId)
          console.log('checked :'+alerts[key].checked)
          prospaceAlerts.push({
            ShareClass__c: prod.shareClass,
            Fund__c: prod.fund,
            Contact__c: this.recordId,
            AlertType__c: this.mapAlertTypes[key].webId,
            IsActive__c: alerts[key].checked
          });
        }
      }
    }
    console.log('here 1:'+prospaceAlerts)
    return prospaceAlerts;
  }

  expandAll() {
    let expandedFund = [];
    let expandedStrat = [];
    for (let strat in this.initGroupedData) {
      expandedStrat.push(this.initGroupedData[strat].Id);
      for (let fund in this.initGroupedData[strat].funds) {
        expandedFund.push(this.initGroupedData[strat].funds[fund].Id);
      }
    }
    this.defaultOpenFund = expandedFund;
    this.defaultOpenStrat = expandedStrat;
  }

  expandActiveSubAl2l() {
    let expandedFund = [];
    let expandedStrat = [];

    this.initGroupedData.forEach((strategy) => {
      let expStrat = strategy.funds.some((fund) =>
        fund.products.some((product) =>
          Object.values(product.alertTypes).some(
            (alert) => alert.active === true
          )
        )
      );

      if (expStrat) {
        expandedStrat.push(strategy.Id);

        // Only add funds with at least one active product alert
        expandedFund.push(
          ...strategy.funds
            .filter((fund) =>
              fund.products.some((product) =>
                Object.values(product.alertTypes).some(
                  (alert) => alert.active === true
                )
              )
            )
            .map((fund) => fund.Id)
        );
      }
    });

    this.defaultOpenFund = expandedFund;
    this.defaultOpenStrat = expandedStrat;
  }
  // expandActiveSubAll() {
  //   let expandedFund = [];
  //   let expandedStrat = [];
  //   console.log('this.results',this.results);
  //   this.results.forEach((strategy) => {
  //     let expStrat = strategy.funds.some((fund) =>
  //       fund.products.some((product) =>
  //         Object.values(product.alertTypes).some(
  //           (alert) => alert.active === true
  //         )
  //       )
  //     );

  //     if (expStrat) {
  //       expandedStrat.push(strategy.Id);

  //       // Only add funds with at least one active product alert
  //       let filteredFunds = strategy.funds
  //         .filter((fund) =>
  //           fund.products.some((product) =>
  //             Object.values(product.alertTypes).some(
  //               (alert) => alert.active === true
  //             )
  //           )
  //         )
  //         .map((fund) => {
  //           // Filter and return only the active products
  //           return {
  //             ...fund,
  //             products: fund.products.filter((product) =>
  //               Object.values(product.alertTypes).some(
  //                 (alert) => alert.active === true
  //               )
  //             )
  //           };
  //         });

  //       expandedFund.push(...filteredFunds);
  //     }
  //   });

  //   console.log('Results => ', expandedFund);
  //   this.results = expandedFund;
  //   this.defaultOpenFund = expandedFund;
  //   this.defaultOpenStrat = expandedStrat;
  // }

  fillPills(values, icon) {
    let items = [];
    values.forEach((cont) => {
      items.push({ type: "icon", label: cont, name: cont });
    });
    return items;
  }
  handleFreqChange(e) {
    this.selectedFrequency = e.target.value;
    if (this.selectedTypes.length > 0) {
      this.selectionDisabled = false;
    }
  }
  handleItemAddtion(e) {
    this.selectedTypes = [...e.detail.selectedValues];
    this.applyFilter();
    if (this.selectedTypes.length === 0) {
      this.selectionDisabled = true;
    } else if (this.selectedFrequency) {
      this.selectionDisabled = false;
    }
  }
  handleActiveOnly(e) {
    this.activeOnly = e.detail.checked;
    this.applyFilter();
  }
  handleItemAddtionCurrency(e) {
    this.selectedCurrencies = [...e.detail.selectedValues];
    this.applyFilter();
  }
  handleItemAddtionDividendPolicy(e) {
    this.selectedDividendPolicy = [...e.detail.selectedValues];
    this.applyFilter();
  }
  handleHedgedSub(e) {
    this.checkboxHedged = e.detail.checked;
    this.applyFilter();
  }

  applyFilter() {
    this.isLoading = true;

    // Initialize the filtered results with the original results
    let filteredResults = [...this.initGroupedData];
    
    // Apply filters based on selected criteria
    filteredResults = [...this.applyTypeFilter(filteredResults)];
    filteredResults = [...this.applyCurrencyFilter(filteredResults)];
    filteredResults = [...this.applyHedgedFilter(filteredResults)];
    filteredResults = [...this.applyActiveOnlyFilter(filteredResults)];
    filteredResults = [...this.applyDividendPolicyFilter(filteredResults)];
    filteredResults = [...this.applySearchFilter(filteredResults)];

    // Update the results with the filtered results
    this.results = [...filteredResults];
    this.isLoading = false;
    this.expandAll();
  }

  applyTypeFilter(filteredResults) {
    if (this.selectedTypes.length > 0) {
      return this.filterByField(filteredResults, this.selectedTypes, "type");
    }
    return filteredResults;
  }

  applyCurrencyFilter(filteredResults) {
    if (this.selectedCurrencies.length > 0) {
      return this.filterByField(
        filteredResults,
        this.selectedCurrencies,
        "CurrencyIsoCode"
      );
    }
    return filteredResults;
  }

  applyHedgedFilter(filteredResults) {
    if (this.checkboxHedged) {
      let regex = new RegExp(this.checkboxHedged, "gi");
      return this.filterByRegex(filteredResults, regex, "Hedged");
    }
    return filteredResults;
  }

  applyActiveOnlyFilter(filteredResults) {
    console.log("this.activeOnly", this.activeOnly);
    if (this.activeOnly) {
      let regex = new RegExp(this.activeOnly, "gi");
      return this.filterByRegex(filteredResults, regex, "ischecked");
    }
    return filteredResults;
  }

  applyDividendPolicyFilter(filteredResults) {
    if (this.selectedDividendPolicy.length > 0) {
      return this.filterByField(
        filteredResults,
        this.selectedDividendPolicy,
        "IncomeAllocation"
      );
    }
    return filteredResults;
  }

  applySearchFilter(filteredResults) {
    if (this.searchKey.length > 0) {
      console.log('here')
      let regex = new RegExp(this.searchKey, "gi");
      return this.filterByNameOrCode(filteredResults, regex);
    }
    return filteredResults;
  }

  filterByField(data, values, field) {
    let regex = new RegExp(values.join("|"), "gi");
    let matchingRows = [];
    console.log("original data", data);
    console.log("original regex", regex);
    data.forEach((row) => {
      let matchingFunds = row.funds.filter((fund) =>
        fund.products.some((product) => values.includes(product[field]))
      );

      if (matchingFunds.length > 0) {
        let matchingRow = Object.assign({}, row, { funds: [] });

        matchingFunds.forEach((matchingFund) => {
          let matchingFundCopy = Object.assign({}, matchingFund, {
            products: matchingFund.products.filter((product) =>
              values.includes(product[field])
            )
          });
          matchingRow.funds.push(matchingFundCopy);
        });

        matchingRows.push(matchingRow);
      }
    });

    return matchingRows;
  }

  filterByRegex(data, regex, field) {
    let matchingRows = [];
    console.log("data", data);
    if(this.fundOnly){
      data.forEach((row) => {
        let matchingFunds = row.funds.filter((fund) =>{
            regex.lastIndex = 0; // Reset lastIndex before testing the regex
            return regex.test(fund[field]);
        });
  
        if (matchingFunds.length > 0) {
          let matchingRow = Object.assign({}, row, { funds: [] });
          matchingFunds.forEach((matchingFund) => {
            matchingRow.funds.push(matchingFund);
          });
  
          matchingRows.push(matchingRow);
        }
      });
    }else{
      data.forEach((row) => {
        let matchingFunds = row.funds.filter((fund) =>
          fund.products.some((product) => {
            regex.lastIndex = 0; // Reset lastIndex before testing the regex
            return regex.test(product[field]);
          })
        );

        if (matchingFunds.length > 0) {
          let matchingRow = Object.assign({}, row, { funds: [] });
          matchingFunds.forEach((matchingFund) => {
            let matchingFundCopy = Object.assign({}, matchingFund, {
              products: matchingFund.products.filter((product) => {
                if (product[field]) {
                  console.log("product[field]", product);
                }
                regex.lastIndex = 0; // Reset lastIndex before testing the regex
                return regex.test(product[field]);
              })
            });
            matchingRow.funds.push(matchingFundCopy);
          });

          matchingRows.push(matchingRow);
        }
      });
    }
    return matchingRows;
  }

  filterByNameOrCode(data, regex) {
    let matchingRows = this.fundOnly? [] : this.hasMatchingISIN(data, regex);
    console.log('matchingRows'+matchingRows)
    data = data.filter((row) => regex.test(row.Name) || regex.test(row.Code));
    data = data.filter(
      (row) => !matchingRows.some((matchingRow) => matchingRow.Id === row.Id)
    );
    console.log('data'+data)
    let filteredResults = [...matchingRows, ...data];
    return filteredResults;
  }

  filterResultsByField(results, values, field) {
    // Filter the results based on the specified field and values
    return results.filter((row) => {
      // Check if any fund's products match the selected values
      return row.funds.some((fund) =>
        // Check if any product in the fund matches the selected values
        fund.products.some((product) => values.includes(product[field]))
      );
    });
  }

  expandSCA1() {
    let expandedFund = [];
    let expandedStrat = [];

    this.initGroupedData.forEach((strategy) => {
      let expStrat = strategy.funds.some((fund) =>
        fund.products.some((product) =>
          Object.values(product.alertTypes).some(
            (alert) => alert.active === true
          )
        )
      );

      if (expStrat) {
        expandedStrat.push(strategy.Id);

        // Only add funds with at least one active product alert
        expandedFund.push(
          ...strategy.funds
            .filter((fund) =>
              fund.products.some((product) =>
                Object.values(product.alertTypes).some(
                  (alert) => alert.active === true
                )
              )
            )
            .map((fund) => fund.Id)
        );
      }
    });

    this.defaultOpenFund = expandedFund;
    this.defaultOpenStrat = expandedStrat;
  }

  collapseAll() {
    this.defaultOpenStrat = [];
    this.defaultOpenFund = [];
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      variant: variant,
      message: message
    });
    this.dispatchEvent(event);
  }

  @api forceRefresh() {
    refreshApex(this.wiredResult);
  }
}