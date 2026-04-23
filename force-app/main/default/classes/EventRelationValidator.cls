public class EventRelationValidator {
    
    public class TooManyWhatIdsException extends Exception {}
    public List<EventRelation> eventRelations = new List<EventRelation>();
    
    public void afterUpdate_AllContactEventRelations_InviteeAndParent_TRUE(){
        
        for(EventRelation er : eventRelations){
            string erRelId = er.RelationId;
            if(erRelId.startsWith('003')){
                //er.IsInvitee = true;
                er.IsParent = true;
                //er.IsWhat = false;
            }
        }
        
        update(eventRelations);
        
    }
    
    public EventRelationValidator(List<Event> newEvents){
        
        // use the event WhatIds to find the account relations
        Map<Id, Id> mapEventToAccount = new Map<Id, Id>();
        Set<Id> acctIds = new Set<Id>();
        Set<Id> evtIds = new Set<Id>();
        
        for(Event e : newEvents){
            
            if(e.Type != null && 
               !e.Type.equalsIgnoreCase('Internal Meeting')){
                   
                   evtIds.add(e.Id);
                   
                   Id thisWhatId = e.WhatId;
                   
                   if(thisWhatId != null && thisWhatId.getSobjectType().getDescribe().getName().EqualsIgnoreCase('account')){ 
                       mapEventToAccount.put(e.Id, e.WhatId);
                       acctIds.add(e.WhatId);
                   }
                   
                   if(acctIds.size() > 1){
                       throw new TooManyWhatIdsException('There were ' + acctIds.size() + ' Accounts added to the Related To Field, and only one is allowed. ');
                   }
                   
               }
            
        }
        
        // Find Account Contact Relations for the Accounts Named and Map them
        List<AccountContactRelation> acrs = new List<AccountContactRelation>();
        Map<Id, Set<Id>> mapContactToAccounts = new Map<Id, Set<Id>>();
        try{
            acrs = [SELECT Id, AccountId, ContactId FROM AccountContactRelation WHERE AccountId IN :acctIds];
        }catch(QueryException qex){}
        
        // Map Event Ids to Related Account Ids
        for(AccountContactRelation acr : acrs){
            
            Set<Id> tempSet = mapContactToAccounts.get(acr.ContactId);
            
            if(tempSet == null){
                tempSet = new Set<Id>(); // account Ids
            }
            
            tempSet.add(acr.AccountId);
            
            mapContactToAccounts.put(acr.ContactId, tempSet);
        }
        
        
        // Get EventRelations and map to Event for Comparison
        
        Map<Id, List<EventRelation>> mapEventRelationToEvent = new Map<Id, List<EventRelation>>();
        

        try{
            eventRelations = [SELECT Id, RelationId, EventId, IsParent, IsInvitee 
                              FROM EventRelation 
                              WHERE EventId IN :evtIds 
                              AND IsWhat = false];
        
            for(EventRelation er : eventRelations){
                
                String relIdStr = er.RelationId;
                
                if(relIdStr.startsWith('003')){ // if it's a contact
                    List<EventRelation> tempERs = mapEventRelationToEvent.get(er.EventId);
                    
                    if(tempERs == null){tempERs = new List<EventRelation>(); }
                    
                    tempERs.add(er);
                    
                    mapEventRelationToEvent.put(er.EventId, tempERs);
                    
                }
            }
        
        }catch(QueryException qex){
            
        }
        
        
        for(Event e : newEvents){
            
            if(e.Type != null && 
                !e.Type.equalsIgnoreCase('Internal Meeting')
               && e.WhoId != null 
               && e.WhatId != null 
               && e.WhatId.getSobjectType().getDescribe().getName().EqualsIgnoreCase('account')){
                   
                   List<EventRelation> tempERs = mapEventRelationToEvent.get(e.Id);
                   
                   for(EventRelation er : tempERs){
                       Set<Id> tempAcctIdSet = mapContactToAccounts.get(er.RelationId);
                       
                       if( (tempAcctIdSet == null || !tempAcctIdSet.contains(e.WhatId))  
                          
                          && er.isInvitee == false ){ // <<<<<<<. PTC 2023-07-20 added because top and bottom can't line up perfectly all the time
                           
                           Account errAcct = [SELECT Id, Name FROM Account WHERE Id = :e.WhatId];
                           Contact errCon = [SELECT Id, Name FROM Contact WHERE Id = :er.RelationId];
                           e.addError('The WhatId(Related To) is an Account[(' + errAcct.Id + ')' + errAcct.Name + 
                                      '] and the contact[(' + errCon.Id + ')' + errCon.Name + '] is not related to it. ');
                       }else{
                           
                           system.debug('Not Related');
                           
                       }
                       
                       
                   }
                   
                   
                   /*
                   //EventRelation er = mapRelations.get(e.Id);
                   //system.debug('$$$ er: ' + er);
                   Set<Id> tempAcctIdSet = mapContactToAccounts.get(e.WhoId);
                   system.debug('$$$ tempAcctIdSet: ' + tempAcctIdSet);
                   if(tempAcctIdSet == null || !tempAcctIdSet.contains(e.WhatId)){
                       
                       e.addError('The WhatId(Related To) is an Account and the contact is not related to it. ');
                   }
					*/
               }
        }
        
    } 
    
    
}