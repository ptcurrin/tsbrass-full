@isTest
public class ProductPDFGet_RedirectClass_Test {

    public static Product2 testProduct2 {get;set;} 
    
    static testmethod void touch(){
        
        Product2 p = new Product2();
        p.Name = 'TestProduct1111';
        p.Specification__c = 'https://www.tsbrass.com/files/drawings/EQUIP-KASON-FCTS-PRE-RINSE/FAUCETS/5EF-1D-DS.pdf';
        p.isActive = true;
        insert(p);
        
        testProduct2 = p;
        
        PageReference pageRef = Page.ProductPDFSaveCallByRecordId;
		Test.setCurrentPage(pageRef);
		pageRef.getParameters().put('Id', String.valueOf(p.Id));
		ApexPages.StandardController sc = new ApexPages.StandardController(p);
		ProductPDFGet_RedirectClass pdfGET = new ProductPDFGet_RedirectClass(sc);
        
        pdfGET.redirect();
        
    }
    
}