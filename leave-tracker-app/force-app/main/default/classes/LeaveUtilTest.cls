@IsTest
private class LeaveUtilTest {

    @IsTest
    static void countsOnlyWeekdays() {
        Date monday = LeaveTestDataFactory.nextMonday();
        System.assertEquals(5, LeaveUtil.countWorkingDays(monday, monday.addDays(4)).intValue(), 'Mon-Fri');
        System.assertEquals(5, LeaveUtil.countWorkingDays(monday, monday.addDays(6)).intValue(), 'Mon-Sun');
        System.assertEquals(2, LeaveUtil.countWorkingDays(monday.addDays(-3), monday).intValue(), 'Fri-Mon');
    }

    @IsTest
    static void weekendOnlyRangeIsZero() {
        Date saturday = LeaveTestDataFactory.nextMonday().addDays(5);
        System.assertEquals(0, LeaveUtil.countWorkingDays(saturday, saturday.addDays(1)).intValue());
    }

    @IsTest
    static void invalidInputsReturnZero() {
        System.assertEquals(0, LeaveUtil.countWorkingDays(null, Date.today()).intValue());
        System.assertEquals(0, LeaveUtil.countWorkingDays(Date.today().addDays(2), Date.today()).intValue());
    }
}
