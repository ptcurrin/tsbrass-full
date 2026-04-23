@isTest
public class AssignAccountOwnerTest {
	
    @isTest static void testAssignOwnerBySalesTeamId(){
        Account a = new Account();
        a.Name = 'Test Prospect';
        a.SalesTeamId__c='Test';
        insert a;
        
        AccountHistory acctHistory1 = new AccountHistory
        (Field='SalesTeamId__c',
		AccountId=a.Id         
        );
        insert acctHistory1;
        
        Id currentUserId = UserInfo.getUserid();
        User u = [select Id, Sales_Team_id__c from User where Sales_Team_Id__c != null and Id != :currentUserId limit 1];
        
        system.debug('u.Sales_Team_Id__c: ' + u.Sales_Team_Id__c);
        a = [select SalesTeamId__c from Account where Id = :a.Id];
        a.SalesTeamId__c = u.Sales_Team_Id__c;        
        update a;
        
        AccountHistory acctHistory2 = new AccountHistory
        (Field='SalesTeamId__c',
		AccountId=a.Id          
        );
        insert acctHistory2;
        
        Test.startTest();
        AssignAccountOwner aao = new AssignAccountOwner();
        Id batchId = Database.executeBatch(aao);
        Test.stopTest();
        
        //List<AccountHistory> acctHistory = [Select ]
        Integer acctHistCnt = [Select Count() From AccountHistory];
        system.debug('Acct History Count: ' + acctHistCnt);
        
        Account acctFinal = [Select OwnerId, Owner.Name From Account][0];       
        system.debug('Account Final: ' + acctFinal);
        //verify that the Account owner was changed
        //system.assertEquals(10, [Select count() from Account Where OwnerId=:t.Territory_Rep__c]);
        system.assert(acctFinal.OwnerId!=currentUserId);       
    }   
}