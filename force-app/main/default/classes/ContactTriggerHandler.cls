public class ContactTriggerHandler {

    private Map<Id,Account> acctMap;
    private List<Contact> contactListNew;
    private List<Contact> contactListOld;
     private Map<string,Custom_Error_Message__mdt> errorMsgMdtMap;

    public ContactTriggerHandler(List<Contact> contactListNew, List<Contact> contactListOld){
        this.contactListNew=contactListNew;
        this.contactListOld=contactListOld;
        errorMsgMdtMap=getCustomErrorMsgMdtMap();
    }

     public void OnBeforeInsert(){
        acctMap=getAccountMap(contactListNew);
         validateContactInsert();
         assignContactOwner();
     }

    public void OnBeforeUpdate(){
        acctMap=getAccountMap(contactListNew);
        validateContactUpdate();
    }
    
    public void OnBeforeDelete(){
        acctMap=getAccountMap(contactListOld);
        validateContactDelete();
    }

    public void assignContactOwner(){      
            system.debug('Acct Map: ' + acctMap);
        	//assign the Contact that Owner
             for(Contact c:contactListNew){     
                 if(acctMap.get(c.AccountId)!=null){
                 	c.OwnerId=acctMap.get(c.AccountId).OwnerId;      
                 }
             }		
    }
    private Map<Id,Account> getAccountMap(List<Contact> thisContactList){
        Set<Id> acctIds = new Set<Id>();
        Map<Id,Account> acctMap = new Map<Id,Account>();             
        for(Contact c:thisContactList){
            system.debug('this Contact: ' + c);
            acctIds.add(c.AccountId);
        }
        system.debug('acctIds: ' + acctIds);
        for(Account a:[Select Id, OwnerId, RecordTypeId, RecordType.DeveloperName From Account Where Id IN:acctIds]){
            acctMap.put(a.Id,a);
        }		
        system.debug('acctMap: ' + acctMap);
        return acctMap;                          
    }


    private void validateContactInsert(){
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
          //if record type of the related Account is Rep_Agency
        //validate that only profile type
        //'T&S Brass - Syteline Integration' 
        //and 'T&S Brass - System Administrator'
        //can insert
        for(Contact c:contactListNew){
            system.debug('validateContactInsert.acctMap: ' + acctMap);
            system.debug('validateContactInsert.c.AccountId: ' + c.AccountId);
            if(c.AccountId==null){continue;}
            string acctRecordTypName = acctMap.get(c.AccountId).RecordType.DeveloperName;
            if(acctRecordTypName=='Rep_Agency'){

                system.debug('sysAdminProfileMap: ' + sysAdminProfileMap);
                system.debug('UserInfo.getProfileId(): ' + UserInfo.getProfileId());               
                   if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                       c.addError(errorMsgMdtMap.get('Rep_Contact_Insert_Error_Message').Message_Text__c);
                   }
            }
        }
    } 

    private void validateContactUpdate(){
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
          //if record type of the related Account is Rep_Agency
        //validate that only profile type
        //'T&S Brass - Syteline Integration' 
         //and 'T&S Brass - System Administrator'
        //can update
        for(Contact c:contactListNew){
            string acctRecordTypName = Schema.SObjectType.Account.getRecordTypeInfosById().get(acctMap.get(c.AccountId).RecordTypeId).getname();
            if(acctRecordTypName=='Rep Agency'){
                if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                       c.addError(errorMsgMdtMap.get('Rep_Contact_Update_Error_Message').Message_Text__c);
                   }
            }
        }
    } 

    private void validateContactDelete(){
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
          //if record type of the related Account is Rep_Agency
        //validate that only profile types
        //'T&S Brass - Syteline Integration' and
        //'T&S Brass - System Administrator' can delete
        for(Contact c:contactListOld){
            string acctRecordTypName = Schema.SObjectType.Account.getRecordTypeInfosById().get(acctMap.get(c.AccountId).RecordTypeId).getname();
            system.debug('acctRecordTypName: ' + acctRecordTypName);
            if(acctRecordTypName=='Rep Agency'){
                   if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                       c.addError(errorMsgMdtMap.get('Rep_Contact_Delete_Error_Message').Message_Text__c);
                   }

            }
        }
    } 

   private Map<String,Id> getSysAdminProfileMap(){
     Map<String,Id> sysAdminProfileMap = new Map<String,Id>();
        for(Profile p:[Select Id,Name From Profile Where Name IN ('T&S Brass - Syteline Integration','T&S Brass - System Administrator')]){
            sysAdminProfileMap.put(p.Name, p.Id);
        }      
        return sysAdminProfileMap;
   }

    private Map<String,Custom_Error_Message__mdt> getCustomErrorMsgMdtMap(){
        Map<string,Custom_Error_Message__mdt> errorMsgMdtMap = new Map<string,Custom_Error_Message__mdt>();
        for (Custom_Error_Message__mdt mdt:[Select DeveloperName, Message_Text__c
        From Custom_Error_Message__mdt
        Where Object_Name__c='Contact']){
        errorMsgMdtMap.put(mdt.DeveloperName, mdt);
       }
       return errorMsgMdtMap;
    }

}