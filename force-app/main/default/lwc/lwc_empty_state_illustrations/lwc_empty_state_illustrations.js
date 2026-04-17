import { LightningElement, api } from 'lwc';
 
export default class Lwc_empty_state_illustrations extends LightningElement {
    @api show_nodata_illustration = false;
    @api show_informational_illustration = false;
    @api show_maintenance_illustration = false;
    @api show_noaccess_illustration = false;
    @api message_to_display = '';
}