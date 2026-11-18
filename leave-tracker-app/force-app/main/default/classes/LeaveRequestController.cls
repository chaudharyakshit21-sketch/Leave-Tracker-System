/**
 * Apex controller for the Leave Tracker LWCs.
 * Server-side logic: leave balance, SOQL queries and DML.
 */
public with sharing class LeaveRequestController {

    @TestVisible
    private static Boolean skipApproval = false;

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getMyLeaveRequests() {
        return [
            SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c,
                   Number_of_Days__c, Status__c, Reason__c
            FROM Leave_Request__c
            WHERE Employee__c = :UserInfo.getUserId()
            ORDER BY Start_Date__c DESC, CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Balance__c> getMyLeaveBalances() {
        Integer thisYear = Date.today().year();
        return [
            SELECT Id, Leave_Type__c, Total_Days__c, Used_Days__c, Remaining_Days__c
            FROM Leave_Balance__c
            WHERE Employee__c = :UserInfo.getUserId() AND Balance_Year__c = :thisYear
            ORDER BY Leave_Type__c
        ];
    }

    @AuraEnabled
    public static Id submitLeaveRequest(String leaveType, Date startDate, Date endDate, String reason) {
        if (String.isBlank(leaveType) || startDate == null || endDate == null) {
            throwAura('Leave type, start date and end date are required.');
        }
        if (endDate < startDate) {
            throwAura('End date cannot be before the start date.');
        }

        Id userId = UserInfo.getUserId();
        User me = [SELECT Id, ManagerId FROM User WHERE Id = :userId LIMIT 1];

        Leave_Request__c request = new Leave_Request__c(
            Employee__c = userId,
            // Falls back to the requester when no manager is configured (e.g. in a dev org)
            Manager__c = me.ManagerId != null ? me.ManagerId : userId,
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Reason__c = reason,
            Status__c = 'Draft'
        );

        try {
            insert request;
            if (!skipApproval) {
                submitForApproval(request.Id);
            }
        } catch (DmlException e) {
            throwAura(e.getDmlMessage(0));
        } catch (Exception e) {
            throwAura(e.getMessage());
        }
        return request.Id;
    }

    @AuraEnabled
    public static void cancelLeaveRequest(Id requestId) {
        List<Leave_Request__c> rows = [
            SELECT Id, Status__c FROM Leave_Request__c
            WHERE Id = :requestId AND Employee__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throwAura('Leave request not found.');
        }
        Leave_Request__c request = rows[0];
        if (request.Status__c != 'Draft' && request.Status__c != 'Submitted') {
            throwAura('Only Draft or Submitted requests can be cancelled.');
        }

        try {
            // Recall any pending approval first so the record is editable
            for (ProcessInstanceWorkitem item : [
                SELECT Id FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :requestId AND ProcessInstance.Status = 'Pending'
            ]) {
                Approval.ProcessWorkitemRequest recall = new Approval.ProcessWorkitemRequest();
                recall.setAction('Removed');
                recall.setWorkitemId(item.Id);
                Approval.process(recall);
            }
            request.Status__c = 'Cancelled';
            update request;
        } catch (DmlException e) {
            throwAura(e.getDmlMessage(0));
        }
    }

    private static void submitForApproval(Id requestId) {
        Approval.ProcessSubmitRequest submission = new Approval.ProcessSubmitRequest();
        submission.setObjectId(requestId);
        submission.setSubmitterId(UserInfo.getUserId());
        submission.setComments('Submitted via Leave Tracker');
        Approval.process(submission);
    }

    private static void throwAura(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        throw ex;
    }
}
