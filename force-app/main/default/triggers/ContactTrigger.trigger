trigger ContactTrigger on Contact (before insert, before update, before delete) {
    if(trigger.isBefore){
        if(trigger.isInsert){
            ContactTriggerHandler h = new ContactTriggerHandler(trigger.new, trigger.old);
            h.OnBeforeInsert();
        }
        if(trigger.isUpdate){
            ContactTriggerHandler h = new ContactTriggerHandler(trigger.new, trigger.old);
            h.OnBeforeUpdate();
        }
        if(trigger.isDelete){
            ContactTriggerHandler h = new ContactTriggerHandler(trigger.new, trigger.old);
            h.OnBeforeDelete();
        }

    }
}