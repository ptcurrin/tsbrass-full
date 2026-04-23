trigger AccountTrigger on Account (before insert, before update, before delete, after update) {
      
    if(trigger.isBefore){
        if(trigger.isInsert && UserInfo.getName()!='Integration User'){
            AccountTriggerHandler h = new AccountTriggerHandler();
            h.OnBeforeInsert(trigger.new);
        }
        if(trigger.isUpdate && UserInfo.getName()!='Integration User'){
            AccountTriggerHandler h = new AccountTriggerHandler();
            h.OnBeforeUpdate(trigger.new, trigger.oldMap);
        }
        if(trigger.isDelete){
            AccountTriggerHandler h = new AccountTriggerHandler();
            h.OnBeforeDelete(trigger.old);
        } if(trigger.isInsert){ AccountTriggerHandler.Check_Account_Type_PicklistValuesAgainstCurrentActives(trigger.new);}
    }
    if(trigger.isAfter){
       
        if(trigger.isUpdate){
            AccountTriggerHandler h = new AccountTriggerHandler();
            h.OnAfterUpdate(trigger.newMap, trigger.oldMap);
        }
    }

}