public class Event_Apex_ValidationRules {
    
    private final PermissionSetAssignment pset;
    private boolean thisUserHasAssignment = false;
    
    private Map<String, Events_Custom_Validation_Rule__mdt> rulesMap;
    
    /*
    private boolean Meeting_Status_CANCELLED_Descri_Required = false;
    private boolean Meeting_Status_CANCELLED_Reason_Required = false;
    private boolean Meeting_Status_CLOSED_COMPLETE_SummaryRq = false;
    private boolean Meeting_Status_CLOSEDCANCELLED_SummaryRq = false;
    private boolean Meeting_Status_NOT_OPEN_ChooseShowFlow  = false;
    private boolean MeetingPreparationFiel_must_not_be_blank  = false;
    */
    public Event_Apex_ValidationRules(){
        
        Set<String> ruleNames = new Set<String>();
        ruleNames.add('Meeting_Status_CANCELLED_Descri_Required');
        ruleNames.add('Meeting_Status_CANCELLED_Reason_Required');
        ruleNames.add('Meeting_Status_CLOSED_COMPLETE_SummaryRq');
        ruleNames.add('Meeting_Status_CLOSEDCANCELLED_SummaryRq');
        ruleNames.add('Meeting_Status_NOT_OPEN_ChooseShowFlow');
        ruleNames.add('MeetingPreparationFiel_must_not_be_blank');
        ruleNames.add('Require_Specific_Subject_Picklist_Values');
        
		List< Events_Custom_Validation_Rule__mdt > rules = [
            SELECT Id, IsActive__c, Developername FROM Events_Custom_Validation_Rule__mdt
            //WHERE DeveloperName IN :ruleNames
        
        ];      
        
        rulesMap = new Map<String, Events_Custom_Validation_Rule__mdt>();
        for(Events_Custom_Validation_Rule__mdt rule : rules){
            rulesMap.put(rule.DeveloperName, rule);
        }
        
        
        
        try{
            pset = [SELECT PermissionSet.Name, 
                    ExpirationDate, 
                    AssigneeId
                    FROM PermissionSetAssignment 
                    WHERE PermissionSet.Name = 'Calendar_Event_NOT_Internal_Meeting_Save_Conditions'
                    
                                             // Calendar_Event_NOT_Internal_Meeting_Save_Conditions
                    
                    AND IsActive = true
                    AND AssigneeId = :UserInfo.getUserId()];	 
            
            system.debug('pset: ' + pset);
            
            if(pset != null && pset.assigneeid == UserInfo.getUserId()){
                thisUserHasAssignment = true;
            }else if(Event_Apex_ValidationRules_Test.isRunningTest == true){
                thisUserHasAssignment = true;
            }
            
        }catch(QueryException qex){}
        
        
        
    }
    
    
    
    public class CustomApexValidationRuleException extends Exception {}
    
    public void validateAllEvents(List<Event> events){
        
        for(Event e : events){
            validateEvent(e);
        }
        
    }
    
    private void validateEvent(Event e){
        
        validate_Meeting_Status_CANCELLED_Descri_Required(e);
        
        validate_Meeting_Status_CANCELLED_Reason_Required(e);
        
        validate_Meeting_Status_CLOSED_COMPLETE_SummaryRq(e);
        
        validate_Meeting_Status_CLOSEDCANCELLED_SummaryRq(e);
        
        validate_Meeting_Status_NOT_OPEN_ChooseShowFlow(e);
        
        validate_MeetingPreparationFiel_must_not_be_blank(e);
        
        validate_Require_Specific_Subject_Picklist_Values(e);
    }
    
    
    private void validate_Meeting_Status_CANCELLED_Descri_Required(Event e){
        
        // 2024-02-09 PTC
        // Meeting_Status_CANCELLED_Descri_Required
        //
        // AND(
        // NOT(ISPICKVAL(Type,'Internal Meeting') )
        // ,
        // ISPICKVAL( Meeting_Status__c ,'Closed - Cancelled')
        // ,
        // ISBLANK( Meeting_Cancelled_Description__c )
        // ,
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // )
        
        if(thisUserHasAssignment && ((rulesMap.get('Meeting_Status_CANCELLED_Descri_Required')).isActive__c )){
            If(e.Type != 'Internal Meeting'){                
                if(e.Meeting_Status__c.equalsIgnoreCase('Closed - Cancelled')){
                    
                    string mcd = e.Meeting_Cancelled_Description__c;
                    if(String.isBlank(mcd)){
                        e.addError('If the Internal Meeting Status is "Completed - Cancelled," then, please, fill in a short description of why the meeting was cancelled. (Applies to all Types other than "Internal Meeting")');
                    }
                    
                }
            }
        }
        
    }
    
    
    
