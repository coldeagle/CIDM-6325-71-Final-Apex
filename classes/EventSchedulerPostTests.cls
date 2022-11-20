@IsTest
private class EventSchedulerPostTests {
    @IsTest
    static void positiveTest() {
        Test.startTest();
        EventSchedulerPost.EventSchedulerResp resp = (EventSchedulerPost.EventSchedulerResp) JSON.deserialize(EventSchedulerPost.doPost(), EventSchedulerPost.EventSchedulerResp.class);
        System.assert(resp.isSuccess);
        Test.stopTest();
        System.assert(![SELECT Id FROM Lead].isEmpty());
        System.assert(![SELECT Id FROM Event].isEmpty());
    }

    @IsTest
    static void negativeTest() {
        Test.startTest();
        EventSchedulerPost.testLastName = null;
        EventSchedulerPost.EventSchedulerResp resp = (EventSchedulerPost.EventSchedulerResp) JSON.deserialize(EventSchedulerPost.doPost(), EventSchedulerPost.EventSchedulerResp.class);
        System.assert(!resp.isSuccess);
        Test.stopTest();
        System.assert([SELECT Id FROM Lead].isEmpty());
        System.assert([SELECT Id FROM Event].isEmpty());
    }
}