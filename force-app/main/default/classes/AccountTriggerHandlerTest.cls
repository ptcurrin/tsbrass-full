@isTest
public class AccountTriggerHandlerTest {
    
    
    @isTest static void testAccountDelete(){
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

            test.startTest();
            delete a2;
            test.stopTest();
    }
    
    @isTest static void testUpdateAcctOwnerByNonIntegrationUser(){
        
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
        
        Id currentUserId = UserInfo.getUserid();
        User u = [select Id, RSM__c from User where RSM__c != null and Id != :currentUserId limit 1];             
        a2.OwnerId=u.Id;
        system.runAs(u){update a2;}        
        system.assertEquals(u.Id, [Select OwnerId From Account Where Id=:a2.id].OwnerId);         
    }
    
      
    @isTest static void testSetAcctOwnerByNonIntegrationUser(){
               
         //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  

		//get a non integration user for testing
		User u = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' limit 1]; 
              
		 //insert prospect under the non-integration user
        Account a2 = new Account();
        a2.Name = 'Test Prospect';       
        a2.RSM__c=u.RSM__c;
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        system.runAs(u){insert a2;}        
         
        system.assertEquals(u.Id, [Select OwnerId From Account Where Id=:a2.id].OwnerId);            
    }
    

    // PTC 2022-09
    static testmethod void affirmative_ContactOwnerChanges(){
        
        List<Account> acctsToUpdate = new List<Account>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;     
        
        // The integration user will not always be running unit tests, but lets get him for the effect
        // the difference will have...
        User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
        
        //get a non integration user for testing
        User notIntegrationUser = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' limit 1]; 
        
        //insert prospect under the non-integration user
        Account a2 = new Account();
        a2.Name = 'Test Prospect';       
        a2.RSM__c=notIntegrationUser.RSM__c;
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        // so the account (a2) will be owned by a non-integration user
        system.runAs(notIntegrationUser){insert a2;}        
        
        // these contacts will begin with account a2 as the direct relation, but owned by the integration user
        Contact c1 = new Contact();
        c1.Title = 'Commadore';
        c1.LastName = 'IntegrationUser';
        c1.FirstName = 'Contact';
        c1.Email = 'c1Email@test.com';
        c1.Phone = '9995556667';
        c1.OtherPhone = '9995556666';
        c1.AccountId = a2.Id; // aimed at NOT integration-user-owned account 
        c1.ownerId = integrationUser.Id; // aimed at Integration User
        insert(c1);
        
        Contact c2 = new Contact();
        c2.Title = 'Commadore';
        c2.LastName = 'IntegrationUser';
        c2.FirstName = 'Contact';
        c2.Email = 'c2Email@test.com';
        c2.Phone = '9995556667';
        c2.OtherPhone = '9995556666';
        c2.AccountId = a2.Id; // aimed at NOT integration-user-owned account
        c2.OwnerId = integrationUser.Id; // aimed at Integration User
        insert(c2);   
        
        Test.startTest();
        
        Account testAcct = [SELECT Id, OwnerId FROM Account WHERE Id = :a2.Id];
        testAcct.OwnerId = integrationUser.Id;
        update(testAcct);
        
        Test.stopTest();
        
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Account Where Id=:a2.id].OwnerId);
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Contact Where Id=:c1.id].OwnerId);
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Contact Where Id=:c2.id].OwnerId);
        
    }
    
    
    // PTC 2022-09
    
    static testmethod void negative_ContactOwnerChanges(){
       
        // a1 = Running User (Most of the time, Integration User)
        // a2 = NOT Integration User
        // 
        
        // The integration user will not always be running unit tests, but lets get him for the effect
        // the difference will have...
        User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
        
        //get a non integration user for testing
        User notIntegrationUser = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' AND Profile.Name = 'T&S Brass - System Administrator' limit 1]; 
        
        
        //system.assertEquals(null, AccountTriggerHandler.counterAfter);
        
        List<Account> acctsToUpdate = new List<Account>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        system.runas(integrationUser){insert a1;}     
        
        //system.assertEquals(1, AccountTriggerHandler.counterAfter);
        
        
        //insert prospect under the non-integration user
        Account a2 = new Account();
        a2.Name = 'Test Prospect';       
        a2.RSM__c=notIntegrationUser.RSM__c;
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        // so the account (a2) will be owned by a non-integration user
        system.runAs(notIntegrationUser){insert a2;}        
        
        //system.assertEquals(2, AccountTriggerHandler.counterAfter);
        
        // these contacts will begin with account a2 as the direct relation, but owned by the integration user
        Contact c1 = new Contact();
        c1.Title = 'Commadore';
        c1.LastName = 'IntegrationUser';
        c1.FirstName = 'Contact';
        c1.Email = 'c1Email@test.com';
        c1.Phone = '9995556667';
        c1.OtherPhone = '9995556666';
        c1.AccountId = a2.Id; // aimed at NOT integration-user-owned account 
        c1.ownerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c1);}
        
        Contact c2 = new Contact();
        c2.Title = 'Commadore';
        c2.LastName = 'IntegrationUser';
        c2.FirstName = 'Contact';
        c2.Email = 'c2Email@test.com';
        c2.Phone = '9995556667';
        c2.OtherPhone = '9995556666';
        c2.AccountId = a2.Id; // aimed at NOT integration-user-owned account
        c2.OwnerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c2);} 
        
        Test.startTest();
        
        a2 = [SELECT Id, OwnerId FROM Account WHERE Id = :a2.Id];
        a2.OwnerId = integrationUser.Id;
        // 2023-10-11 Changing this user to integration user to bypass the validation rule, which allows no User other than the Integration User to change ownership of contacts
        system.runAs(notintegrationUser){update(a2);} // resaving a2 should make it go get all of its related contacts and change ownership of them
        //system.assertEquals(3, AccountTriggerHandler.counterAfter);
        
        //insert prospect 2 under the non-integration user
        Account a3 = new Account();
        a3.OwnerId = notintegrationUser.Id;
        a3.Name = 'Test Prospect 2';       
        a3.RSM__c=notIntegrationUser.RSM__c;
        a3.External_Id__c='12347';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        // so the account (a2) will be owned by runner or integration user
        system.runas(integrationUser){insert a3;} 
        
        //system.assertEquals(4, AccountTriggerHandler.counterAfter);
        
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = c2.Id;
        acr.AccountId = a3.Id;
        //acr.IsDirect = false; // this should turn up indirect when queried
        acr.IsActive = true;
        system.runas(integrationUser){insert(acr);}
        
        // The third account is saved again, which should activate the account trigger
        a3.Name = 'Test Prospect Resaved';
        system.runas(integrationUser){update(a3);}
        
        //system.assertEquals(5, AccountTriggerHandler.counterAfter);
        
        
        Test.stopTest();
        
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Account Where Id=:a2.id].OwnerId);
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Contact Where Id=:c1.id].OwnerId);
        
        // "c2" was originally related, directly, to "a2", but then, in order to demostrate ownership correctly remaining,
        // was added as an AccountContactRelation on a different, new account("a3") and that account was saved again.
        // Since the account was resaved, the handler ran, and the owner remains IntegrationUser, because the contact
        // is directly related to "a2", which is owned by the IntegrationUser, not the system doing the unit test.
        system.assertEquals(IntegrationUser.Id, [Select OwnerId From Contact Where Id=:c2.id].OwnerId);
          
        AccountContactRelation acrTestResult = [SELECT Id, 
                                                ContactId, 
                                                Contact.OwnerId,
                                                AccountId, 
                                                Account.OwnerId,
                                                IsDirect 
                                                FROM AccountContactRelation 
                                                WHERE Id = :acr.Id];
        
        system.debug('acrTestResult: ' + acrTestResult);
        system.assertEquals(false, acrTestResult.IsDirect);
        system.assertEquals(c2.Id, acrTestResult.ContactId);
        system.assertEquals(integrationUser.Id, acrTestResult.Contact.OwnerId);
        system.assertEquals(notintegrationuser.Id, acrTestResult.Account.OwnerId);
    }
    
    static testmethod void positive_ContactOwnerChanges_2(){
       
        User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
        
        //get a non integration user for testing
        User notIntegrationUser = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' limit 1]; 
        
        List<Account> acctsToUpdate = new List<Account>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        system.runas(integrationUser){insert a1;}  
        a1 = [SELECT Id, OwnerId FROM Account WHERE Id = :a1.Id];
        system.assertEquals(integrationuser.Id, a1.OwnerId); // confirm owner
        
        // There is an account, owned by the integration user. 
        // We will change ownership to see who owns the contacts afterward
		
        Contact c1 = new Contact();
        c1.Title = 'Commadore';
        c1.LastName = 'IntegrationUser';
        c1.FirstName = 'Contact';
        c1.Email = 'c1Email@test.com';
        c1.Phone = '9995556667';
        c1.OtherPhone = '9995556666';
        c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
        c1.ownerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c1);}
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        system.assertEquals(integrationuser.Id, c1.OwnerId); // confirm owner, related to a1
        
        Contact c2 = new Contact();
        c2.Title = 'Commadore';
        c2.LastName = 'IntegrationUser';
        c2.FirstName = 'Contact';
        c2.Email = 'c2Email@test.com';
        c2.Phone = '9995556667';
        c2.OtherPhone = '9995556666';
        c2.AccountId = a1.Id; // aimed at NOT integration-user-owned account
        c2.OwnerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c2);} 
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(integrationuser.Id, c2.OwnerId); // confirm owner, related to a1
        
		// Now, we must change the account owner to NON-integration user and see who owns the contacts
        Test.startTest();
        
        a1.OwnerId = notIntegrationUser.Id;
        update(a1);
        
        Test.stopTest();
        
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(notintegrationuser.Id, c1.OwnerId); // confirm owner
        system.assertEquals(notintegrationuser.Id, c2.OwnerId); // confirm owner
    }
    
    static testmethod void negative_ContactOwnerChanges_2(){
       
        User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
        
        //get a non integration user for testing
        User notIntegrationUser = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' limit 1]; 
        
        List<Account> acctsToUpdate = new List<Account>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        system.runas(integrationUser){insert a1;}  
        a1 = [SELECT Id, OwnerId FROM Account WHERE Id = :a1.Id];
        system.assertEquals(integrationuser.Id, a1.OwnerId); // confirm owner
        
        // There is an account, owned by the integration user. 
        // We will change ownership to see who owns the contacts afterward
		
        Contact c1 = new Contact();
        c1.Title = 'Commadore';
        c1.LastName = 'IntegrationUser';
        c1.FirstName = 'Contact';
        c1.Email = 'c1Email@test.com';
        c1.Phone = '9995556667';
        c1.OtherPhone = '9995556666';
        c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
        c1.ownerId = notintegrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c1);}
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        system.assertEquals(integrationuser.Id, c1.OwnerId); // confirm owner, related to a1
        
        Contact c2 = new Contact();
        c2.Title = 'Commadore';
        c2.LastName = 'IntegrationUser';
        c2.FirstName = 'Contact';
        c2.Email = 'c2Email@test.com';
        c2.Phone = '9995556667';
        c2.OtherPhone = '9995556666';
        c2.AccountId = a1.Id; // aimed at NOT integration-user-owned account
        c2.OwnerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c2);} 
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(integrationuser.Id, c2.OwnerId); // confirm owner, related to a1
        
        //insert prospect under the non-integration user
        Account a2 = new Account();
        a2.Name = 'Test Prospect';       
        a2.RSM__c=notIntegrationUser.RSM__c;
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        // so the account (a2) will be owned by a non-integration user
        system.runAs(notIntegrationUser){insert a2;}        
        
		// Now, we must change the account owner of the NONintegration user. The code should pick up no contacts.
		// We will take a look after it's over
        Test.startTest();
        
        a2.OwnerId = notintegrationUser.Id;
        update(a2);
        
        Test.stopTest();
        
        a2 = [SELECT Id, OwnerId FROM Account WHERE Id = :a2.Id];
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(notintegrationuser.id, a2.ownerid); // confirm owner
        system.assertEquals(integrationuser.Id, c1.OwnerId); // confirm owner
        system.assertEquals(integrationuser.Id, c2.OwnerId); // confirm owner
    }
    
    static testmethod void differentAccountsUpdatedSameTime_ContactOwnerChanges(){
       
        User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
        
        //get a non integration user for testing
        User notIntegrationUser = [select Id, RSM__c from User where RSM__c != null and User.Name!='Integration User' limit 1]; 
        
        List<Account> acctsToUpdate = new List<Account>();
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        system.runas(integrationUser){insert a1;}  
        a1 = [SELECT Id, OwnerId FROM Account WHERE Id = :a1.Id];
        system.assertEquals(integrationuser.Id, a1.OwnerId); // confirm owner
        
        // There is an account, owned by the integration user. 
        // We will change ownership to see who owns the contacts afterward
		
        Contact c1 = new Contact();
        c1.Title = 'Commadore';
        c1.LastName = 'IntegrationUser';
        c1.FirstName = 'Contact';
        c1.Email = 'c1Email@test.com';
        c1.Phone = '9995556667';
        c1.OtherPhone = '9995556666';
        c1.AccountId = a1.Id; // aimed at NOT integration-user-owned account 
        c1.ownerId = notintegrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c1);}
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        system.assertEquals(integrationuser.Id, c1.OwnerId); // confirm owner, related to a1
        
        Contact c2 = new Contact();
        c2.Title = 'Commadore';
        c2.LastName = 'IntegrationUser';
        c2.FirstName = 'Contact';
        c2.Email = 'c2Email@test.com';
        c2.Phone = '9995556667';
        c2.OtherPhone = '9995556666';
        c2.AccountId = a1.Id; // aimed at NOT integration-user-owned account
        c2.OwnerId = integrationUser.Id; // aimed at Integration User
        system.runas(integrationUser){insert(c2);} 
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(integrationuser.Id, c2.OwnerId); // confirm owner, related to a1
        
        //insert prospect under the non-integration user
        Account a2 = new Account();
        a2.Name = 'Test Prospect';       
        a2.RSM__c=notIntegrationUser.RSM__c;
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        // so the account (a2) will be owned by a non-integration user
        system.runAs(notIntegrationUser){insert a2;}        
        
		// Now, we must change the account owner of the NONintegration user. The code should pick up no contacts.
		// Both accounts will be saved again, but since ownership of the account with 2 contacts has not changed,
		// and the other account has no contacts, the test should not touch the code that saves owner changes.
		// It does not.
        Test.startTest();
        
        a2.OwnerId = notintegrationUser.Id;
        List<Account> accts = new List<Account>();
        accts.add(a1);
        accts.add(a2);
        update(accts);
        
        Test.stopTest();
        
        a2 = [SELECT Id, OwnerId FROM Account WHERE Id = :a2.Id];
        c1 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c1.Id];
        c2 = [SELECT Id, OwnerId FROM Contact WHERE Id = :c2.Id];
        system.assertEquals(notintegrationuser.id, a2.ownerid); // confirm owner
        system.assertEquals(integrationuser.Id, c1.OwnerId); // confirm owner
        system.assertEquals(integrationuser.Id, c2.OwnerId); // confirm owner
    }
    
    
}