    private void validate_Meeting_Status_CANCELLED_Reason_Required(Event e){
        
        // Meeting_Status_CANCELLED_Reason_Required
        // 
        // AND(
        // NOT(ISPICKVAL(Type,'Internal Meeting') )
        // ,
        // ISPICKVAL( Meeting_Status__c ,'Closed - Cancelled')
        // ,
        // ISBLANK( TEXT(Reason_Meeting_Cancelled__c) )
        // ,
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // )
        
        if(thisUserHasAssignment && (rulesMap.get('Meeting_Status_CANCELLED_Reason_Required')).isActive__c
           ){
            If(e.Type != 'Internal Meeting'){                
                if(e.Meeting_Status__c.equalsIgnoreCase('Closed - Cancelled')){
                    
                    string rmc = e.Reason_Meeting_Cancelled__c;
                    if(String.isBlank(rmc)){
                        e.addError('If the Meeting Status is "Completed - Cancelled" then a Reason Meeting Cancelled must be chosen (Applies to All Meeting Types other than "Internal Meeting")');
                    }
                    
                }
            }
        }
        
    }
    
    private void validate_Meeting_Status_CLOSED_COMPLETE_SummaryRq(Event e){
        
        // Meeting_Status_CLOSED_COMPLETE_SummaryRq 
        //
        // AND(
        // NOT(ISPICKVAL(Type,'Internal Meeting') )
        // ,
        // ISPICKVAL(Meeting_Status__c,'Closed - Complete')
        // ,
        // ISBLANK( Description )
        // ,
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // )
        
        // NOTE: We have switched around the Description field with Summary, and given it a special section
        // on the Event detail page. This can be confusing, take care!
        
        if(thisUserHasAssignment && (rulesMap.get('Meeting_Status_CLOSED_COMPLETE_SummaryRq')).isActive__c
           ){
            If(e.Type != 'Internal Meeting'){                
                if(e.Meeting_Status__c.equalsIgnoreCase('Closed - Complete')){
                    
                    string rmc = e.Description;
                    if(String.isBlank(rmc)){
                        e.addError('You must fill in the Meeting Summary Section before saving a "Closed - Completed" Status Meeting (Applies to all Types other than "Internal Meeting")');
                    }
                    
                }
            }
        }
        
    }
    
    private void validate_Meeting_Status_CLOSEDCANCELLED_SummaryRq(Event e){
        
        // Meeting_Status_CLOSEDCANCELLED_SummaryRq 
        // 
        // AND(
        // NOT(ISPICKVAL(Type,'Internal Meeting') )
        // ,
        // ISPICKVAL(Meeting_Status__c,'Closed - Cancelled')
        // ,
        // ISBLANK( Description )
        // ,
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // )
        
        if(thisUserHasAssignment && (rulesMap.get('Meeting_Status_CLOSEDCANCELLED_SummaryRq')).isActive__c
           
           ){
            If(e.Type != 'Internal Meeting'){                
                if(e.Meeting_Status__c.equalsIgnoreCase('Closed - Cancelled')){
                    
                    string rmc = e.Description;
                    if(String.isBlank(rmc)){
                        e.addError('You must fill in the Meeting Summary Section before saving a "Closed - Cancelled" Status Meeting (Applies to all Types other than "Internal Meeting")');
                    }
                    
                }
            }
        }
        
    }
    
