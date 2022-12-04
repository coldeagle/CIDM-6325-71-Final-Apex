/**
 * @description This class is an Apex REST class which will take a post of data (see EventSchedulerReq sub class). The data passed
 * in the request will create a lead and event based on the information passed.
 *
 * @author      Jason Hardy
 */
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
        global Boolean isTestOnly {
            get {
                if (this.isTestOnly == null) this.isTestOnly = false;
                return this.isTestOnly;
            }
            set;
        }
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

    /**
     * @description This is the post function that is called when the REST callout is made.
     * @return      The JSON serialized response to inform whether or not the request was successfully posted
     */
    @HttpPost
    global static String doPost() {
        EventSchedulerResp returnResp = new EventSchedulerResp();
        try {
            String reqBody = Test.isRunningTest() ? createTestReq() : RestContext.request.requestBody.toString().unescapeUnicode();
            reqBody = reqBody.startsWith('"{') ? reqBody.substringAfter('"') : reqBody;
            reqBody = reqBody.endsWith('}"') ? reqBody.substringBeforeLast('"') : reqBody;
            EventSchedulerReq evtSchReq = (EventSchedulerReq) JSON.deserialize(reqBody, EventSchedulerReq.class);
            createLeadAndEvent(evtSchReq);

        } catch (Exception e) {
            returnResp.isSuccess = false;
            returnResp.message = e.getMessage();
            System.debug(e.getMessage());
        }
        return JSON.serializePretty(returnResp, false);
    }

    /**
     * @description     Will create the lead and event from the POST
     * @param postReq   The POST request
     */
    global static void createLeadAndEvent(EventSchedulerReq postReq) {
        Lead l = new Lead(
                FirstName = postReq.firstName,
                LastName = postReq.lastName,
                Email = postReq.email,
                Phone = postReq.phone,
                Company = postReq.company,
                Description = postReq.description
        );

        //We use test only to indicate whether or not to actually create the data. The testing framework for
        //django-salesforce doesn't appear to be able to do mocks with the portion of functionality I was using, so
        //the isTestOnly feature was added to prevent the creation of erroneous information
        if (!postReq.isTestOnly) insert l;

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
            if (!postReq.isTestOnly) insert e;
        }

    }

    /**
     * @description This is for the unit test to create a test request
     * @return      The JSON serialized request
     */
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