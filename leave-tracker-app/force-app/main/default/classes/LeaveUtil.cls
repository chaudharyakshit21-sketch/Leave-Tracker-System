/**
 * Helper methods shared by the controller and trigger handler.
 */
public with sharing class LeaveUtil {

    public static final Integer MAX_LEAVE_SPAN_DAYS = 366;

    /** Counts Monday-Friday days between two dates (inclusive). */
    public static Decimal countWorkingDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate < startDate) {
            return 0;
        }
        Integer total = 0;
        Integer span = Math.min(startDate.daysBetween(endDate), MAX_LEAVE_SPAN_DAYS);
        for (Integer i = 0; i <= span; i++) {
            if (isWorkingDay(startDate.addDays(i))) {
                total++;
            }
        }
        return total;
    }

    /** 1900-01-07 was a Sunday, so 0 = Sunday and 6 = Saturday. */
    public static Boolean isWorkingDay(Date d) {
        Integer dayOfWeek = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
        return dayOfWeek != 0 && dayOfWeek != 6;
    }
}
