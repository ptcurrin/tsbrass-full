@isTest
public class AssignAccountOwnerBatchTest {
    
	 @isTest static void testAssignOwnerByRSMId(){
         
        //insert rep agency account      
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                
         
        Account a = new Account();
        a.Name = 'Test Prospect';
        a.SalesTeamId__c='Test';
        a.SLSMan_Rep_Agency__c=a1.Id;
        a.Type='Architect'; 
        insert a;            
        
        AccountHistory acctHistory1 = new AccountHistory
        (Field='RSM__c',
		AccountId=a.Id         
        );
        insert acctHistory1;
        
        Id currentUserId = UserInfo.getUserid();
        User u = [select Id, RSM__c from User where RSM__c != null and Id != :currentUserId limit 1];
        
        system.debug('u.RSM__c: ' + u.RSM__c);
        a = [select RSM__c from Account where Id = :a.Id];
        a.RSM__c = u.RSM__c;        
        update a;
        
        AccountHistory acctHistory2 = new AccountHistory
        (Field='RSM__c',
		AccountId=a.Id           
        );
        insert acctHistory2;
        
        Test.startTest();
        AssignAccountOwnerBatch aao = new AssignAccountOwnerBatch();
        Id batchId = Database.executeBatch(aao);
        Test.stopTest();
               
        Integer acctHistCnt = [Select Count() From AccountHistory];
        system.debug('Acct History Count: ' + acctHistCnt);
        
        Account acctFinal = [Select OwnerId, Owner.Name From Account Where id=:a.id];       
        system.debug('Account Final: ' + acctFinal);
        //verify that the Account owner was changed
        system.assert(acctFinal.OwnerId!=currentUserId);       
    }   
    
    @isTest static void testAssignAll(){
             
        // 2023-10-19 PTC - I saw earlier today that the current validation rules for accounts say that only 
        // Admins and Syteline Users can change account ownership. That means we need to get one or the other 
        // for this test, not just some random user.
        
        
        Id currentUserId = UserInfo.getUserid();
        User u = [select Id, RSM__c from User where RSM__c != null and Id != :currentUserId limit 1];
        system.debug('Non Integration User: ' + u);
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12344';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                
        
        Account a = new Account();
        a.Name = 'Test Prospect';
        a.SalesTeamId__c='Test'; 
        a.External_Id__c='12345';
        a.RSM__c = u.RSM__c;     
        a.SLSMan_Rep_Agency__c=a1.Id;
        a.Type='Architect'; 
        insert a;        
        
        Test.startTest();
        AssignAccountOwnerBatch aao = new AssignAccountOwnerBatch(datetime.newInstance(2000, 1,1));
        Id batchId = Database.executeBatch(aao);
        Test.stopTest();
                          
        Account acctFinal = [Select OwnerId, Owner.Name From Account Where Id=:a.id];       
        system.debug('Account Final: ' + acctFinal);
        //verify that the Account owner was changed
        system.assert(acctFinal.OwnerId==u.Id);       

    }
     @isTest static void testJobLevelError(){
        Id currentUserId = UserInfo.getUserid();
        User u = [select Id, RSM__c from User where RSM__c != null and Id != :currentUserId limit 1];
        system.debug('Non Integration User: ' + u);
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12344';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                
        
        Account a = new Account();
        a.Name = 'Test Prospect';
        a.SalesTeamId__c='Test'; 
        a.External_Id__c='12345';
        a.RSM__c = u.RSM__c;     
        a.SLSMan_Rep_Agency__c=a1.Id;
        a.Type='Architect'; 
        insert a;        
        Test.startTest();
        AssignAccountOwnerBatch aao = new AssignAccountOwnerBatch();
        aao.isJobLevelErrorTest=true;
        Id batchId = Database.executeBatch(aao);
        Test.stopTest();
     }
}