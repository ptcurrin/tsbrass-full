@isTest
public class LeadTriggerTest {

    // The way this method works... 
    // The LeadTriggerTest class can't see all data, so it relies on what's produced by the 
    // actual method. There are zero leads when it begins, one is inserted during the bootup
    // faze of the method, and after that lead is converted, there are TWO leads, because one
    // was converted and moved out of the system, where we can see (and no one can tell me why!)
    // while the new lead is given the Status "QUALIFIED READ ONLY," which is not an OOB
    // Status, and represents a new Lead that will never be converted. This new Lead is
    // essentially archived, and available in the Lead related list for the Account and Contact
    // created when it was converted. 
    
    static testmethod void canLeadMakeALead(){
        
        Id RecTypeIdSalesRep = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        
        List<Account> accounts = [SELECT Id, Name FROM Account];
        system.assert(accounts.isEmpty());
        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA09999';
        a1.Type='Rep Agency';
        a1.RecordTypeId=RecTypeIdSalesRep;
        insert a1;     
        
        accounts = [SELECT Id, Name FROM Account];
        system.assertEquals(accounts.size(), 1);
        
        List<Contact> contacts = [SELECT Id, Name FROM Contact];
        system.assert(contacts.isEmpty());
        
        List<Lead> leads = [SELECT Id FROM Lead];
        
        system.assert(leads.size() == 0);
        
        Lead l = new Lead();
        l.Account_Type__c = 'Installer';
        l.street = '316 Main Street';
        l.City = 'Oxford';
        l.State = 'NC';
        l.PostalCode = '27565';
        l.Company = 'The Boring Company';
        l.LastName = 'Little';
        l.FirstName = 'Omar';
        l.Status = 'New';
        l.Email = 'Test@email.com';
        l.Phone = '9999999999';
        l.Title = 'Sir';
        l.Sales_Rep__c = a1.Id;
        l.eContacts__Business_Card__c = '/09/fdsafdsafdsafdafdsafdsa';
        
        insert(l);
        
        leads = [SELECT Id FROM Lead];
        system.assert(leads.size() == 1);
        
        
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.id);
        
        LeadStatus convertStatus = [SELECT Id, ApiName FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(convertStatus.ApiName);
        
        
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        System.assert(lcr.isSuccess());
        
        Test.startTest();
        
        
        
        Test.stopTest();
        
        leads = [SELECT Id, 
                 Status, 
                 Lastname, 
                 Firstname, 
                 Company, 
                 Converted_Account__c, 
                 Converted_Contact__c 
                 FROM Lead
                 ORDER BY Status
                 ASC
                ];
        system.assert(leads.size() == 2);
        for(Lead led : leads){
            
            system.debug(led);
            
        }
        
        Boolean foundQualified = false;
        for(Lead led : leads){
            if(led.Status == 'Qualified'){
                foundQualified = true;
            }
        }
        system.assert(foundQualified);
        //system.assertEquals(leads[0].Status, 'Qualified');
        
        Boolean foundQualifiedReadOnly = false;
        for(Lead led : leads){
            if(led.Status == 'Qualified Read Only'){
                foundQualifiedReadOnly = true;
            }
        }
        system.assert(foundQualifiedReadOnly);
        //system.assertEquals(leads[1].Status, 'Qualified Read Only');
        
        
        accounts = [SELECT Id, Name FROM Account];
        system.assertEquals(accounts.size(), 2);
        
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'The Boring Company'];
        system.assertEquals(testAccount.Name, ('The Boring Company'));
        
        contacts = [SELECT Id, Name, eContacts__Business_Card__c FROM Contact];
		system.assertEquals(contacts.size(), 1); 
        system.assertEquals(contacts[0].Name, 'Omar Little');
        system.assertEquals(contacts[0].eContacts__Business_Card__c, '/09/fdsafdsafdsafdafdsafdsa');
        
        
    }
    
}