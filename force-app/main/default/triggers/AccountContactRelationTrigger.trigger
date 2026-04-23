trigger AccountContactRelationTrigger on AccountContactRelation (before insert, before delete) {

    
    if(Trigger.isBefore){
        
        AccountContactRelationTriggerHandler handler = new AccountContactRelationTriggerHandler(Trigger.New, Trigger.Old);
        
        if(Trigger.isInsert){
               	
            new AccountContactRelationTriggerHandler(Trigger.New, null).insertAccountContactRelations();
            
        }
                
        if(Trigger.isDelete){
            
            new AccountContactRelationTriggerHandler(null, Trigger.Old).deleteAccountContactRelations();
            
        }
        
    }
    
}