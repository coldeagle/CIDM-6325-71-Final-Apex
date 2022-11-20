@RestResource(UrlMapping='/postEvents/v1/*')
global without sharing class EventSchedulerPost {
    @TestVisible static String testLastName = 'TestLN';

    global class EventSchedulerReq {
        global String firstName;
        global String lastName;
        global String email;
        global String phone;
        global String company;
        global String scheduledDate;
        global String scheduleTime;
        global String description;
        global Decimal donationAmount;
        global Integer minutes;
    }

    global class EventSchedulerResp {
        global Boolean isSuccess {
            get {
                if (this.isSuccess == null) this.isSuccess = true;
                return this.isSuccess;
            }
            set;
        }
        global String message;

    }

    @HttpPost
    global static String doPost() {
        EventSchedulerResp returnResp = new EventSchedulerResp();
        try {
            String reqBody = Test.isRunningTest() ? createTestReq() : RestContext.request.requestBody.toString();

            createLeadAndEvent((EventSchedulerReq) JSON.deserialize(reqBody, EventSchedulerReq.class));

        } catch (Exception e) {
            returnResp.isSuccess = false;
            returnResp.message = e.getMessage();
        }
        return JSON.serializePretty(returnResp, false);
    }

    global static void createLeadAndEvent(EventSchedulerReq postReq) {
        Lead l = new Lead(
                FirstName = postReq.firstName,
                LastName = postReq.lastName,
                Email = postReq.email,
                Phone = postReq.phone,
                Company = postReq.company,
                Description = postReq.description
        );
        insert l;

        Date derivedDate = EventSchedulerGet.attemptToGetDate(postReq.scheduledDate);
        List<String> splitTime = postReq?.scheduleTime.split(':');
        if (splitTime != null && splitTime.size() > 1) {
            Time t = Time.newInstance(Integer.valueOf(splitTime[0]), Integer.valueOf(splitTime[1]), 0, 0);
            Datetime startDt = Datetime.newInstance(derivedDate, t);
            Event e = new Event (
                    Subject = 'Appointment Request with $'+postReq.donationAmount+' amount donated',
                    StartDateTime = startDt,
                    EndDateTime = startDt.addMinutes(postReq.minutes),
                    WhoId = l.Id
            );
            insert e;
        }

    }

    @TestVisible static String createTestReq() {
        EventSchedulerReq retObj = new EventSchedulerReq();

        retObj.firstName = 'fn';
        retObj.lastName = testLastName;
        retObj.phone = '999-555-1212';
        retObj.company = 'test co';
        retObj.email = 'test@email.com';
        retObj.scheduledDate = '2022-11-01';
        retObj.scheduleTime = '14:00';
        retObj.minutes = 60;
        retObj.description = 'test';
        retObj.donationAmount = 100;

        return JSON.serializePretty(retObj);
    }

    global class EventSchedulerPostException extends Exception {

    }
}