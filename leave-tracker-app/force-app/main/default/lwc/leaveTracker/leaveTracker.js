import { LightningElement } from 'lwc';

/**
 * Container component. Listens to custom events bubbling up from the child
 * components and asks the other children to refresh their wired data.
 */
export default class LeaveTracker extends LightningElement {
    handleLeaveChange() {
        this.refreshChild('c-leave-history');
        this.refreshChild('c-leave-balance-card');
    }

    refreshChild(selector) {
        const child = this.template.querySelector(selector);
        if (child && typeof child.refresh === 'function') {
            child.refresh();
        }
    }
}
