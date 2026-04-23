public class EventTriggerHandler {
    
    private static boolean isCalendarEventSalesConditionUser = (0 < [SELECT Count() FROM PermissionSetAssignment WHERE PermissionSet.Label = 'Calendar Event - NOT Internal Meeting Save Conditions' AND IsActive = true AND AssigneeId = :UserInfo.getUserId()]);
    
    public EventTriggerHandler(){}
    
    public void handleEvents_Before_Insert(List<Event> events){
        // Logic in this method applies only event ids where the type field is marked 'Internal Meeting' 
        if(isCalendarEventSalesConditionUser){
        	fillBlankLocationWithPrimaryAccountAddress(events);
        }
    }
    
    public void handleEvents_After_Insert(List<Event> events){
        
        if(isCalendarEventSalesConditionUser){
            // Logic in this class gathers only event ids where the type field is NOT marked 'Internal Meeting' and
            // so any other kind of meeting should not be bound by its rules for contact account relation
            EventRelationValidator validator = new EventRelationValidator(events);
            
            // Sales has requested that this logic only be applied to events NOT of type 'Internal Meeting' and 
            // therefore, logic has been introduced that keeps the event relations list in the validator
            // class from loading in the first place. When this method runs, there should be no objects 
            // to iterate through or operate on, PTC 2023-10-09
            validator.afterUpdate_AllContactEventRelations_InviteeAndParent_TRUE();
        }
    }
    
    public void handleEvents_Before_Update(List<Event> events){
        
        // Logic in this method applies only event ids where the type field is NOT marked 'Internal Meeting' 
        if(isCalendarEventSalesConditionUser){
        	fillBlankLocationWithPrimaryAccountAddress(events);
        }
    }
    
    public void handleEvents_After_Update(List<Event> events){
        
        // Logic in this class gathers only event ids where the type field is NOT marked 'Internal Meeting' and
        // so any other kind of meeting should not be bound by its rules for contact account relation
        if(isCalendarEventSalesConditionUser){
            EventRelationValidator validator = new EventRelationValidator(events);
            
            // Sales has requested that this logic only be applied to events NOT of type 'Internal Meeting' and 
            // therefore, logic has been introduced that keeps the event relations list in the validator
            // class from loading in the first place. When this method runs, there should be no objects 
            // to iterate through or operate on, PTC 2023-10-09
            validator.afterUpdate_AllContactEventRelations_InviteeAndParent_TRUE();
        }
    }
    
    // BEGIN ....   BEFORE CODE, ALTERS FIELDS, NO DML // 2023-11-09 PTC changing so that entry conditions require permission set   
    private void fillBlankLocationWithPrimaryAccountAddress(List<Event> events){
        
        Map<Id, Id> mapEventIdToWhatId = new Map<Id, Id>();
        Set<Id> acctIds = new Set<Id>();
        for(Event e : events){
            
            if(e.Type != null && !e.Type.equalsIgnoreCase('Internal Meeting')){ // 2023-10-09 NH Patch by PTC // 2023-11-09 switch, add Permission Set
                
                mapEventIdToWhatId.put(e.Id, e.WhatId);
                if(e.WhatId != null){
                    acctIds.add(e.WhatId);
                }
            }
        }
        
        List<Account> accounts = new List<Account>();
        try{
            accounts = [SELECT 
                        Id, 
                        Address_1__c, 
                        Address_2__c, 
                        Address_3__c, 
                        Address_4__c, 
                        Billing_City__c,
                        Billing_State__c,
                        Billing_Country__c,
                        Billing_Zip__c
                        FROM Account
                        WHERE Id IN :acctIds
                        
                       ];
        }catch(Exception ex){
            
        }
        
        Map<Id, Account> mapAccounts;
        if(accounts != null && accounts.size() > 0){    
            mapAccounts = new Map<Id, Account>(accounts);
        }else{
            mapAccounts = new Map<Id, Account>();
        }
        
        
        for(Event e : events){
            
            if(
                // 2023-10-09 NH Patch by PTC
                e.Type != null && !e.Type.equalsIgnoreCase('Internal Meeting')
                &&
                // 2023-10-09 NH Patch by PTC
                (e.WhatId != null) 
                &&
                (e.Location == null || e.Location == '')
                
            ){
                
                Id acctId = mapEventIdToWhatId.get(e.Id);
                
                if(acctId != null){
                    
                    Account a = mapAccounts.get(acctId);
                    
                    if(a != null){
                        
                        // Event.Location is (255)
                        
                        String address = '';
                        
                        if(a.Address_1__c != null) { address += a.Address_1__c + '\n'; }
                        if(a.Address_2__c != null) { address += a.Address_2__c + '\n'; }
                        if(a.Address_3__c != null) { address += a.Address_3__c + '\n'; }
                        if(a.Address_4__c != null) { address += a.Address_4__c + '\n'; }
                        if(a.Billing_City__c != null) { address += a.Billing_City__c + ', '; }
                        if(a.Billing_State__c != null) { address += a.Billing_State__c + '\n'; }
                        if(a.Billing_Zip__c != null) { address += a.Billing_Zip__c + ' '; }
                        if(a.Billing_Country__c != null) { address += a.Billing_Country__c + ' '; }
                        
                        e.Location = address;
                        
                    }
                }
            }
        }
        
        
    }
    //  .....  END BEFORE CODE, NO DML
    
    
    
}