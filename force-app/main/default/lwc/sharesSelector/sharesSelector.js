/**
 * Created by Saad LOZZI on 09/11/2021.
 */

import { LightningElement, api, track, wire } from 'lwc';
import getRelatedShares from '@salesforce/apex/WTPSelectorController.getRelatedShares';
import {
    EXAMPLES_COLUMNS_DEFINITION_BASIC,
    EXAMPLES_DATA_BASIC,
} from './sampleData';

export default class SharesSelector extends LightningElement
{
    @api currentWTPId;
    @track selectedRows = [];
    @track _selectedRowsIds = [];
    @track _productList;
    @track _productsIds;
    @track _products = [];
    @track gridData;

    @api
    get productList()
    {
        console.log('SLI <>>> '+ JSON.stringify(this.productList));
        return this._productList;
    }
    set productList(value)
    {
        this._productList = value;
        this._productsIds = this.getProductIds(this._productList);

        console.log('SLI value >> ' + JSON.stringify(this._productsIds));
        console.log('SLI >> ' + this.currentWTPId);

        getRelatedShares({productsIds : this._productsIds, recordId : this.currentWTPId})
        .then( result =>
        {
            let rows = JSON.parse(result);
            let Ids = [];
            rows.forEach(function(row)
            {
                if(row.checked == true)
                {
                    Ids.push(row.id);
                }
            });
            this.selectedRows = Ids;
            this.gridData = JSON.parse(result);
            const value = this.selectedRows;
            this.addShareEvent(value);
        })
        .catch( error =>
        {
            console.log(error);
        })
    }

    renderedCallback()
    {

    }


    // definition of columns for the tree grid
    gridColumns = EXAMPLES_COLUMNS_DEFINITION_BASIC;

    // data provided to the tree grid


    updateSelectedRows(event)
    {
        this._selectedRowsIds = [];
        const rows = event.detail.selectedRows;
        rows.forEach( row => this._selectedRowsIds.push(row.id) );

        const value = this._selectedRowsIds;
        this.addShareEvent(value);
    }

    addShareEvent(value)
    {
        const sharesAdded = new CustomEvent("sharesadded",
        {
          detail: { value }
        });
        this.dispatchEvent(sharesAdded);
    }

    getProductIds(products)
    {
        console.log('SLI  products >> ', JSON.stringify(products));
        let productsIds = [];
        this._products = [];

        products.forEach(product =>
        {
            productsIds.push(product['Product__c']);
            this._products.push({
                'Id' : product['Product__c'],
                'Name' : product['Product__r'].Name
            });
        });
        console.log('SLI  out products >> ', JSON.stringify(productsIds));
        return productsIds;
    }
}