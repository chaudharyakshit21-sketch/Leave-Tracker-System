# Leave Tracker Application (LWC + Apex + Flows)

A full-stack employee leave management app on the Salesforce platform. Employees request leave from a Lightning Web Component UI; requests run through a **multi-step Approval Workflow** with **automated email notifications**.

## Features
- **LWC UI** (4 components): `leaveTracker` (container), `leaveRequestForm`, `leaveBalanceCard`, `leaveHistory`
  - dynamic event handling (single `handleChange` for all inputs, custom events `leavesubmitted` / `leavecancelled`)
  - lifecycle hooks (`connectedCallback`) and decorators (`@wire`, `@api`)
  - `lightning-datatable` with dynamic row actions, toast messages, imperative + wired Apex
- **Apex controllers** for server-side logic: leave balance, SOQL queries and DML (`LeaveRequestController`)
- **Trigger + handler** (bulk-safe): working-day calculation, overlap detection, balance validation, balance deduction on approval and restoration on cancellation
- **Approval process** (`Leave_Approval`): Step 1 – line manager; Step 2 – HR queue
- **Email notifications**: approver request email, approved and rejected emails to the employee (workflow alerts + email templates)
- **Flow**: before-save record-triggered flow that defaults the approving manager from `User.ManagerId`
- **Validation rules**: end ≥ start, no back-dating (except Sick), reason required for > 3 days, used ≤ total, employee required
- **Test classes** with positive, negative and bulk (50 records) scenarios

## Data model
| Object | Purpose |
|---|---|
| `Leave_Request__c` | Employee, Manager, Leave Type, Start/End date, Number of Days, Reason, Status |
| `Leave_Balance__c` | Employee, Leave Type, Year, Total Days, Used Days, Remaining Days (formula) |

## Approval flow
```
Employee submits (LWC)  ->  Status: Submitted
   Step 1: Manager approves
   Step 2: HR queue approves
   Final approval  -> Status: Approved, balance deducted, email to employee
   Final rejection -> Status: Rejected, email to employee
```

## Getting started
Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) and a free [Developer Edition org](https://developer.salesforce.com/signup).

```bash
# 1. Authorise your org
sf org login web --alias leave-dev

# 2. Deploy
sf project deploy start --source-dir force-app --target-org leave-dev

# 3. Assign the permission set to yourself
sf org assign permset --name Leave_Tracker_User --target-org leave-dev

# 4. Create this year's leave balances (Annual 20, Sick 10, Casual 8)
sf apex run --file scripts/apex/setup-leave-balances.apex --target-org leave-dev

# 5. Run tests
sf apex run test --test-level RunLocalTests --result-format human --code-coverage --target-org leave-dev

# 6. Open the org -> App Launcher -> "Leave Tracker"
sf org open --target-org leave-dev
```

### Post-deployment setup
1. **HR queue**: *Setup -> Queues -> HR Approvers* -> add your HR users as members.
2. **Managers**: set the *Manager* field on users (*Setup -> Users*). If a user has no manager the request is routed to the requester themselves (handy for demos in a dev org).
3. In a dev org you can approve your own requests via *Approval History* or the *Items to Approve* list.

## Project structure
```
force-app/main/default
├── applications/       Leave Tracker app
├── approvalProcesses/  Leave_Approval (multi-step)
├── classes/            Controller, trigger handler, utilities, tests
├── email/              Email folder + 3 templates
├── flexipages/         Leave Tracker app page
├── flows/              Leave_Request_Set_Manager
├── lwc/                leaveTracker, leaveRequestForm, leaveBalanceCard, leaveHistory
├── objects/            Leave_Request__c, Leave_Balance__c (+ validation rules)
├── permissionsets/     Leave_Tracker_User
├── queues/             HR_Approvers
├── tabs/ triggers/ workflows/
scripts/apex/           Leave balance setup
```

## Tech stack
Salesforce · Lightning Web Components · Apex · SOQL · Flows · Approval Processes · Salesforce DX
