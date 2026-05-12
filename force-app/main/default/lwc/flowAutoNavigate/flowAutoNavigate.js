import { LightningElement, api } from 'lwc';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

export default class FlowAutoNavigate extends LightningElement {
  @api recordId;             // any Salesforce Id
  @api openInNewTab = false; // true => new tab

  connectedCallback() {
    const id = (this.recordId || '').trim();
    if (!id) {
      this.dispatchEvent(new FlowNavigationFinishEvent());
      return;
    }

    const url = `/${id}`;

    if (this.openInNewTab === true || this.openInNewTab === 'true') {
      // Best-effort (popup blockers may apply)
      window.open(url, '_blank');
      this.dispatchEvent(new FlowNavigationFinishEvent());
      return;
    }

    // Same tab: HARD redirect so the container can't "snap back" to the launch context
    window.location.assign(url);

    // No need to finish; page is navigating away.
    // (If you want to be explicit, you can keep a tiny delay, but it's usually unnecessary.)
    // setTimeout(() => this.dispatchEvent(new FlowNavigationFinishEvent()), 300);
  }
}