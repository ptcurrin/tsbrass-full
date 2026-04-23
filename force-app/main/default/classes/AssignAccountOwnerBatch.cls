global class AssignAccountOwnerBatch implements Schedulable,Database.Batchable<sObject>{
	 private DateTime targetDate;  
     private static Boolean isJobLevelError=false;
     @TestVisible private Boolean isJobLevelErrorTest=false;
     private static List<Database.SaveResult> results=new List<Database.SaveResult>();
    
    public AssignAccountOwnerBatch(){ 
        //targetDate=DateTime.Now().addDays(-1);
        targetDate=DateTime.Now().addHours(-3);
        system.debug('targetDate: ' + targetDate);
    }
    
     public AssignAccountOwnerBatch(DateTime targetDate){ 
        this.targetDate=targetDate;
    }
   
     global void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }
    
	global Database.QueryLocator start(Database.BatchableContext bc) {          
        string targetDateString=targetDate.formatGMT('yyyy-MM-dd\'T\'hh:mm:ss\'Z\'');   
        //get integration user id
        Id integrationUserId = [Select Id From User Where Name = 'Integration User' And IsActive=true].Id;       
        if(integrationUserId==null){return null;}      
        // collect the batches of records or objects to be passed to execute  
            string query='SELECT ID, RSM__c FROM Account' + 
                ' Where LastModifiedById = \'' + integrationUserId + '\'' 
                +
                ' And LastModifiedDate >= ' + targetDateString + ''
                //' AND RecordType.Name = \'Klarco\''
                
                ;
         system.debug('query: ' + query);
         system.debug('Accounts to process: ' + Database.query(query));   
        return Database.getQueryLocator(query); 
    }
    
    global void execute(Database.BatchableContext bc, List<Account> records){
        try{
        // process each batch of records
        system.debug('records: ' +records); 
        AccountHelper helper = new AccountHelper(records);
        results=helper.assignAccountOwner();
            if(Test.isRunningTest() && isJobLevelErrorTest){
                throw new AssignAccountOwnerBatchException('Test Job Level Exception');
            }   
        
        }
        catch(Exception ex){
            isJobLevelError=true;
             Integration_Log__c log = new Integration_Log__c(
                            Error_Code__c = ex.getTypeName(),
                            Description__c = ex.getStackTraceString(),                        
                            Object_Name__c = 'Account',
                 			Name = 'Assign Account Owner Batch Job Level Error: Job Id-' + bc.getJobId()
                 );
                 insert log;
		}
        
    }    
    global void finish(Database.BatchableContext bc){
        // execute any post-processing operations
        if(!isJobLevelError){
            if(!results.isEmpty()){
            	logErrors(results);
            }
        }
    }    
    
     private void logErrors(List<Database.SaveResult> results){
        List<Integration_Log__c> logList = new List<Integration_Log__c>();     
            for (Database.SaveResult r : results) {
                System.debug(r + '  ===> r');
                if (!r.isSuccess()) {
                    Integration_Log__c log = new Integration_Log__c(
                            Error_Code__c = 'Update Error',
                            Description__c = (r.getErrors() != null) ? String.valueOf(r.getErrors()) : '',
                            Name =  'Assign Account Owner Batch Record Update Error-' +  r.getID(),
                            Record_ID__c = r.getID(),
                            Object_Name__c = 'Account'
                    );
                    logList.add(log);                   
            	}
            }
        if(logList.size() > 0) insert logList;
   }
    
    
    private class AssignAccountOwnerBatchException extends Exception{}
}