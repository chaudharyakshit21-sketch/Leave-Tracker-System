/**
 * Leave_Request__c business rules:
 *  - calculate working days
 *  - block overlapping requests
 *  - validate leave balance on create and on approval
 *  - deduct (or restore) balance when a request is approved (or later cancelled)
 * All logic is bulk-safe (no SOQL/DML inside loops).
 */
public with sharing class LeaveRequestTriggerHandler {

    private static final String UNPAID = 'Unpaid';

    public static void beforeInsert(List<Leave_Request__c> newList) {
        calculateDays(newList);
        validateWorkingDays(newList);
        validateOverlap(newList);
        validateBalance(newList);
    }

    public static void beforeUpdate(List<Leave_Request__c> newList, Map<Id, Leave_Request__c> oldMap) {
        List<Leave_Request__c> dateChanged = new List<Leave_Request__c>();
        List<Leave_Request__c> approving = new List<Leave_Request__c>();
        for (Leave_Request__c r : newList) {
            Leave_Request__c old = oldMap.get(r.Id);
            if (r.Start_Date__c != old.Start_Date__c || r.End_Date__c != old.End_Date__c) {
                dateChanged.add(r);
            }
            if (r.Status__c == 'Approved' && old.Status__c != 'Approved') {
                approving.add(r);
            }
        }
        if (!dateChanged.isEmpty()) {
            calculateDays(dateChanged);
            validateWorkingDays(dateChanged);
            validateOverlap(dateChanged);
        }
        if (!approving.isEmpty()) {
            validateBalance(approving);
        }
    }

    public static void afterUpdate(List<Leave_Request__c> newList, Map<Id, Leave_Request__c> oldMap) {
        List<Leave_Request__c> approved = new List<Leave_Request__c>();
        List<Leave_Request__c> reversed = new List<Leave_Request__c>();
        for (Leave_Request__c r : newList) {
            Leave_Request__c old = oldMap.get(r.Id);
            if (r.Status__c == 'Approved' && old.Status__c != 'Approved') {
                approved.add(r);
            } else if (old.Status__c == 'Approved' && (r.Status__c == 'Cancelled' || r.Status__c == 'Rejected')) {
                reversed.add(r);
            }
        }
        if (!approved.isEmpty()) adjustBalances(approved, 1);
        if (!reversed.isEmpty()) adjustBalances(reversed, -1);
    }

    // ------------------------------------------------------------------

    private static void calculateDays(List<Leave_Request__c> requests) {
        for (Leave_Request__c r : requests) {
            r.Number_of_Days__c = LeaveUtil.countWorkingDays(r.Start_Date__c, r.End_Date__c);
        }
    }

    private static void validateWorkingDays(List<Leave_Request__c> requests) {
        for (Leave_Request__c r : requests) {
            if (r.Start_Date__c != null && r.End_Date__c != null && r.End_Date__c >= r.Start_Date__c
                && r.Number_of_Days__c == 0) {
                r.addError('The selected dates only contain weekends - no working days to request.');
            }
        }
    }

    private static void validateOverlap(List<Leave_Request__c> requests) {
        Set<Id> employeeIds = new Set<Id>();
        Date minStart;
        Date maxEnd;
        for (Leave_Request__c r : requests) {
            if (r.Employee__c == null || r.Start_Date__c == null || r.End_Date__c == null) continue;
            employeeIds.add(r.Employee__c);
            if (minStart == null || r.Start_Date__c < minStart) minStart = r.Start_Date__c;
            if (maxEnd == null || r.End_Date__c > maxEnd) maxEnd = r.End_Date__c;
        }
        if (employeeIds.isEmpty()) return;

        Map<Id, List<Leave_Request__c>> existing = new Map<Id, List<Leave_Request__c>>();
        for (Leave_Request__c e : [
            SELECT Id, Employee__c, Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE Employee__c IN :employeeIds
              AND Status__c IN ('Draft', 'Submitted', 'Approved')
              AND Start_Date__c <= :maxEnd AND End_Date__c >= :minStart
        ]) {
            if (!existing.containsKey(e.Employee__c)) existing.put(e.Employee__c, new List<Leave_Request__c>());
            existing.get(e.Employee__c).add(e);
        }

        for (Leave_Request__c r : requests) {
            if (!existing.containsKey(r.Employee__c) || r.Start_Date__c == null || r.End_Date__c == null) continue;
            for (Leave_Request__c e : existing.get(r.Employee__c)) {
                if (e.Id != r.Id && e.Start_Date__c <= r.End_Date__c && e.End_Date__c >= r.Start_Date__c) {
                    r.addError('You already have a leave request overlapping these dates.');
                    break;
                }
            }
        }
    }

    private static void validateBalance(List<Leave_Request__c> requests) {
        Map<String, Leave_Balance__c> balances = loadBalances(requests);
        for (Leave_Request__c r : requests) {
            if (r.Leave_Type__c == UNPAID || r.Start_Date__c == null) continue;
            Leave_Balance__c b = balances.get(balanceKey(r));
            if (b == null) {
                r.addError('No ' + r.Leave_Type__c + ' leave balance is configured for ' + r.Start_Date__c.year() + '.');
            } else if (b.Remaining_Days__c < r.Number_of_Days__c) {
                r.addError('Insufficient ' + r.Leave_Type__c + ' leave balance. Remaining: '
                    + b.Remaining_Days__c + ' day(s), requested: ' + r.Number_of_Days__c + '.');
            }
        }
    }

    /** direction: +1 deducts days (approval), -1 restores days (cancel/reject after approval). */
    private static void adjustBalances(List<Leave_Request__c> requests, Integer direction) {
        Map<String, Leave_Balance__c> balances = loadBalances(requests);
        Map<Id, Leave_Balance__c> toUpdate = new Map<Id, Leave_Balance__c>();
        for (Leave_Request__c r : requests) {
            if (r.Leave_Type__c == UNPAID) continue;
            Leave_Balance__c b = balances.get(balanceKey(r));
            if (b == null) continue;
            Decimal used = b.Used_Days__c == null ? 0 : b.Used_Days__c;
            b.Used_Days__c = Math.max(0, used + (direction * r.Number_of_Days__c));
            toUpdate.put(b.Id, b);
        }
        if (!toUpdate.isEmpty()) update toUpdate.values();
    }

    private static Map<String, Leave_Balance__c> loadBalances(List<Leave_Request__c> requests) {
        Set<Id> employeeIds = new Set<Id>();
        Set<Decimal> years = new Set<Decimal>();
        for (Leave_Request__c r : requests) {
            if (r.Employee__c != null && r.Start_Date__c != null) {
                employeeIds.add(r.Employee__c);
                years.add(r.Start_Date__c.year());
            }
        }
        Map<String, Leave_Balance__c> result = new Map<String, Leave_Balance__c>();
        if (employeeIds.isEmpty()) return result;
        for (Leave_Balance__c b : [
            SELECT Id, Employee__c, Leave_Type__c, Balance_Year__c, Total_Days__c, Used_Days__c, Remaining_Days__c
            FROM Leave_Balance__c
            WHERE Employee__c IN :employeeIds AND Balance_Year__c IN :years
        ]) {
            result.put(b.Employee__c + '|' + b.Leave_Type__c + '|' + Integer.valueOf(b.Balance_Year__c), b);
        }
        return result;
    }

    private static String balanceKey(Leave_Request__c r) {
        return r.Employee__c + '|' + r.Leave_Type__c + '|' + r.Start_Date__c.year();
    }
}
