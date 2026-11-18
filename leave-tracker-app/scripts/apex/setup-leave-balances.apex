// Creates this year's leave entitlements for up to 25 active standard users.
// Run:  sf apex run --file scripts/apex/setup-leave-balances.apex
Integer year = Date.today().year();
Map<String, Decimal> entitlement = new Map<String, Decimal>{ 'Annual' => 20, 'Sick' => 10, 'Casual' => 8 };

List<Leave_Balance__c> balances = new List<Leave_Balance__c>();
for (User u : [SELECT Id FROM User WHERE IsActive = true AND UserType = 'Standard' LIMIT 25]) {
    for (String leaveType : entitlement.keySet()) {
        balances.add(new Leave_Balance__c(
            Employee__c = u.Id,
            Leave_Type__c = leaveType,
            Balance_Year__c = year,
            Total_Days__c = entitlement.get(leaveType),
            Used_Days__c = 0
        ));
    }
}
insert balances;
System.debug('Created ' + balances.size() + ' leave balance records for ' + year);
