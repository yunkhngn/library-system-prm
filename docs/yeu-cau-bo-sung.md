# Additional business requirements

Record additional requirements for the next revision of the library entry/exit implementation guidance document. These are business requirements, not implemented functionality or a database design.

## Employee/librarian shift scheduling

Requested by the user on October 7, 2026, after discussing missing use cases in version 1.0 of the document.

### Agreed scope

- Admin creates shifts.
- Admin assigns employees/librarians to shifts.
- Admin adjusts or cancels assignments.
- Admin views schedules and checks employee shift overlaps.
- Employees/librarians view their own schedules.

Individual staff schedules are separate from library opening/closing-hour configuration.

### Points to clarify when revising the document

- Concrete dated shifts versus recurring schedules; handling overnight shifts.
- Number of staff required per shift.
- Rules for overlapping assignments.
- Whether shift swaps, leave, or employee attendance are needed; these are outside the agreed scope.

### Document sections to update

- Admin and employee/librarian roles and interactions.
- Scheduling workflows and use-case inventory.
- Shift/assignment data design once detailed rules are settled.
- Implementation roadmap and related test scenarios.

## Shared account information

Requested by the user on October 7, 2026, during the DB-design review:

- Add email to users.
- Rename student_code to code because librarians also have user codes.
- Use code for accounts across roles; APIs use code instead of studentCode.

This replaces student_code in the version 1.0 Word users design. Required/unique constraints and login rules are proposed in the backend plan; they are not yet implemented.
