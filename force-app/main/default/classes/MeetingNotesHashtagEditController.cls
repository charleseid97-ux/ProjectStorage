public class MeetingNotesHashtagEditController {
	@AuraEnabled
    public static String[] getAllTags() {
        String[] l_Return = new String[]{};
        for (Custom_Topic__c l_Tag : [SELECT Name FROM Custom_Topic__c])
            l_Return.add(l_Tag.Name);
        return l_Return;
    }	
}