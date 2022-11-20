@IsTest
private class EventSchedulerGetTests {

    @IsTest static void holidayTest() {
        Test.startTest();

        BusinessHours bh = EventSchedulerGet.getBusinessHours();
        List<Holiday> holidays = [SELECT Id, ActivityDate FROM Holiday LIMIT 1];

        Date targetDate = holidays.isEmpty() ? Date.newInstance(Date.today().year(), 12, 25) : holidays[0].ActivityDate;
        Time startTime = EventSchedulerGet.getTimeFromBusinessHour(bh, Datetime.newInstance(targetDate, Time.newInstance(0,0,0,0)), true);
        Datetime targetDt = Datetime.newInstance(targetDate, startTime);

        List<Event> evts = new List<Event>{
                new Event(StartDateTime = targetDt.addDays(3).addMinutes(60), Subject = 'Test4', DurationInMinutes = 60, OwnerId = UserInfo.getUserId()),
                new Event(StartDateTime = targetDt.addDays(2).addMinutes(120), Subject = 'Test3', DurationInMinutes = 60, OwnerId = UserInfo.getUserId()),
                new Event(StartDateTime = targetDt.addDays(2).addMinutes(60), Subject = 'Test2', DurationInMinutes = 60, OwnerId = UserInfo.getUserId()),
                new Event(StartDateTime = targetDt.addDays(2).addMinutes(0), Subject = 'Test1', DurationInMinutes = 30, OwnerId = UserInfo.getUserId()),
                new Event(StartDateTime = targetDt.addDays(0), Subject = 'Test0', DurationInMinutes = 60, OwnerId = UserInfo.getUserId())
        };

        insert evts;


        EventSchedulerGet.static_requestDate = targetDt.format('YYYY-MM-dd');
        EventSchedulerGet.EventSchedulerGetResponse esgr = (EventSchedulerGet.EventSchedulerGetResponse) JSON.deserialize(EventSchedulerGet.doGet(), EventSchedulerGet.EventSchedulerGetResponse.class);

        Test.stopTest();

        System.assert(esgr.isSuccess, 'Response was not successful!');
        if (!holidays.isEmpty()) System.assert(!esgr.available, 'Response should have come back as unavailable!');
    }

    @IsTest static void availableTest() {
        BusinessHours bh = EventSchedulerGet.getBusinessHours();

        Test.startTest();

        Datetime targetDt = BusinessHours.nextStartDate(bh.Id, System.now().addDays(1));

        List<Event> evts = new List<Event>{
                new Event(StartDateTime = targetDt.addDays(0), Subject = 'Test0', DurationInMinutes = 60, OwnerId = UserInfo.getUserId())
        };
        insert evts;
        EventSchedulerGet.static_requestDate = targetDt.format('YYYY-MM-dd');
        EventSchedulerGet.EventSchedulerGetResponse esgr = (EventSchedulerGet.EventSchedulerGetResponse) JSON.deserialize(EventSchedulerGet.doGet(), EventSchedulerGet.EventSchedulerGetResponse.class);

        Test.stopTest();

        System.assert(esgr.isSuccess, 'Response was not successful!');
        System.assert(esgr.available, 'Response should have returned available!');
    }

    @IsTest static void errorTest() {
        Test.startTest();

        EventSchedulerGet.static_requestDate = '2/11/2022';
        EventSchedulerGet.EventSchedulerGetResponse esgr = (EventSchedulerGet.EventSchedulerGetResponse) JSON.deserialize(EventSchedulerGet.doGet(), EventSchedulerGet.EventSchedulerGetResponse.class);

        Test.stopTest();

        System.assert(!esgr.isSuccess, 'Response should not have returned successful!');

    }

    @IsTest static void blankConstructorTest() {

        new EventSchedulerGet.AvailableTime();
        new EventSchedulerGet.AvailableDay();

    }
}