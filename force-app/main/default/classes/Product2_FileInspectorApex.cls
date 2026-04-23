public class Product2_FileInspectorApex {
    
    public class ProductWrapper{
        
       
        @AuraEnabled public List<ContentVersion> cvs {get;set;}
        @AuraEnabled public ContentDocument cd {get;set;}
        @AuraEnabled public Product2 product {get;set;}
        @AuraEnabled public ContentDocumentLink cdl {get;set;}
        
        public ProductWrapper(Product2 p, ContentDocumentLink cdl, ContentDocument cd, List<ContentVersion> cvs){
            
            this.product = p;
            this.cd = cd;
            this.cvs = cvs;
            this.cdl = cdl;
            
        }
    }
        
    
    @AuraEnabled
    public static List<ProductWrapper> getProducts(boolean isActive) {
        
        Product2_FileInspectorApex fi = new Product2_FileInspectorApex([SELECT Id, Name, ProductCode, Specification__c, isActive  FROM Product2 WHERE isActive = :isActive]);
        
        return fi.wrappers;
    }
    
    private List<Product2> products {get;set;}
    private Map<Id, Product2> mapProducts {get;set;}
    private Set<Id> pids {get;set;}
    private List<String> titleStrings {get;set;}
    private List<ProductWrapper> wrappers {get;set;}
    private Map<String, ContentDocument> mapContentDocs {get;set;} 
    private Set<Id> contentDocIdSet {get;set;}
    private Map<Id, List<ContentVersion>> mapCDtoContentVersions {get;set;}
    private List<ContentDocumentLink> cdls {get;set;}
    private integer totalCVs {get;set;}
    
    public Product2_FileInspectorApex(List<Product2> products){
        
        this.products = products;
        
        this.mapProducts = new Map<Id, Product2>(this.products);
        
        this.titleStrings = new List<String>();
        
        if(wrappers == null || wrappers.isEmpty()){
            wrappers = new List<ProductWrapper>();
        }
        
        this.pids = new Set<Id>();
        for(Product2 p : products){
            titleStrings.add(p.ProductCode + '.pdf');
            pids.add(p.Id);
        }
        
        // cDe.ContentDocumentId = conDoc;
        // cDe.LinkedEntityId = product.Id; // you can use objectId,GroupId etc
        // cDe.ShareType = 'I'; // Inferred permission, checkout description of ContentDocumentLink object for more details
        // cDe.Visibility
        
        cdls = [SELECT Id, ContentDocumentId, LinkedEntityId, ShareType, Visibility FROM ContentDocumentLink
                WHERE LinkedEntityId IN :pids
               ];
        
        mapContentDocs = mapContentDocs(this.titleStrings);
        
        contentDocIdSet = new Set<Id>();
        
        for(ContentDocument cd : mapContentDocs.Values()){
            contentDocIdSet.add(cd.Id);
        }
        
        mapCDtoContentVersions = mapContentVersions(contentDocIdSet);
        
        totalCVs = 0;
        
        for(ContentDocumentLink cdl : cdls){
            
            List<ContentVersion> cvsTemp = mapCDtoContentVersions.get(cdl.ContentDocumentId);
            
            Product2 prod = mapProducts.get(cdl.LinkedEntityId);
            ContentDocument cd;
            
            if(cvsTemp != null && !cvsTemp.isEmpty()){
            	cd = mapContentDocs.get(cvsTemp[0].ContentDocumentId);
            }
            
            ProductWrapper pw = new ProductWrapper(prod, cdl, cd, cvsTemp);
            
            wrappers.add(pw);
            
        }
        
        for(ProductWrapper w : wrappers){
            if(w.cvs != null && w.cvs.size() > 0){
                totalCVs += w.cvs.size();
            }
        }
        
        system.debug('#products: ' + products.size()); 
        system.debug('#mappedProducts: ' + mapProducts.keyset().size());
        system.debug('#pids: ' +  pids);
        system.debug('#titles: ' +  titleStrings.size() );
        system.debug('#productWrappers: ' + wrappers.size());
        system.debug('#mapContentDocs.keyset: ' +  mapContentDocs.keyset().size());
        system.debug('#contentDocIdSet: ' +  contentDocIdSet.size()); 
        system.debug('#mapCDtoContentVersions.keyset.size: ' + mapCDtoContentVersions.keyset().size());
        system.debug('#TotalCVs: ' + totalCVs);
        system.debug('#cdls: ' + cdls.size()); 
        
    }
    
    private Map<String, ContentDocument> mapContentDocs(List<string> titleStrings){
        
        List<ContentDocument> cds = new List<ContentDocument>();
        Map<String, ContentDocument> mapCds = new Map<String, ContentDocument>();
        
        cds = [SELECT Id, Title FROM ContentDocument 
               WHERE Title IN :titleStrings
               
              ];
        
        system.debug('cds: ' + cds.size());
        
        for(ContentDocument cd : cds){
            mapCds.put(cd.title, cd);
        }
        
        return mapCds;
    }
    
    private Map<Id, List<ContentVersion>> mapContentVersions(Set<Id> contentDocIds){
        
        Map<Id, List<ContentVersion>> mapCDtoContentVersions = new Map<Id, List<ContentVersion>>();
        
        List<ContentVersion> versions = new List<ContentVersion>();
        versions = [SELECT Id, 
                    ContentDocumentId,
                    PathOnClient,
                    ContentUrl,
                    //VersionData,
                    Title,
                    IsMajorVersion,
                    OWnerId,
                    PublishStatus
                    FROM ContentVersion 
                    WHERE isLatest = true
                    AND ContentDocumentId IN :contentDocIds];
        
        for(ContentVersion cv : versions){
            
            List<ContentVersion> versionsTemp = mapCDtoContentVersions.get(cv.ContentDocumentId);
            if(versionsTemp == null){
                versionsTemp = new List<ContentVersion>();
            }
            versionsTemp.add(cv);
            mapCDtoContentVersions.put(cv.ContentDocumentId, versionsTemp);
            
        }
        
        return mapCDtoContentVersions;
        
    }
    
}