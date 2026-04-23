trigger LeadTrigger on Lead (after update) {
   
    // When it comes through, for now, it is only to copy to a new kind of RecType Lead, for the purpose of 
    // accessing a related list for immediate visibility for Salesfolks.
    LeadTriggerHandler handler = new LeadTriggerHandler(Trigger.New, Trigger.NewMap, Trigger.OldMap, Trigger.Old);
    
    if(Trigger.isUpdate && Trigger.isAfter){
    
    	handler.onTriggerAfterUpdate();    
    
    }
    
}