trigger EventTrigger on Event (before insert, before update, after insert, after update) {
    
    system.debug('User: ' + UserInfo.getUserName());
    system.debug('IsBatch? :     ' + System.isBatch());
    system.debug('IsFuture?:     ' + System.isFuture());
    system.debug('IsQueuable?:   ' + System.isQueueable());
    system.debug('IsSchedueled?: ' + System.IsScheduled());
    system.debug('VF.CurrenPage? ' + ApexPages.currentPage());
    
    
    //Get info about the current request
    Request reqInfo = Request.getCurrent();
    Quiddity qidd = reqInfo.getQuiddity();
    
    try{
        system.debug('RestContxtReq?: ' + RestContext.request);
        system.debug('RestContxtRes?: ' + RestContext.response);
        
        
        
        //Universally unique identifier for this request
        //Same as requestId in splunk or REQUEST_ID in event monitoring
        String currentRequestId = reqInfo.getRequestId();
        
        
        //enum representing how Apex is running. e.g. BULK_API vs LIGHTNING
        //Use this with a switch statement,
        //instead of checking System.isFuture() || System.isQueueable() || ...
        
        system.debug('Quiddity: ' + qidd);
        system.debug('RequestId: ' + reqInfo.getRequestId());
        
        //system.debug('QuiddityShortcode: ' + system.getQuiddityShortCode() );
        
        if((reqInfo.getRequestId()).startswith('TID')){
            system.debug('Starts TID');
        }
        
        
    }catch(Exception ex){
        
    }
    
    integer v = 3;
    integer w = 2;
    integer y = 1;
    integer x = 0;
    integer z = -1;
    
    
    EventTriggerHandler handler = new EventTriggerHandler();
    
    
    
    if(Trigger.isBefore){
        
        
        if((reqInfo.getRequestId()).startswith('TID') || (qidd + '') == 'RUNTEST_SYNC' || (qidd + '') == 'RUNTEST_DEPLOY'){
            system.debug('Request ID Starts TID... or Quiddity is "RUNTEST_SYNC" running Apex Custom Validation Rules');
            
            Event_Apex_ValidationRules rules = new Event_Apex_ValidationRules();
            rules.validateAllEvents(Trigger.New);
            
        }
        
        if(Trigger.isInsert){
            
            handler.handleEvents_Before_Insert(Trigger.New);
            
        }
        
        if(Trigger.isUpdate){
            
            handler.handleEvents_Before_Update(Trigger.New);
            
        }
    }
    
    if(Trigger.isAfter){
        
        if(Trigger.isInsert){
            
            handler.handleEvents_After_Insert(Trigger.New);
            
        }
        
        if(Trigger.isUpdate){
            
            handler.handleEvents_After_Update(Trigger.New);
            
        }
    }
    
}