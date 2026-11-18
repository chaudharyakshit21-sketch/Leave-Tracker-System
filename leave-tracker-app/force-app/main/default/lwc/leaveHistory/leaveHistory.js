import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyLeaveRequests from '@salesforce/apex/LeaveRequestController.getMyLeaveRequests';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';

const CANCELLABLE = ['Draft', 'Submitted'];

export default class LeaveHistory extends LightningElement {
    requests = [];
    error;
    wiredResult;

    columns = [
        { label: 'Request', fieldName: 'Name', type: 'text' },
        { label: 'Type', fieldName: 'Leave_Type__c', type: 'text' },
        { label: 'From', fieldName: 'Start_Date__c', type: 'date-local' },
        { label: 'To', fieldName: 'End_Date__c', type: 'date-local' },
        { label: 'Days', fieldName: 'Number_of_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: this.getRowActions } }
    ];

    @wire(getMyLeaveRequests)
    wiredRequests(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.requests = data;
            this.error = undefined;
        } else if (error) {
            this.requests = [];
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get hasRequests() {
        return this.requests.length > 0;
    }

    get isEmpty() {
        return !this.error && this.wiredResult && this.wiredResult.data && this.requests.length === 0;
    }

    // Only pending requests can be cancelled
    getRowActions(row, doneCallback) {
        const actions = CANCELLABLE.includes(row.Status__c)
            ? [{ label: 'Cancel request', name: 'cancel' }]
            : [{ label: 'No actions available', name: 'none', disabled: true }];
        doneCallback(actions);
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'cancel') {
            return;
        }
        try {
            await cancelLeaveRequest({ requestId: event.detail.row.Id });
            this.dispatchEvent(new ShowToastEvent({ title: 'Cancelled', message: 'Leave request cancelled.', variant: 'success' }));
            await this.refresh();
            this.dispatchEvent(new CustomEvent('leavecancelled'));
        } catch (error) {
            const message = error && error.body ? error.body.message : 'Unable to cancel request.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
        }
    }

    @api
    refresh() {
        return refreshApex(this.wiredResult);
    }
}
