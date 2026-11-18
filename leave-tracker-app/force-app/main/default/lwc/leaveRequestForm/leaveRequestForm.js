import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import LEAVE_TYPE_FIELD from '@salesforce/schema/Leave_Request__c.Leave_Type__c';
import submitLeaveRequest from '@salesforce/apex/LeaveRequestController.submitLeaveRequest';

export default class LeaveRequestForm extends LightningElement {
    leaveType;
    startDate;
    endDate;
    reason = '';
    isSaving = false;
    typeOptions = [];

    @wire(getObjectInfo, { objectApiName: LEAVE_REQUEST_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: LEAVE_TYPE_FIELD
    })
    wiredLeaveTypes({ data }) {
        if (data) {
            this.typeOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
        }
    }

    // Lifecycle hook: runs when the component is inserted into the DOM
    connectedCallback() {
        this.setDefaultDates();
    }

    setDefaultDates() {
        const today = new Date();
        const iso = new Date(today.getTime() - today.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
        this.startDate = iso;
        this.endDate = iso;
    }

    /** Dynamic event handling: one handler for every input, keyed by the input's name. */
    handleChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        if (name === 'startDate' && this.endDate && value > this.endDate) {
            this.endDate = value;
        }
    }

    get calculatedDays() {
        if (!this.startDate || !this.endDate || this.endDate < this.startDate) {
            return 0;
        }
        const cursor = new Date(`${this.startDate}T00:00:00`);
        const end = new Date(`${this.endDate}T00:00:00`);
        let days = 0;
        for (let i = 0; cursor <= end && i < 366; i++) {
            const dow = cursor.getDay();
            if (dow !== 0 && dow !== 6) {
                days++;
            }
            cursor.setDate(cursor.getDate() + 1);
        }
        return days;
    }

    async handleSubmit() {
        const allValid = [...this.template.querySelectorAll('lightning-combobox, lightning-input, lightning-textarea')]
            .reduce((valid, field) => field.reportValidity() && valid, true);
        if (!allValid) {
            return;
        }

        this.isSaving = true;
        try {
            const recordId = await submitLeaveRequest({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason
            });
            this.showToast('Success', 'Leave request submitted for approval.', 'success');
            // Notify the parent so the history and balances refresh
            this.dispatchEvent(new CustomEvent('leavesubmitted', { detail: { recordId } }));
            this.resetForm();
        } catch (error) {
            this.showToast('Could not submit leave request', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    resetForm() {
        this.leaveType = undefined;
        this.reason = '';
        this.setDefaultDates();
    }

    reduceError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message).join(', ');
            }
            return error.body.message;
        }
        return (error && error.message) || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