    private void validate_Meeting_Status_NOT_OPEN_ChooseShowFlow(Event e){
        
        // Meeting_Status_NOT_OPEN_ChooseShowFlow 
        // 
        // AND(
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // ,
        // NOT(ISPICKVAL(Type,'Internal Meeting'))
        // ,
        // NOT(
        // ISPICKVAL(Meeting_Status__c, 'Open')
        // ),
        // NOT(OR(
        // ISPICKVAL(Show_New_Task_Flow__c, 'Show') ,
        // ISPICKVAL(Show_New_Task_Flow__c, 'Hide')
        // )
        // )
        // )
        
        if(thisUserHasAssignment && (rulesMap.get('Meeting_Status_NOT_OPEN_ChooseShowFlow')).isActive__c
           
           ){
            If(e.Type != 'Internal Meeting'){                
                if(!e.Meeting_Status__c.equalsIgnoreCase('Open')){
                    
                    string sntf = e.Show_New_Task_Flow__c;
                    
                    if(sntf == null || sntf == ''){
                        e.addError('You must choose Hide or Show if you are closing an Internal Meeting (Applies to all Types other than "Internal Meeting")');
                    }
                    
                    else if(!sntf.equalsIgnoreCase('Hide') && !sntf.equalsIgnoreCase('Show')){
                        e.addError('You must choose Hide or Show if you are closing an Internal Meeting (Applies to all Types other than "Internal Meeting")');
                    }
                    
                }
            }
        }
        
    }
    
    private void validate_MeetingPreparationFiel_must_not_be_blank(Event e){
        
        // MeetingPreparationFiel_must_not_be_blank 
        // 
        // AND(
        // NOT(ISPICKVAL( Type ,'Internal Meeting') )
        // ,
        // ISBLANK( Meeting_Preparation__c )
        // ,
        // $Permission.Obey_Event_Save_Unless_Internal_Meetings
        // )
        
        if(thisUserHasAssignment && (rulesMap.get('MeetingPreparationFiel_must_not_be_blank')).isActive__c
           
           ){
            If(e.Type != 'Internal Meeting'){                
                if(String.isBlank(e.Meeting_Preparation__c)){
                    
                    e.addError('The Meeting Preparation field cannot be blank (Applies to all Types other than "Internal Meeting")');
                    
                }
            }
        }
        
    }
    
    private void validate_Require_Specific_Subject_Picklist_Values(Event e){
        
        // AND(
		// Subject <> 'Annual Meeting',
		// Subject <> 'Buying Group',
		// Subject <> 'Conference',
		// Subject <> 'Lunch N Learn',
		// Subject <> 'General Meeting',
		// Subject <> 'Project Meeting',
		// Subject <> 'Marketing',
		// Subject <> 'Trade Show',
		// Subject <> 'Training',
		// Subject <> 'Other'
		// )
        
        if(thisUserHasAssignment && (rulesMap.get('Require_Specific_Subject_Picklist_Values')).isActive__c
           
           ){
            If(!(e.Type == 'Internal Meeting')){  
                
                Map<String, String> valueToLabel = getActivePicklistValues('Event', 'Subject');
                
                system.debug('***** valueToLabel.keyset(): ' + valueToLabel.keyset());
                system.debug('***** valueToLabel.values(): ' + valueToLabel.values());
                system.debug('***** e.Type: ' + e.Subject);
                
                if(!valueToLabel.keyset().contains(e.Subject)){
                    
                    e.addError('If the Event Type is not \'Internal Meeting\', You must use a value from the Subject Field Picklist');
                    
                }
            }
        }
        
    }
    
    public static Map<String, String> getActivePicklistValues(String objectName, String fieldName) {

        Map<String, String> values = new Map<String, String>{};

        List<Schema.DescribeSobjectResult> results = Schema.describeSObjects(new List<String>{objectName});

        for(Schema.DescribeSobjectResult res : results) {

            for (Schema.PicklistEntry entry : res.fields.getMap().get(fieldName).getDescribe().getPicklistValues()) {

                if (entry.isActive()) {

                    values.put(entry.getValue(), entry.getLabel());

                }

            }

        }

        return values;

    }
    
    
    
}