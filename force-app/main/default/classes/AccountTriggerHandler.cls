public class AccountTriggerHandler {
    
    public static Integer counterAfter {get;set;}
    
    private static string dfltRSM='';
    
    public AccountTriggerHandler(){
        dfltRSM=getDefaultRSM();
    }
    
    public void OnBeforeInsert(List<Account> records){
        validateAcctInsert(records);
        //for Accounts created in the UI set the Sales Team Id 
        populateRSM(records);
        // Type is a problem coming in - PTC 2023-03-03 
        Check_Account_Type_PicklistValuesAgainstCurrentActives(records);        
        assignAccountOwner(records); //for Accounts created by the Syteline Integration set the Owner based on the Sales Team Id
        
    }
    
    public void OnBeforeUpdate(List<Account> updated, Map<Id, Account> oldMap){
        validateAcctUpdate(updated); 
        // Type is a problem coming in - PTC 2023-03-03 
        Check_Account_Type_PicklistValuesAgainstCurrentActives(updated);
        Set<string> RSMs = new Set<string>();
        Set<string> ownerIds = new Set<string>();
        for(Account a : updated){
            Account old = oldMap.get(a.Id);
            if(a.RSM__c != old.RSM__c){
                //need to populate new owner              
                RSMs.add(a.RSM__c);
            }
            else if(a.OwnerId != old.OwnerId){
                ownerIds.add(a.OwnerId);
            }
            //admin forced rerun of assignment logic
            // else if(a.Rerun_Sales_Team_Assignment__c == true && old.Rerun_Sales_Team_Assignment__c != true){
            //     RSMs.add(a.RSM__c);
            // }
        }
        
        if(!RSMs.isEmpty()){
            Map<string, string> userMap = getUsersByRSM(RSMs);
            for(Account a : updated){
                if(RSMs.contains(a.RSM__c)){
                    if(a.RSM__c == null){
                        system.debug('RSM Id is null');
                        //RSM was nulled out -- assign to default user                   
                        a.OwnerId = userMap.get(dfltRSM);
                    }
                    else{
                        system.debug('RSM Id not null: ' + a.RSM__c);
                        //get user id
                        
                        string uid = userMap.get(a.RSM__c);
                        if(uid != null){
                            a.OwnerId = uid;
                        }
                        else{//if no match is found in the user table assign to default user
                            system.debug('no matching user found, assigning to admin user');                         
                            a.OwnerId = userMap.get(dfltRSM);
                        }                      
                    }
                    //reset admin flag if set
                    //   if(a.Rerun_Sales_Team_Assignment__c == true){
                    //       a.Rerun_Sales_Team_Assignment__c = false;
                    //  }
                    
                }
            }
        }
        
        if(!ownerIds.isEmpty()){
            Map<string, string> userMap = getRSMByUser(ownerIds);
            for(Account a : updated){
                if(userMap.containsKey(a.OwnerId)){                   
                    if(userMap.get(a.OwnerId) != dfltRSM){
                        //only update RSM id if it's not set to the admin user
                        a.RSM__c = userMap.get(a.OwnerId);
                    }
                    
                }
            }
        }
    }
    
    public void OnBeforeDelete(List<Account> acctList){
        validateAcctDelete(acctList);
    }
    
    public void OnAfterUpdate(Map<Id,Account> newMap, Map<Id,Account> oldMap){
        updateContactOwners(newMap, oldMap);
    }
    
    @testVisible
    private void updateContactOwners(Map<Id,Account> newMap, Map<Id,Account> oldMap){
        
        Set<Id> acctIds = new Set<Id>();
        
        List<Contact> contacts = new List<Contact>();
        for(Account a :newMap.values()){
            if(a.OwnerId != oldMap.get(a.Id).OwnerId 
               
               //|| oldMap.get(a.Id) == null // <<< should be added to make sure null is null?
               
              ){
                  
                  acctIds.add(a.Id);
                  
              }
        }                  
        
        for(Contact c:[Select OwnerId, AccountId From Contact Where AccountId IN:acctIds]){
            c.OwnerId=newMap.get(c.AccountId).OwnerId;
            contacts.add(c);
        }
        
        if(!contacts.isEmpty()){
            update contacts;
        }
        
    }
    
    public static Map<string, string> getUsersByRSM(Set<string> rsmIds){
        Map<string, string> rsmMap = new Map<string, string>();
        for(User u : [select Id, RSM__c from User where RSM__c in :rsmIds]){
            rsmMap.put(u.RSM__c, u.Id);
        }
        //add admin to list     
        User adm = [select id from User where RSM__c = :dfltRSM];
        rsmMap.put(dfltRSM, adm.Id);
        return rsmMap;
    }
    
    private static Map<string, string> getRSMByUser(Set<string> ownerIds){
        Map<string, string> RSM_Map = new Map<string, string>();
        for(User u : [select Id, RSM__c from User where Id in :ownerIds]){
            RSM_Map.put(u.Id, u.RSM__c);
        }
        return RSM_Map;
    }
    
    public static string getDefaultRSM(){
        String rsm = [Select RSM__c FROM Syteline_Integration_Setting__mdt
                      Where DeveloperName  = 'Default_Account_Owner'].RSM__c;
        if(rsm==''){throw new ApplicationException('Default Account Owner cannot be blank in Syteline_Integration_Setting__mdt');}
        return rsm;
    }
    
    
    private static void populateRSM(List<Account> records){
        Set<string> ownerIds = new Set<string>();
        for(Account a : records){                       
            if(a.External_Id__c ==null /* this 'OR' added to account for incoming Klarco Accounts */|| a.CustSupp__c != null){
                ownerIds.add(a.OwnerId);
            }
        }
        
        if(!ownerIds.isEmpty()){
            Map<string, string> userMap = getRSMByUser(ownerIds);
            for(Account a : records){               
                if(userMap.containsKey(a.OwnerId)){
                    a.RSM__c = userMap.get(a.OwnerId);
                }
            }
        }
    }
    
    private static void assignAccountOwner(List<Account> records){
        Set<string> RSMs = new Set<string>();
        for(Account a : records){                       
            if((a.External_Id__c !=null /* Klarco 'OR' Added: CustSupp */ || a.CustSupp__c != null) && a.RSM__c!=null){
                RSMs.add(a.RSM__c);
            }
        }
        if(!RSMs.isEmpty()){
            Map<string, string> userMap = getUsersByRSM(RSMs);
            system.debug('user map: ' + userMap);
            for(Account a : records){
                if(RSMs.contains(a.RSM__c)){
                    if(a.RSM__c == null){
                        system.debug('RSM is null');
                        //sales team was nulled out -- assign to admin                     
                        a.OwnerId = userMap.get(dfltRSM);
                    }
                    else{
                        system.debug('RSM ID is not null: ' + a.RSM__c);
                        //get user id
                        
                        string uid = userMap.get(a.RSM__c);
                        if(uid != null){
                            a.OwnerId = uid;
                        }
                        else{//if no match is found in the user table assign to admin user
                            system.debug('no matching user found, assigning to admin user');                         
                            a.OwnerId = userMap.get(dfltRSM);
                        }
                        system.debug('user id: '+ uid);
                        system.debug('a.OwnerId: ' + a.OwnerId);
                    }// PTC 2023-10-10 vvv   //sales team was nulled out -- assign to admin                 
                }else if(a.RSM__c == null){ system.debug('RSM is null'); a.OwnerId = userMap.get(dfltRSM);}     
            }        // PTC 2023-10-10 ^^^
        }
    }
    
    
    private void validateAcctInsert(List<Account> records){   
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
        //if record type is Rep_Agency
        //validate that only profile types
        //'T&S Brass - Syteline Integration' 
        //and 'T&S Brass - Syteline Administrator' 
        //can update
        for(Account a:records){
            string recordtypename = Schema.SObjectType.Account.getRecordTypeInfosById().get(a.recordtypeid).getname();
            system.debug('recordtypename: ' + recordtypename);
            if(recordtypename=='Rep Agency'){
                system.debug('logged in user profile id: ' + (UserInfo.getProfileId()));
                system.debug('syteline integration profile id: ' + sysAdminProfileMap.get('T&S Brass - Syteline Integration'));
                if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                    a.addError('Only the Syteline Integration System Administrator may create Rep Agency Accounts');
                }
            }
        }
    } 
    
    private void validateAcctUpdate(List<Account> records){
        
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
        //if record type is Rep_Agency
        //validate that only profile types
        //'T&S Brass - Syteline Integration' 
        //and 'T&S Brass - Syteline Administrator' 
        //can update
        for(Account a:records){
            string recordtypename = Schema.SObjectType.Account.getRecordTypeInfosById().get(a.recordtypeid).getname();
            if(recordtypename=='Rep Agency'){
                if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                    a.addError('Only the Syteline Integration System Administrator may update Rep Agency Accounts');
                }
            }
        }
    } 
    //private void assignForUpdateKlarcoValues(List<Account> records){}
    private void validateAcctDelete(List<Account> records){
        
        Map<String,Id> sysAdminProfileMap = getSysAdminProfileMap();
        //if record type is Rep_Agency
        //validate that only profile types
        //'T&S Brass - Syteline Integration' and
        //'T&S Brass - System Administrator' can delete
        for(Account a:records){
            string recordtypename = Schema.SObjectType.Account.getRecordTypeInfosById().get(a.recordtypeid).getname();
            if(recordtypename=='Rep Agency'){
                if(!sysAdminProfileMap.values().contains(UserInfo.getProfileId())){
                    a.addError('Only a System Administrator may delete Rep Agency Accounts');
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
    
    private class ApplicationException extends Exception{}
    
    public static void Check_Account_Type_PicklistValuesAgainstCurrentActives(List<Account> records){
        
        Set<String> pickListValuesSet= new Set<String>();
        Schema.DescribeFieldResult fieldResult = Account.Type.getDescribe();
        List<Schema.PicklistEntry> ples = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ples){
            if(pickListVal.isActive() == true){
                system.debug('Picklist Values: ' + picklistVal.getLabel());
                pickListValuesSet.add(pickListVal.getValue());
            }
        }     
        
        system.debug('records: ' + records);
        
        for(Account a:records){
            
            system.debug('a.Type: ' + a.Type);
            
            if(a.Type == null || a.Type == ''){
                a.Type = 'Other';
                system.debug('a.Type CHANGED bc NULLORBLANK: ' + a.Type);
            }
            
            if(!pickListValuesSet.contains(a.Type)){
                
                system.debug('PICKLIST VALUE SET does not include ' + a.Type);
                a.addError('Type must be within existing picklist values. [' + a.Type + '] is not among them.' );
                
            }
        }
        
    }
    
}