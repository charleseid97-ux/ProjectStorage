import { LightningElement, api, track, wire } from 'lwc';

import getProductHierarchy from '@salesforce/apex/productHierarchyController.getProductHierarchy';

import getAllProductHierarchy from '@salesforce/apex/ProductHierarchyAllController.getProductHierarchy';

import getPickListValues from '@salesforce/apex/PicklistController.getPickListValuesCustomContries';


export default class ProductHierarchy extends LightningElement 
{
    fieldName = 'Country__c';
    
    objectName = 'Share_Class__c';

    @track countries;

    @track selectedCountry = 'All countries';

    @track items = [];
    
    @api recordId;

    // value of show SRI checkbox
    showSRI = false;
    // value of show regional focus checkbox
    showRF = false;
    // value of show asset class checkbox
    showAC = false;
    // whether the product is a regional focus or an asset class
    ishighlevel = false;

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

        getPickListValues(
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
        });

        console.log('rec id ', this.recordId);

        if(this.recordId != null)
        {
            getProductHierarchy(
                {
                    productId : this.recordId,
                    showSRI : this.showSRI,
                    showRF : this.showRF,
                    showAC : this.showAC,
                    country : this.selectedCountry
                }
                ).then(
                result => 
           {
               console.log('Result : ',JSON.stringify(result));

               this.items = [JSON.parse(result)];
   
               this.items = this.items.filter(function(value, index, arr)
               { 
                   console.log('filtered values '+ value.items);
                   
                   return value.items != null;
               });

               console.log(this.items[0].ishighlevel);
   
               if(this.items[0].ishighlevel)
               {
                   this.ishighlevel = true;
               }
           }
           ).catch(error => 
               {
                   console.log('error is ', JSON.stringify(error));
               }
           )
        } 
        else
        {
            getAllProductHierarchy(
            {
                productId : this.recordId,
                showSRI : this.showSRI,
                showRF : this.showRF,
                showAC : this.showAC,
                country : this.selectedCountry
            }
            ).then(
                result => 
                {
                    console.log('show items');
                    
                    this.items = [JSON.parse(result)];

                    console.log('filtered values '+ JSON.stringify(this.items[0].items[0].items));
              
                    console.log(this.items[0].ishighlevel);
        
                    if(this.items[0].ishighlevel)
                    {
                        this.ishighlevel = true;
                    }
                }
           ).catch(error => 
               {
                   console.log('error is ', JSON.stringify(error));
               }
           )
        }   
    }


    handleCountryChange(event)
    {
        this.selectedCountry = event.target.value;

        console.log('selected country : ' +this.selectedCountry);

        this.connectedCallback();
    }

    handleChangeAssetCbx(event)
    {
        this.showAC = event.target.checked;

        if(this.showAC){this.showRF = !event.target.checked;}

        console.log('this AC ', this.showAC);

        this.connectedCallback();
    }

    handleChangeRegionalCbx(event)
    {
        this.showRF = event.target.checked;
        
        if(this.showRF){this.showAC = !event.target.checked;}

        console.log('this RF ', this.showRF);

        this.connectedCallback();
    }

    handleChangeSRICbx(event)
    {
        this.showSRI = event.target.checked;

        console.log('this SRI ', this.showSRI);

        this.connectedCallback();
    }

    countryPickList = 
    {
        data : 
        {
            values : 
            [
                {
                    value : 'LU',
                    label : 'Luxembourg'
                },
                {
                    value : 'AT',
                    label : 'Austria'
                },
                {
                    value : 'BE',
                    label : 'Belgium'
                },{
                    value : 'FR',
                    label : 'France'
                },{
                    value : 'DE',
                    label : 'Germany'
                },{
                    value : 'GB',
                    label : 'Great Britain'
                },{
                    value : 'IT',
                    label : 'Italy'
                },{
                    value : 'ES',
                    label : 'Spain'
                },{
                    value : 'SE',
                    label : 'Sweden'
                },{
                    value : 'CH',
                    label : 'Switzerland'
                },{
                    value : 'TW',
                    label : 'Taiwan'
                },{
                    value : 'NL',
                    label : 'The Netherlands'
                },{
                    value : 'PT',
                    label : 'Portugal'
                }, 
            ]
        }
    }

    /*items = [
        {
            label: 'Product',
            name: '1',
            expanded: false,
            items: [
                {
                    label: 'Fund 1',
                    name: '2',
                    expanded: false,
                    items: [
                        {
                            label: 'Share 1 ',
                            name: '3',
                            expanded: false,
                            items: [],
                        },
                        {
                            label: 'Share 2',
                            name: '4',
                            expanded: false,
                            items: [],
                        },
                    ],
                },
            ],
        }
    ];*/
}