@isTest
public class ContactTriggerHandlerTest {
    
    @TestSetup
    static void makeData(){

        Id currentUserId = UserInfo.getUserid();
        User u = [select Id from User where Id != :currentUserId And Sales_Team_Id__c != null limit 1];
        List<Account> accountList = new List<Account>();
        List<Contact> contactList = new List<Contact>();

         //insert rep agency account
         Account a1 = new Account();
         a1.Name = 'Rep Agency';       
         a1.External_Id__c='12345';
         a1.SLSMan_EXT_ID__c='SMA00001';
         a1.Type='Rep Agency';
         a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
         a1.OwnerId=u.Id;
         a1.Salesman__c='Old Sales Rep 1';
         insert a1;    
         accountList.add(a1);              
         
          //insert prospect
         Account a2 = new Account();
         a2.Name = 'Test Prospect';
         a2.RSM__c='SMA00867';
         a2.External_Id__c='12346';
         a2.SLSMan_Rep_Agency__c=a1.Id;
         a2.Type='Installer';   
         a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();  
         a2.OwnerId=u.Id;
         a2.Salesman__c='Old Sales Rep 2';
         insert a2;    

         //insert a contact for the prospect
         Contact c = new Contact();
         c.FirstName='John';
         c.LastName='Smith';     
         c.AccountId=a2.Id;
         c.Email='test@test.com';
         c.OtherPhone='9191234567';
         c.Phone='1234567890';
         c.Title='President';
         contactList.add(c);

          //insert a contact for the Rep Agency
          Contact c2 = new Contact();
          c2.FirstName='Ben';
          c2.LastName='Franklin';     
          c2.AccountId=a1.Id;
          c2.Email='test2@test.com';
          c2.OtherPhone='9191234560';
          c2.Phone='1234567899';
          c2.Title='CEO';
         contactList.add(c2);
         insert contactList;
    }

    @isTest static void testContactUpdate(){
        Contact c = [Select Id, LastName From Contact Where LastName='Smith'][0];
        test.startTest();
        c.LastName = 'Jones';
        update c;
        test.stopTest();
        system.assertEquals('Jones', [Select LastName From Contact Where Id = :c.Id].LastName, 'Assert that LastName was updated');
    } 

    @isTest static void testContactDelete(){
        Contact c = [Select Id From Contact Where LastName='Smith'][0];
        test.startTest();
        delete c;
        test.stopTest();
        system.assertEquals(0, [Select Count() From Contact Where LastName='Smith'],'Assert that Contact was deleted');
    }

    @isTest static void testRepAgencyAcctDeleteValidation(){
        User u = [Select Id From User 
                 Where Profile.Name != 'T&S Brass - System Administrator'
                 AND Profile.Name != 'System Administrator'][0];
        Contact c = [Select Id From Contact Where LastName='Franklin'];
        Database.DeleteResult dr;

        system.runAs(u){
            test.startTest();
            dr = Database.delete(c,false);
            test.stopTest();
        }
        system.assertEquals(false, dr.isSuccess(),'Assert that attempt to delete Rep Agency Contact by Non Sys Admin failed');
    }
}