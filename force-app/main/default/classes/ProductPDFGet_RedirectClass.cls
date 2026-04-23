public class ProductPDFGet_RedirectClass {

    
    public final Product2 p {get;set;}
    
    public ProductPDFGet_RedirectClass(ApexPages.StandardController controller){
        
        if(!Test.isRunningTest()){
            p = (Product2) controller.getRecord();
        }else{
            p = ProductPDFGet_RedirectClass_Test.testProduct2;
        }
        
    }
    
    public PageReference redirect()
    {
        HttpGETCalloutForPDFFileStorage httpCallout = new HttpGETCalloutForPDFFileStorage(p.Id);
        
        Boolean successBool = httpCallout.addFileToProduct();
        
        if(successBool){
        
        	return new PageReference('/' + p.Id);
            
        }else{
            
            return Page.ProductPDFSaveCallErrorPage;
            
        }
    }
    
}