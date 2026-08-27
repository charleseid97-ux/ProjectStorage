/**
 * @description Quick action LWC for submitting a Convention__c (Agreement) record for
 *              approval. AgreementRequestApproval-specific wrapper: configures and
 *              renders the generic c-custom-approval-submit-screen with this process's
 *              settings. Shared by Intermediary/Sub-distributor and Investor-without-
 *              Agreement records; which records see the action is controlled entirely
 *              by flexipage visibility rules.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';

export default class ConventionSubmitForApproval extends LightningElement {

    @api recordId;
}