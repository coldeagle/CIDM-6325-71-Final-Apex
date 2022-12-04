/**
 * @description This class is an apex REST class that will attempt to find dates available based on the request date
 * passed as the param RequestDate. It can also take the Salesforce user name of the user that you would like to look
 * up the availability for, this way it can accommodate the schedules of multiple people. The user name parameter is
 * UserName.
 *
 * It will check the URL parameters and the headers for the variables
 *
 *
 * @author      Jason Hardy
 */
@RestResource(UrlMapping='/getEvents/v1/*')
global without sharing class EventSchedulerGet {
    @TestVisible static String static_requestDate {
        get {
            if (static_requestDate == null) static_requestDate = System.now().format('YYYY-MM-dd');
            return static_requestDate;
        }
        set;
    }
    global class EventSchedulerGetResponse {
        global Boolean available {
            get {
                if (this.available == null) this.available = false;
                return this.available;
            }
            set;
        }
        global Boolean isSuccess {
            get {
                if (this.isSuccess == null) this.isSuccess = true;
                return this.isSuccess;
            }
            set;
        }
        global String message;
        global List<AvailableDay> availableDates {
            get {
                if (this.availableDates == null) this.availableDates = new List<AvailableDay>();
                return this.availableDates;
            }
            set;
        }
        global Date requestedDay;
    }

    global class AvailableDay {
        global Date day;
        global List<AvailableTime> availableTimes {
            get {
                if (this.availableTimes == null) this.availableTimes = new List<AvailableTime>();

                return this.availableTimes;
            }
            set;
        }

        global AvailableDay() {

        }

        global AvailableDay(Datetime dt, List<AvailableTime> times) {
            this.day = dt != null ? dt.date() : null;
            this.availableTimes = times;
        }
    }

    global class AvailableTime {
        global String startTime;
        global String endTime;

        global AvailableTime() {

        }

        global AvailableTime(String startTime, String endTime) {
            this.startTime = startTime;
            this.endTime = endTime;
        }
    }
    /**
     * @description The get method for the apex REST class
     * @return      The get response in JSON
     */
    @HttpGet
    global static String doGet() {
        EventSchedulerGetResponse respObj = new EventSchedulerGetResponse();

        try {
            RestRequest req = Test.isRunningTest() ? getTestRestRequest() : RestContext.request;

            BusinessHours selectedBh = getBusinessHours();

            if (selectedBh == null) throw new EventSchedulerGetException('No valid business hours were found ');

            if (selectedBh != null) {
                // Attempting to get the parameters form the request or headers
                Map<String, String> valPairs = req?.params;
                if (valPairs.isEmpty()) valPairs = req?.headers;

                Date requestedDate = attemptToGetDate(valPairs);
                respObj.requestedDay = requestedDate;

                Time t = getTimeFromBusinessHour(selectedBh, Datetime.newInstance(requestedDate.year(), requestedDate.month(), requestedDate.day()), true);

                Datetime dtRequested = Datetime.newInstance(requestedDate, t);
                Datetime nextAvailable = BusinessHours.nextStartDate(selectedBh.Id, dtRequested);

                respObj.available = BusinessHours.isWithin(selectedBh.Id, dtRequested);

                String userName = getStringValFromValPairs(valPairs, 'UserName');

                Datetime prevAvail = nextAvailable;

                //Getting the availability based on the passed
                respObj.availableDates.add(new AvailableDay(prevAvail, getAvailableTimes(selectedBh, prevAvail, userName)));

                //Getting additional availability over the next 6 days from the initial date requested
                //Note, yes there is a query inside of the loop. This is why there's a limit hard coded here.
                //Generally as a best practice one does not make SOQL queries inside of a loop; however, for the use of
                //this class, I felt it was reasonable given the complexity of finding available days over several days
                for (Integer i = 0; i < 6; i++) {
                    prevAvail = BusinessHours.nextStartDate(selectedBh.Id, prevAvail.addDays(1));
                    respObj.availableDates.add(new AvailableDay(prevAvail, getAvailableTimes(selectedBh, prevAvail, userName)));
                }

            }
        } catch (Exception e) {
            respObj.isSuccess = false;
            respObj.message = e.getMessage()+'/'+e.getStackTraceString();
        }


        return JSON.serialize(respObj, true);
    }

    /**
     * @description Will get a est response, mainly used instead of doing mock which can cause headaches of its won
     * @return      The test rest request
     */
    private static RestRequest getTestRestRequest() {
        Map<String, Object> rawRestResponse = new Map<String, Object>();
        rawRestResponse.put('params', new Map<String, String> {'RequestDate'=>static_requestDate, 'UserName'=>UserInfo.getUserName()});
        rawRestResponse.put('headers', new Map<String, String> {'RequestDate'=>static_requestDate, 'UserName'=>UserInfo.getUserName()});

        return (RestRequest) JSON.deserialize(JSON.serialize(rawRestResponse),RestRequest.class);
    }

    /**
     * @description         This function will get the available times
     * @param selectedBh    The selected business hours object
     * @param dateToCheck   The date to check against
     * @param userName      The user name of the user to check for availability
     *
     * @return              The available times
     */
    global static List<AvailableTime> getAvailableTimes(BusinessHours selectedBh, Datetime dateToCheck, String userName) {
        List<AvailableTime> returnList = new List<AvailableTime>();

        Datetime startDt = Datetime.newInstance(dateToCheck.date(), getTimeFromBusinessHour(selectedBh, dateToCheck, true));
        Datetime endDt = Datetime.newInstance(dateToCheck.date(), getTimeFromBusinessHour(selectedBh, dateToCheck, false));

        List<Time> schStartTimes = new List<Time>();
        List<Time> schEndTimes = new List<Time>();
        if (String.isBlank(userName)) userName = UserInfo.getUserName();
        userName = userName.replaceAll(' ', '+');

        //Getting existing events so we can exclude existing scheduled events
        for (Event e : [
                SELECT  Id, StartDateTime, EndDateTime
                FROM    Event
                WHERE   OwnerId IN (
                            SELECT Id
                            FROM User
                            WHERE Username = :userName
                        )
                        AND StartDateTime >= :dateToCheck.date()
                        AND EndDateTime <= :dateToCheck.date().addDays(1)
                ORDER BY StartDateTime]) {
            schStartTimes.add(simplifyTime(e.StartDateTime.time()));
            schEndTimes.add(simplifyTime(e.EndDateTime.time()));
        }

        Time lastEndTime;
        Time lastStartTime = simplifyTime(startDt.time());

        // Going through the start times so we can filter the existing scheduled events out
        for (Integer i=0; i < schStartTimes.size(); i++) {
            Time startTime = schStartTimes[i];
            Time endTime = schEndTimes[i];

            //Covering the very first bit of availability here, on the first iteration we wouldn't have a last end time
            //so we need to use the original start time from business hours and the current start time as the end
            if (lastEndTime == null && lastStartTime < startTime) {
                returnList.add(new AvailableTime(timeToString(lastStartTime), timeToString(startTime)));
            }

            //If there's a gap between the last event and this event, we'll need to add that gap to the available time
            if (lastEndTime != null && startTime > lastEndTime && endTime > lastEndTime) {
                returnList.add(new AvailableTime(timeToString(lastEndTime), timeToString(startTime)));
            }

            lastStartTime = startTime;
            lastEndTime = endTime;
        }

        //If there wasn't a last meeting or the last meeting is before the end of business hours, we'll want to add that
        //availability
        if (lastEndTime == null || (lastEndTime != null && lastEndTime < simplifyTime(endDt.time()))) {
            lastEndTime = lastEndTime == null ? lastStartTime : lastEndTime; //If we didn't have a last end, that means no events
            returnList.add(new AvailableTime(timeToString(lastEndTime), timeToString(endDt.time())));
        }

        return returnList;
    }

    /**
     * @description Simplifies the time to remove seconds and milliseconds
     * @param t     The time to simplify
     *
     * @return      The simplified time
     */
    global static Time simplifyTime(Time t) {
        return t != null ? Time.newInstance(t.hour(), t.minute(),0,0) : t;
    }

    /**
     * @description Converts time to a string
     * @param t     The time variable to convert
     *
     * @return      The stringified time
     */
    global static String timeToString(Time t) {
        String returnVal = '';

        if (t != null) {
            Integer iHr = t.hour();
            Integer iMin = t.minute();
            String hr = iHr < 10 ? '0'+iHr : String.valueOf(iHr);
            String min = iMin < 10 ? '0'+iMin : String.valueOf(iMin);
        returnVal += hr + ':' + min;
        }

        return returnVal;
    }

    /**
     * @description         Gets the time from the business hours
     * @param selectedBh    The selected business hours object
     * @param dateToCheck   The date to check against
     * @param getStart      Whether or not to get the start time
     *
     * @return              The time
     */
    global static Time getTimeFromBusinessHour(BusinessHours selectedBh, Datetime dateToCheck, Boolean getStart) {
        getStart = getStart == null ? false : getStart;
        String dayName = dateToCheck.format('EEEE');
        return (Time) selectedBh.get(dayName+(getStart ? 'Start' : 'End')+'Time');
    }

    /**
     * @description     Will try to get the date from a string
     * @param dateStr   The string version of the date
     *
     * @return          The date, if it's not correct an exception will be thrown
     */
    global static Date attemptToGetDate(String dateStr) {
        Date returnDate;

        if (String.isNotBlank(dateStr)) {

            if (!dateStr.contains('-')) throw new EventSchedulerGetException('The date ('+dateStr+') was not formatted correctly! It must be YYYY-MM-DD!');

            List<String> dateSplit = dateStr.split('-');

            if (dateSplit.size() == 3) returnDate = Date.newInstance(Integer.valueOf(dateSplit[0]), Integer.valueOf(dateSplit[1]), Integer.valueOf(dateSplit[2]));
            if (dateSplit.size() != 3) throw new EventSchedulerGetException(dateStr+' is not a valid date!');
        }

        return returnDate;
    }

    /**
     * @description     Will attempt to get the date from the value pairs, defaults the key to RequestDate
     * @param valPairs  The map of key to values
     *
     * @return          The date
     */
    global static Date attemptToGetDate(Map<String, String> valPairs) {
        return attemptToGetDate(getStringValFromValPairs(valPairs, 'RequestDate'));
    }

    /**
     * @description         Will attempt to get the date from the value pairs from the key to locate
     * @param valPairs      The value pairs
     * @param keyToLocate   The key to look up
     *
     * @return              The date based on the key to locate from the pairs
     */
    global static String getStringValFromValPairs(Map<String, String> valPairs, String keyToLocate) {
        String returnVal;

        keyToLocate = String.isBlank(keyToLocate) ? '' : keyToLocate;

        for (String key : valPairs.keySet()) {
            if (key.toLowerCase() == keyToLocate.toLowerCase()) returnVal = EncodingUtil.urlDecode(valPairs.get(key), 'UTF-8');
        }

        return returnVal;
    }

    /**
     * @description Retrieves the business hours
     * @return      The business hours that needed to be queried
     */
    global static BusinessHours getBusinessHours() {
        BusinessHours selectedBh;

        for (BusinessHours bh : [
                SELECT  Id, Name, SundayStartTime, SundayEndTime, MondayStartTime, MondayEndTime, TuesdayStartTime,
                        TuesdayEndTime, WednesdayStartTime, WednesdayEndTime, ThursdayStartTime, ThursdayEndTime,
                        FridayStartTime, FridayEndTime, SaturdayStartTime, SaturdayEndTime
                FROM    BusinessHours WHERE IsActive = true AND (Name = :Label.Configured_Business_Hours_Name OR IsDefault = true)]) {
            if (bh.Name == Label.Configured_Business_Hours_Name || (selectedBh == null && bh.IsDefault)) selectedBh = bh;
        }

        return selectedBh;
    }

    global class EventSchedulerGetException extends Exception {

    }
}