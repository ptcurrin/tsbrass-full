@isTest
public class Pricebook2TriggerTest {

    
    static testmethod void newPricebook(){
        
        Test.startTest();
        
        Pricebook2 pb = new Pricebook2();
        pb.Calendar_Year__c = '2025';
        pb.Calendar_Month__c = 'June';
        pb.Price_Book_Country__c = 'US';
        pb.Quote_Object_Name_Concatenation__c = 'MESABOOGIE';
        pb.IsActive = true;
        pb.Name = 'fdsa';
        insert(pb);
        
        Test.stopTest();
        
        PriceBook2 resPB = [SELECT Id, Calendar_Year__c, Calendar_Month__c, Price_Book_Country__c, Quote_Object_Name_Concatenation__c, IsActive, Name FROM Pricebook2 WHERE Id = :pb.Id];

        system.assertEquals('MESABOOGIE US June 2025 Price Book', resPB.Name);
        
    }
    
}