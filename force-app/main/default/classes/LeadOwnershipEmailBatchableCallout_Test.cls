@isTest(seeAllData=true)
public class LeadOwnershipEmailBatchableCallout_Test {

    static testmethod void touch(){

        
        Lead l = new Lead();
        l.Company = 'TestCompany';
        l.LastName = 'TestLastname';
        l.Ownership_Change_Email_SEND_TONIGHT__c = true;
        insert(l);
        
        Lead beforeLead = [SELECT Id, Ownership_Change_Email_SEND_TONIGHT__c FROM Lead WHERE Id = :l.Id];
        system.assertEquals(beforeLead.Ownership_Change_Email_SEND_TONIGHT__c, true);
        
        Test.startTest();
        
        Database.executeBatch(new LeadOwnershipEmailBatchableCallout(), 1);
        
        Test.stopTest();
        
        Lead result = [SELECT Id, Ownership_Change_Email_SEND_TONIGHT__c FROM Lead WHERE Id = :l.Id];
        system.assertEquals(result.Ownership_Change_Email_SEND_TONIGHT__c, false);
        
    }
    
}