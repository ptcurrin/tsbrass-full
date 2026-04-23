@isTest
public class AccountContactRelationTriggerHandlerTest {
    
    /*
* Written by Patrick Currin
* Belkbot Solutions, LLC 
* March 2024
* 
* This test class tests a few GETS for record type Id and profiles by instantiating itself and 
* calling the appropriate method. 
* 
* There is often a user (Syteline Integration User  =-) who CAN do things with the objects
* and a disallowed user, who is a System Administrator clone, for now, but more profiles can easily
* be granted the ability to make changes. 
* 
* To add allowed profiles, create another method that get's another profile and add it to the profile SET
* in the AccountContactRelationTriggerHandler.apxc class   
*/ 
    
    static testmethod void returnRepAgencyRecordTypeId(){
        
        string retstr = new AccountContactRelationTriggerHandler().getRepAgencyAccountRecordTypeId();
        system.assert(null != retstr);
        system.debug('AccountContactRelationTriggerHandlerTest.returnRepAgencyRecordTypeId() --> ' + retstr);
        
    }
    
    static testmethod void returnSytelineIntegrationProfileId(){
        
        Set<Id> retSet = new AccountContactRelationTriggerHandler().getSytelineIntegrationProfileIdSet();
        system.assert(!retset.isEmpty());
        system.debug('AccountContactRelationTriggerHandlerTest.getSytelineIntegrationProfileId() --> ' + retSet);
        
    }
    
    static testmethod void try_INSERT_ExtraRepAgencyContactACR_asNonAllowedProfile(){
        
        Profile siProfile = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User siUser = new User(Alias = 'standt', Email='syteline_user@testorg.com', 
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                               LocaleSidKey='en_US', ProfileId = siProfile.Id, 
                               TimeZoneSidKey='America/Los_Angeles', UserName='sytelinexuserx@testorg.com');
        
        Profile p = [SELECT Id FROM Profile WHERE Name='T&S Brass - System Administrator']; 
        User u = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, 
                          TimeZoneSidKey='America/Los_Angeles', UserName='adminxuserx@testorg.com');
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        
        system.runas(siUser){
            
            
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1;                  
            
            //insert prospect
            
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            
            // these contacts will begin with account a2 as the direct relation, but owned by the integration user
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
            insert(c1);
            
        }
        
        Test.startTest();
        
        System.runAs(u) {
            
            AccountContactRelation acr = new AccountContactRelation();
            acr.ContactId = c1.Id;
            acr.AccountId = a2.Id;
            acr.isActive = true;
            
            try{
                
                insert(acr);
                system.assert(false);
                
            }catch(Exception ex){
                system.assert(true);
            }
        }
        
