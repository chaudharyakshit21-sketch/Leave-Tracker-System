@IsTest
public class LeaveTestDataFactory {

    /** Next Monday that is at least one week away. */
    public static Date nextMonday() {
        Date d = Date.today().addDays(7);
        while (Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7) != 1) {
            d = d.addDays(1);
        }
        return d;
    }

    public static Leave_Balance__c createBalance(Id employeeId, String leaveType, Decimal total, Integer year) {
        Leave_Balance__c b = new Leave_Balance__c(
            Employee__c = employeeId, Leave_Type__c = leaveType,
            Balance_Year__c = year, Total_Days__c = total, Used_Days__c = 0
        );
        insert b;
        return b;
    }

    public static Leave_Request__c createRequest(Id employeeId, String leaveType, Date startDate, Date endDate) {
        Leave_Request__c r = new Leave_Request__c(
            Employee__c = employeeId, Manager__c = employeeId, Leave_Type__c = leaveType,
            Start_Date__c = startDate, End_Date__c = endDate,
            Reason__c = 'Test reason', Status__c = 'Draft'
        );
        insert r;
        return r;
    }
}
