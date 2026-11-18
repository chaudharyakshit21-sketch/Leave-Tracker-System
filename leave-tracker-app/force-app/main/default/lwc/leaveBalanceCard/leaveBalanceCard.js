import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMyLeaveBalances from '@salesforce/apex/LeaveRequestController.getMyLeaveBalances';

export default class LeaveBalanceCard extends LightningElement {
    balances = [];
    error;
    wiredResult;

    @wire(getMyLeaveBalances)
    wiredBalances(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.balances = data.map((b) => ({
                ...b,
                usedPercent: b.Total_Days__c > 0 ? ((b.Used_Days__c || 0) / b.Total_Days__c) * 100 : 0
            }));
            this.error = undefined;
        } else if (error) {
            this.balances = [];
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get hasBalances() {
        return this.balances.length > 0;
    }

    get noBalances() {
        return !this.error && this.wiredResult && this.wiredResult.data && this.balances.length === 0;
    }

    /** Called by the parent after a leave request changes. */
    @api
    refresh() {
        return refreshApex(this.wiredResult);
    }
}
