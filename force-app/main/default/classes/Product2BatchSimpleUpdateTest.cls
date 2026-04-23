@isTest
public class Product2BatchSimpleUpdateTest {

    static public boolean isNotSame {get;set;}
    
    static testmethod void touch(){
    
    
        Product2 p = new Product2();
        p.Name = 'TestProduct1111';
        p.Specification__c = 'https://www.tsbrass.com/files/drawings/EQUIP-KASON-FCTS-PRE-RINSE/FAUCETS/5EF-1D-DS.pdf';
        p.isActive = true;
        insert(p);
        
        Test.startTest();
    	Database.executeBatch(new Product2BatchSimpleUpdate());
        Test.stopTest();
        
        Product2BatchSimpleUpdateTest.isNotSame = true;
        
        new HttpGETCalloutForPDFFileStorage(p.Id).addFileToProduct();
        
    }
}