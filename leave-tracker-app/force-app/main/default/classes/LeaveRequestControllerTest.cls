@IsTest
private class LeaveRequestTriggerHandlerTest {

    private static final Id ME = UserInfo.getUserId();

    @IsTest
    static void approvalDeductsBalanceAndCancellationRestoresIt() {
        Date monday = LeaveTestDataFactory.nextMonday();
        Leave_Balance__c balance = LeaveTestDataFactory.createBalance(ME, 'Annual', 10, monday.year());
        Leave_Request__c r = LeaveTestDataFactory.createRequest(ME, 'Annual', monday, monday.addDays(2));

        r.Status__c = 'Approved';
        update r;
        balance = [SELECT Used_Days__c, Remaining_Days__c FROM Leave_Balance__c WHERE Id = :balance.Id];
        System.assertEquals(3, balance.Used_Days__c.intValue());
        System.assertEquals(7, balance.Remaining_Days__c.intValue());

        r.Status__c = 'Cancelled';
        update r;
        balance = [SELECT Used_Days__c FROM Leave_Balance__c WHERE Id = :balance.Id];
        System.assertEquals(0, balance.Used_Days__c.intValue());
    }

    @IsTest
    static void rejectedRequestDoesNotTouchBalance() {
        Date monday = LeaveTestDataFactory.nextMonday();
        Leave_Balance__c balance = LeaveTestDataFactory.createBalance(ME, 'Annual', 10, monday.year());
        Leave_Request__c r = LeaveTestDataFactory.createRequest(ME, 'Annual', monday, monday);
        r.Status__c = 'Rejected';
        update r;
        System.assertEquals(0, [SELECT Used_Days__c FROM Leave_Balance__c WHERE Id = :balance.Id].Used_Days__c.intValue());
    }

    @IsTest
    static void changingDatesRecalculatesDays() {
        Date monday = LeaveTestDataFactory.nextMonday();
        LeaveTestDataFactory.createBalance(ME, 'Annual', 20, monday.year());
        Leave_Request__c r = LeaveTestDataFactory.createRequest(ME, 'Annual', monday, monday);
        System.assertEquals(1, [SELECT Number_of_Days__c FROM Leave_Request__c WHERE Id = :r.Id].Number_of_Days__c.intValue());

        r.End_Date__c = monday.addDays(4);
        update r;
        System.assertEquals(5, [SELECT Number_of_Days__c FROM Leave_Request__c WHERE Id = :r.Id].Number_of_Days__c.intValue());
    }

    @IsTest
    static void bulkInsertForManyEmployeesIsGovernorSafe() {
        Date monday = LeaveTestDataFactory.nextMonday();
        List<User> users = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Date lastDate = monday.addDays(7 * 9 + 4);
        LeaveTestDataFactory.createBalance(users[0].Id, 'Annual', 100, monday.year());
        if (lastDate.year() != monday.year()) {
            // requests spill into next year - give that year a balance too
            LeaveTestDataFactory.createBalance(users[0].Id, 'Annual', 100, lastDate.year());
        }

        List<Leave_Request__c> requests = new List<Leave_Request__c>();
        for (Integer i = 0; i < 50; i++) {
            // one day each, on distinct weekdays so nothing overlaps
            Date d = monday.addDays(7 * (i / 5) + Math.mod(i, 5));
            requests.add(new Leave_Request__c(
                Employee__c = users[0].Id, Manager__c = users[0].Id, Leave_Type__c = 'Annual',
                Start_Date__c = d, End_Date__c = d, Status__c = 'Draft'
            ));
        }
        Test.startTest();
        insert requests;
        Test.stopTest();
        System.assertEquals(50, [SELECT COUNT() FROM Leave_Request__c]);
    }

    @IsTest
    static void backdatedLeaveRejectedExceptSick() {
        Date yesterday = Date.today().addDays(-1);
        Leave_Request__c annual = new Leave_Request__c(Employee__c = ME, Manager__c = ME, Leave_Type__c = 'Unpaid',
            Start_Date__c = yesterday, End_Date__c = yesterday);
        System.assert(!Database.insert(annual, false).isSuccess());
    }

    @IsTest
    static void longLeaveNeedsReason() {
        Date monday = LeaveTestDataFactory.nextMonday();
        Leave_Request__c r = new Leave_Request__c(Employee__c = ME, Manager__c = ME, Leave_Type__c = 'Unpaid',
            Start_Date__c = monday, End_Date__c = monday.addDays(4));
        System.assert(!Database.insert(r, false).isSuccess(), 'Reason required for > 3 days');
    }
}