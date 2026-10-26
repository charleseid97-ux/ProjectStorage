import { LightningElement, api, wire } from 'lwc';
import getFeeders from '@salesforce/apex/ProjectFeederController.getFeeders';

export default class FeederSection extends LightningElement {
  @api recordId; // Project Id (record page)

  lines = [];
  error;

  @wire(getFeeders, { projectId: '$recordId' })
  wired({ data, error }) {
    if (data) {
      this.lines = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.lines = [];
      // Optionnel : console
      // eslint-disable-next-line no-console
      console.error(error);
    }
  }

  get hasData() {
    return this.lines && this.lines.length > 0;
  }
}
