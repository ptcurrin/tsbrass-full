@isTest
public class EventTriggerDeactivate {

    static testmethod void touch(){
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id;
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'TEST DESCRIPTION';
        
        Database.SaveResult sr = Database.insert(e);
        
        
    }
    
}