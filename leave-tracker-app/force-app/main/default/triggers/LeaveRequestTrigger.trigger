trigger LeaveRequestTrigger on Leave_Request__c (before insert, before update, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        LeaveRequestTriggerHandler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        LeaveRequestTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        LeaveRequestTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
