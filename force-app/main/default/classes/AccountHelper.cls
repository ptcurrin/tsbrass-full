public class AccountHelper {
    private List<Account> acctList;
	private static string dfltRegSlsMgr;
    private Set<string> regSlsMgrIdSet;
    
    public AccountHelper(List<Account> acctList){
        this.acctList=acctList;
        dfltRegSlsMgr=getDefaultRSM();
        regSlsMgrIdSet=getRegSalesMgrIds();
    }
    
     public List<Database.SaveResult> assignAccountOwner(){
         List<Database.SaveResult> results;
          if(!regSlsMgrIdSet.isEmpty()){            
           Map<string, string> userMap = getUsersByRSM(regSlsMgrIdSet);
              system.debug('user map: ' + userMap);
            for(Account a : acctList){
                if(regSlsMgrIdSet.contains(a.RSM__c)){
                    if(a.RSM__c == null){
                        system.debug('RSM is null');
                        //sales team was nulled out -- assign to admin                     
                       a.OwnerId = userMap.get(dfltRegSlsMgr);
                    }
                    else{
                        system.debug('RSM ID is not null: ' + a.RSM__c);
                        //get user id
                        
                        string uid = userMap.get(a.RSM__c);
                        if(uid != null){
                            a.OwnerId = uid;
                        }
                        else{//if no match is found in the user table assign to admin user
                            system.debug('No matching user found, assigning to default Regional Sales Manager');                         
                            a.OwnerId = userMap.get(dfltRegSlsMgr);
                        }
                        system.debug('user id: '+ uid);
                        system.debug('a.OwnerId: ' + a.OwnerId);
                    }                                     
                }
                // PTC 2023-10-10 vvv
                else if(a.RSM__c == null){
                    system.debug('RSM is null');
                        //sales team was nulled out -- assign to admin                     
                       a.OwnerId = userMap.get(dfltRegSlsMgr);
                    
                }// PTC 2023-10-10 ^^^
            }
          results = Database.update(acctList,false);          
		}     
      return results;
    }
   
    private Set<string> getRegSalesMgrIds(){
         Set<string> rsmIds = new Set<string>();       
         for(Account a: acctList){
             if(a.RSM__c!=null){
                 rsmIds.add(a.RSM__c); 
             }
         }
         system.debug('RSM Ids: ' + rsmIds);
        return rsmIds;
	}
    
    private string getDefaultRSM(){
        String rsm = [Select RSM__c FROM Syteline_Integration_Setting__mdt
                      Where DeveloperName  = 'Default_Account_Owner'].RSM__c;
        if(rsm==''){throw new AccountHelperException('Default Account Owner cannot be blank in Syteline_Integration_Setting__mdt');}
        return rsm;
    }
    
     private Map<string, string> getUsersByRSM(Set<string> rsmIds){
        Map<string, string> rsmMap = new Map<string, string>();
        for(User u : [select Id, RSM__c from User where RSM__c in :rsmIds]){
            rsmMap.put(u.RSM__c, u.Id);
        }
        //add admin to list     
        User adm = [select id from User where RSM__c = :dfltRegSlsMgr];
        rsmMap.put(dfltRegSlsMgr, adm.Id);
        return rsmMap;
    }
    private class AccountHelperException extends Exception{}
}