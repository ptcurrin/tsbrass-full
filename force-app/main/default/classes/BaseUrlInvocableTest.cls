@isTest
public class BaseUrlInvocableTest {

    static testmethod void call_BaseUrlInvocable(){
        
        List<Id> ids = new List<Id>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;   
        
        ids.add(a1.Id);
        
        BaseUrlInvocable.getBaseOrgUrl(ids);
        
        
    }
    
}