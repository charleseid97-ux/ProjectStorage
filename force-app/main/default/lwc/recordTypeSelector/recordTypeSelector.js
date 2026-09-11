/**
 * @description       :
 * @author            : SILA Nicolas
 * @group             :
 * @last modified on  : 09-11-2026
 * @last modified by  :
**/

import { LightningElement, api, wire, track } from 'lwc';

import getRecordTypes
    from '@salesforce/apex/RecordTypeController.getRecordTypes';

import {
    NavigationMixin,
    CurrentPageReference
} from 'lightning/navigation';

import {
    getRecord,
    getFieldValue
} from 'lightning/uiRecordApi';

import ACCOUNT_ID_FIELD
    from '@salesforce/schema/Case.AccountId';

export default class RecordTypeSelector extends NavigationMixin(
    LightningElement
) {

    @api recordId;

    @track showModal = true;
    @track recordTypeOptions = [];
    @track urlRT;
    @track selectedDescription = '';
    @track recordTypeDescriptions = {};

    accountIdFromUrl;
    accountIdFromCase;


    /*
     * Account received when component is opened
     * from Account page:
     *
     * /lightning/n/New_Work_Together_Process
     * ?c__accountId=001...
     */
    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {

        if (pageRef) {

            console.log(
                'RecordTypeSelector PageReference:',
                JSON.stringify(pageRef)
            );

            this.accountIdFromUrl =
                pageRef.state?.c__accountId;

            console.log(
                'Account Id received from URL:',
                this.accountIdFromUrl
            );
        }
    }


    /*
     * Account received when component is opened
     * from an existing Case.
     */
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [ACCOUNT_ID_FIELD]
    })
    wiredCase({ error, data }) {

        if (data) {

            this.accountIdFromCase =
                getFieldValue(
                    data,
                    ACCOUNT_ID_FIELD
                );

            console.log(
                'Case Id:',
                this.recordId
            );

            console.log(
                'Account Id from Case:',
                this.accountIdFromCase
            );

        } else if (error) {

            console.log(
                'No Case context available'
            );
        }
    }


    /*
     * Priority:
     * 1. Account passed in URL
     * 2. Account from current Case
     */
    get effectiveAccountId() {

        return (
            this.accountIdFromUrl ||
            this.accountIdFromCase
        );
    }


    /*
     * Load Case Record Types
     */
    @wire(getRecordTypes)
    wiredRecordTypes({ error, data }) {

        if (data) {

            this.recordTypeOptions = data;

            console.log(
                'recordTypeOptions',
                data
            );

        } else if (error) {

            console.error(
                'Error fetching record types',
                error
            );
        }
    }


    closeModal() {

        window.location =
            '/lightning/o/Case/list?filterName=__Recent';
    }


    handleRecordTypeChange(event) {

        this.urlRT =
            event.target.value;

        console.log(
            'urlRT',
            this.urlRT
        );
    }


    handleContinue() {

        console.log(
            'Selected URL:',
            this.urlRT
        );

        console.log(
            'Effective Account Id:',
            this.effectiveAccountId
        );


        if (!this.urlRT) {

            console.error(
                'No record type selected'
            );

            return;
        }


        /*
         * ESG
         *
         * Navigate to dedicated ESG App Page
         * and preserve Account context.
         */
        if (
            this.urlRT.includes(
                '/lightning/n/ESG_Requests'
            )
        ) {

            const state = {};

            if (this.effectiveAccountId) {

                state.c__accountId =
                    this.effectiveAccountId;
            }

            console.log(
                'Navigating to ESG with state:',
                JSON.stringify(state)
            );

            this[NavigationMixin.Navigate]({

                type: 'standard__navItemPage',

                attributes: {
                    apiName: 'ESG_Requests'
                },

                state: state
            });

            return;
        }


        /*
         * Other Record Types
         */
        let targetUrl = this.urlRT;


        /*
         * If launched from Account,
         * prefill Account on standard Case creation.
         */
        if (
            this.effectiveAccountId &&
            targetUrl.includes(
                '/lightning/o/Case/new'
            )
        ) {

            const separator =
                targetUrl.includes('?')
                    ? '&'
                    : '?';

            targetUrl +=
                separator +
                'defaultFieldValues=' +
                encodeURIComponent(
                    'AccountId=' +
                    this.effectiveAccountId
                );
        }


        console.log(
            'Final target URL:',
            targetUrl
        );

        window.location =
            targetUrl;
    }
}