        Test.stopTest();
        
        
    }
    
    
    static testmethod void try_INSERT_ExtraRepAgencyContactACR_asAllowedProfile(){
        
        Profile siProfile = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User siUser = new User(Alias = 'standt', Email='syteline_user@testorg.com', 
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                               LocaleSidKey='en_US', ProfileId = siProfile.Id, 
                               TimeZoneSidKey='America/Los_Angeles', UserName='sytelinexuserx@testorg.com');
        
        
        Profile p = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User u = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, 
                          TimeZoneSidKey='America/Los_Angeles', UserName='adminxuserx@testorg.com');
        
        
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        
        system.runas(siUser){
            
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1;                  
            
            //insert prospect
            
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            
            // these contacts will begin with account a2 as the direct relation, but owned by the integration user
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
            insert(c1);
            
        }
        
        Test.startTest();
        
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = c1.Id;
        acr.AccountId = a2.Id;
        acr.isActive = true;
        
        System.runAs(u) {
            
            try{
                
                insert(acr);
                system.assert(true);
                
            }catch(Exception ex){
                system.assert(false);
            }
            
        }
        
        Test.stopTest();
        
        
        AccountContactRelation acrTestResult = [SELECT Id, AccountId, ContactId FROM AccountContactRelation WHERE Id = :acr.Id LIMIT 1];
        system.assertEquals(acrTestResult.Id, acr.Id);
        
        List<AccountContactRelation> acrTestResults = [SELECT Id FROM AccountContactRelation];
		system.assertEquals(2, acrTestResults.size());
        
    }
    
    
    static testmethod void try_INSERT_ESTORE_ACR_asAllowedProfile(){
        
        Profile p = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User u = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, 
                          TimeZoneSidKey='America/Los_Angeles', UserName='adminxuserx@testorg.com');
        
        
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Test.startTest();
        
        
        
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        AccountContactRelation acr = new AccountContactRelation();
        
        
        System.runAs(u) {
            
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1;                  
            
            //insert prospect
            
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            
            // these contacts will begin with account a2 as the direct relation, but owned by the integration user
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
            c1.E_Store__c = true;
            insert(c1);
            
            
            
            acr.ContactId = c1.Id;
            acr.AccountId = a2.Id;
            acr.isActive = true;
            
            
            try{
                
                insert(acr);
                system.assert(true);
                
            }catch(Exception ex){
                system.assert(false);
            }
            
        }
        
        Test.stopTest();
        
        
        AccountContactRelation acrTestResult = [SELECT Id, AccountId, ContactId FROM AccountContactRelation WHERE Id = :acr.Id LIMIT 1];

        system.assertEquals(acrTestResult.Id, acr.Id);
        
    }
    
    
    
    static testmethod void try_INSERT_ESTORE_ACR_asNonAllowedProfile(){
        
        // This should fail softly by adding an error related to the EStore
        
        Profile siProfile = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User siUser = new User(Alias = 'standt', Email='syteline_user@testorg.com', 
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                               LocaleSidKey='en_US', ProfileId = siProfile.Id, 
                               TimeZoneSidKey='America/Los_Angeles', UserName='sytelinexuserx@testorg.com');
        
        
        Profile profileNOTAllowed = [SELECT Id FROM Profile WHERE Name='T&S Brass - System Administrator']; 
        User userNOTAllowed = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                                       EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                                       LocaleSidKey='en_US', ProfileId = profileNOTAllowed.Id, 
                                       TimeZoneSidKey='America/Los_Angeles', UserName='adminexuserx@testorg.com');
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        
        System.runas(siUser){
            
            // REP AGENCY is required for the SalesRep Id of the next account created...
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1; 
            
            // ACCOUNT WE ARE ADDING AN ACR FOR THE CONTACT 
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a2.Id; 
            c1.E_Store__c = true; // HERE WE GO. E STORE USER. <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            
            
        }
        
        
        Test.startTest();
        
        System.runAs(userNOTAllowed) {
            
            try{
                
                insert(c1);
                system.assert(false);
                
            }catch(Exception ex){
                system.assert(true);
            }
        }
        
        Test.stopTest();
        
        
        Contact cTest;
        try{            
            cTest = [SELECT Id FROM Contact WHERE Id = :c1.Id LIMIT 1];
        }catch(QueryException qex){
            
        }
        system.assert(cTest == null );
        
    }
    
    
    
    
    
    static testmethod void try_UPDATE_ESTORE_ACR_asNonAllowedProfile(){
        
        Profile profileAllowed = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User userAllowed = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                                    EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                                    LocaleSidKey='en_US', ProfileId = profileAllowed.Id, 
                                    TimeZoneSidKey='America/Los_Angeles', UserName='adminxuserx@testorg.com');
        
        
        
        
        Profile profileNOTAllowed = [SELECT Id FROM Profile WHERE Name='T&S Brass - System Administrator']; 
        User userNOTAllowed = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                                       EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                                       LocaleSidKey='en_US', ProfileId = profileNOTAllowed.Id, 
                                       TimeZoneSidKey='America/Los_Angeles', UserName='sytelinexuserx@testorg.com');
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        
        System.runas(userAllowed){
            
            // REP AGENCY
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1;                  
            
            // ACCOUNT WE ARE ADDING AN ACR FOR THE CONTACT 
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a2.Id; 
            c1.E_Store__c = true; // HERE WE GO. E STORE USER. <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            insert(c1);
            
        }
        
        
        Test.startTest();
        
        System.runAs(userNOTAllowed) {
            
            c1.AccountId = a1.Id;
            
            
            try{
                
                update(c1);
                system.assert(false);
                
            }catch(Exception ex){
                
                system.debug('$$$ A proper exception was thrown: ' + ex.getMessage());
                
                system.assert(true);
            }
        }
        
        Test.stopTest();
        
        Contact cTest = [SELECT Id, AccountId FROM Contact WHERE Id = :c1.Id];
        system.debug('cTest: ' + cTest);
        system.debug('a2.Id: ' + a2.Id + ' <<<< UPDATE FROM ');
        system.debug('a1.Id: ' + a1.Id + ' <<<< UPDATED TO ');
        system.assertEquals(cTest.AccountId, a2.Id);
        
        
        AccountContactRelation testACR;
        try{
            testACR = [SELECT Id, ContactId, AccountId FROM AccountContactRelation 
                       WHERE AccountId = :c1.AccountId
                       AND ContactId = :c1.Id];
        }catch(QueryException qex){
            
        }
        
        system.debug('testACR: ' + testACR);
        system.assert(testACR == null);
        
        
    }
    
    
    
    
    static testmethod void try_DELETE_ESTORE_ACR_asNonAllowedProfile(){
        
        Profile profileAllowed = [SELECT Id FROM Profile WHERE Name='T&S Brass - Syteline Integration']; 
        User userAllowed = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                                    EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                                    LocaleSidKey='en_US', ProfileId = profileAllowed.Id, 
                                    TimeZoneSidKey='America/Los_Angeles', UserName='adminxuserx@testorg.com');
        
        
        
        
        Profile profileNOTAllowed = [SELECT Id FROM Profile WHERE Name='T&S Brass - System Administrator']; 
        User userNOTAllowed = new User(Alias = 'standt', Email='adminuser@testorg.com', 
                                       EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                                       LocaleSidKey='en_US', ProfileId = profileNOTAllowed.Id, 
                                       TimeZoneSidKey='America/Los_Angeles', UserName='sytelinexuserx@testorg.com');
        
        
        List<AccountContactRelation> acrsBefore = new List<AccountContactRelation>();
        List<AccountContactRelation> acrsAfterOneContact = new List<AccountContactRelation>();
        
        try{
            acrsBefore = [SELECT Id FROM AccountContactRelation];
            
        }catch(QueryException qex){
            
        }
        
        system.assert(acrsBefore.size() == 0);
        
        Account a1 = new Account();
        Account a2 = new Account();
        Contact c1 = new Contact();
        AccountContactRelation extraACR = new AccountContactRelation();
        System.runas(userAllowed){
            
            // REP AGENCY
            a1.Name = 'RepAgencyAccount';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
            insert a1;                  
            
            a2.Name = 'ProspectAccount';
            a2.RSM__c='SMA00900';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            insert a2;    
            
            c1.Title = 'Architect';
            c1.LastName = 'Belk';
            c1.FirstName = 'Mark';
            c1.Email = 'gmark@belkbot.com';
            c1.Phone = '9999999999';
            c1.OtherPhone = '9999999999';
            c1.AccountId = a2.Id; 
            c1.E_Store__c = true; // HERE WE GO. E STORE USER. <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            insert(c1);
            
            extraACR.AccountId = a1.Id; //. <<<<<<<<<<<<<<<<< We need an extra ACR to delete later. The allowed user adds it.
            extraACR.ContactId = c1.Id;
            insert(extraACR);
            
        }
        
        
        Test.startTest();
        
        System.runAs(userNOTAllowed) {
            
            
            try{
                
                delete(extraACR);
                system.assert(false);
                
            }catch(Exception ex){
                
                system.debug('$$$ A proper exception was thrown: ' + ex.getMessage());
                
                system.assert(true);
            }
        }
        
        Test.stopTest();
        
        
        AccountContactRelation testACR;
        try{
            testACR = [SELECT Id, ContactId, AccountId FROM AccountContactRelation 
                       WHERE AccountId = :a1.Id
                       AND ContactId = :c1.Id];
        }catch(QueryException qex){
            
        }
        
        system.debug('testACR: ' + testACR);
        system.assert(testACR != null);
        

        
    }
    
    
}