global class AssignAccountOwner implements Schedulable,Database.Batchable<sObject>{

    private DateTime targetDate=DateTime.Now().addDays(-1);
    private Boolean reassignAll = false;
    private String query = '';
    private static string dfltSalesTeamId='';
    
    public AssignAccountOwner(){
         dfltSalesTeamId=getDefaultSalesTeamId();
    }
    
    public AssignAccountOwner(DateTime targetDate, Boolean reassignAll){
        this.targetDate=targetDate;
        this.reassignAll = reassignAll;
        dfltSalesTeamId=getDefaultSalesTeamId();
    }
    
    public AssignAccountOwner(String query, Boolean reassignAll){
        this.query=query;
        this.reassignAll = reassignAll;
    }
    
     global void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }
    
	global Database.QueryLocator start(Database.BatchableContext bc) {
        string targetDateString = '';
        if(targetDate==null){       
        targetDateString = DateTime.Now().addDays(-1).format('yyyy-MM-dd\'T\'hh:mm:ss\'Z\'');
         } 
        else{
            targetDateString=targetDate.format('yyyy-MM-dd\'T\'hh:mm:ss\'Z\'');
        }
        //get integration user id
        Id integrationUserId = [Select Id From User Where Name = 'Integration User'].Id;
        
        if(integrationUserId==null){return null;}
        
        // collect the batches of records or objects to be passed to execute
        if(query==''){
            return Database.getQueryLocator(
               'SELECT ID, SalesTeamId__c FROM Account' + 
                ' Where LastModifiedById = \'' + integrationUserId + '\'' +
                ' And LastModifiedDate >= ' + targetDateString + ''
            );
        }
        else {return Database.getQueryLocator(query);}
    }
    
    global void execute(Database.BatchableContext bc, List<Account> records){
        // process each batch of records
        system.debug('records: ' +records);
       if(reassignAll){assignAccountOwner(records);}
        else{
            List<Account> updatedAccts = checkIfSalesTeamChanged(records);
            if(!updatedAccts.IsEmpty()){
               assignAccountOwner(updatedAccts);
            }
        }
    }    
    global void finish(Database.BatchableContext bc){
        // execute any post-processing operations
    }    
    
 private void assignAccountOwner(List<Account> accts){
         Set<string> salesTeamIds = new Set<string>();
         for(Account a: accts){
             salesTeamIds.add(a.SalesTeamId__c);                                           
         }
     system.debug('Sales Team Ids: ' + salesTeamIds);
          if(!salesTeamIds.isEmpty()){            
            Map<string, string> userMap = AccountTriggerHandler.getUsersBySalesTeam(salesTeamIds);
            for(Account a : accts){
                system.debug('Sales Team Id: ' + a.SalesTeamId__c);
                if(salesTeamIds.contains(a.SalesTeamId__c)){
                    if(a.SalesTeamId__c == null){
                        system.debug('sales team Id is null');
                        //sales team was nulled out -- assign to admin
                        //a.OwnerId = userMap.get('PB');
                        a.OwnerId=userMap.get(dfltSalesTeamId);
                    }
                    else{
                        system.debug('sales team Id is not null: ' + a.SalesTeamId__c);
                        //get user id                        
                        string uid = userMap.get(a.SalesTeamId__c);
                        if(uid != null){
                            a.OwnerId = uid;
                        }
                        else{//if no match is found in the user table assign to admin user
                            system.debug('no matching user found, assigning to admin user');
                            //a.OwnerId = userMap.get('PB');
                            a.OwnerId = userMap.get(dfltSalesTeamId);
                        }
                    }                                       
                }
			}
           update accts;
		}           
    }
    
    private List<Account> checkIfSalesTeamChanged(List<Account> accts){ 
        //check to see which Accounts had a change to the Sales Team Id field
        List<Account> updatedAccts = new List<Account>();
        for(AccountHistory ac : [Select AccountId From AccountHistory
                        Where Field = 'SalesTeamId__c'
                        And AccountId IN : accts
                        AND CreatedDate >= :targetDate
                         ]){
                             for(Account a:accts){
                                 if(ac.AccountId==a.Id && !updatedAccts.contains(a)){
                             		updatedAccts.add(a);
                                 }
                             }
                         }
        return updatedAccts;
    }        
    
    private static string getDefaultSalesTeamId(){
        String slsTeamId = [Select Sales_Team_Id__c FROM Syteline_Integration_Setting__mdt
                    Where DeveloperName  = 'Default_Account_Owner'].Sales_Team_Id__c;
        if(slsTeamId==''){throw new ApplicationException('Default Account Owner cannot be blank in Syteline_Integration_Setting__mdt');}
        return slsTeamId;
    }
    
    private class ApplicationException extends Exception{}
    
}