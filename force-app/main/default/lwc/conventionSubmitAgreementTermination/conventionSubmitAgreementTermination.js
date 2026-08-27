/**
 * @description Quick action LWC for submitting a Convention__c (Agreement) record for
 *              termination approval. AgreementTermination-specific wrapper: configures
 *              and renders the generic c-custom-approval-submit-screen with this
 *              process's settings.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';

export default class ConventionSubmitAgreementTermination extends LightningElement {

    @api recordId;
}