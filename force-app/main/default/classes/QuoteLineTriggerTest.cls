@isTest
public class QuoteLineTriggerTest {

    static testmethod void TouchTrigger(){
        
        Opportunity opp = new Opportunity();
        opp.Name = 'TestOpp01';
        opp.Stagename = 'Proposal';
        opp.CloseDate = Date.today();
        insert(opp);
        
        
        
        Id pricebookStd = Test.getStandardPricebookId();
        
        Pricebook2 pb = new Pricebook2();
        pb.Name = 'TestCustomPB';
        pb.Quote_Object_Name_Concatenation__c = 'blahBefore';
        pb.Calendar_Year__c = '2025';
        pb.Price_Book_Country__c = 'China'; 
        insert(pb);
        
        Quote q = new Quote();
        q.OpportunityId = opp.Id;
        q.name = 'fdsaQuote';
        q.Pricebook2Id = pb.id;
        insert(q);
        
        Product2 prod = new PRoduct2();
        prod.name = 'Blah';
        prod.ProductCode = 'Blah';
        insert(prod);
        
        PricebookEntry pbeStd = new PricebookEntry();
        pbeStd.product2Id = prod.Id;
        pbeStd.pricebook2Id = pricebookStd;
        pbeStd.UnitPrice = 2.00;
        pbeStd.IsActive = true;
        insert(pbeStd);
        
        PricebookEntry pbe01 = new PricebookEntry();
        pbe01.product2Id = prod.Id;
        pbe01.pricebook2Id = pb.id;
        pbe01.UnitPrice = 2.00;
        pbe01.IsActive = true;
        insert(pbe01);
        
        Test.startTest();
        
        QuoteLineItem qliNew = new QuoteLineItem();
        qliNew.Quantity = 2;
        qliNew.UnitPrice = 5.00;
        qliNew.Discount = 10;
        qliNew.PricebookEntryId = pbe01.Id;
        qliNew.QuoteId = q.id;
        qliNew.Total_Price_UADFormat__c = '';
        insert(qliNew);
        
        Test.stopTest();
        
        QuoteLineItem qliAfter = [SELECT Id, Total_Price_UADFormat__c FROM QuoteLineItem WHERE Id = :qliNew.Id];
        
        system.assertEquals('د.إ‎9.00', qliAfter.Total_Price_UADFormat__c);
        
        
    }
}