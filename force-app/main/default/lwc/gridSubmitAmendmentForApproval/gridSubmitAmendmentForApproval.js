/**
 * @description Quick action LWC for submitting a Grid__c record for approval.
 *              GridAmendment-specific wrapper: configures and renders the
 *              generic c-custom-approval-submit-screen with this process's
 *              settings. Add new processes by copying this wrapper with a
 *              different processName rather than editing the generic screen.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';

const PROCESS_NAME = 'GridAmendment';

export default class GridSubmitForApproval extends LightningElement {

    @api recordId;

    processName = PROCESS_NAME;
}
