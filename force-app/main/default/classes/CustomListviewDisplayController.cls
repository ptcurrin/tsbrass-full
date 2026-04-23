public without sharing class CustomListviewDisplayController {
    
    @AuraEnabled
    public static boolean setUpAndCheckPermissions(){
         
        PermissionSet pset = [SELECT Id, Label, Name FROM PermissionSet WHERE Name = 'Today_s_Events_and_More_Widget'];
        
        Id userId = UserInfo.getUserId();
        
        PermissionSetAssignment psa;
        
        try{    
            psa = [SELECT AssigneeId,ExpirationDate,Id,IsActive,PermissionSetGroupId,PermissionSetId,SystemModstamp 
                   FROM PermissionSetAssignment 
                   WHERE AssigneeId = :userId
                   AND PermissionSetId = :pset.Id];
            
            if(psa != null){
                return true;
            }else{
                return false;
            }
        }catch(QueryException qex){
            return false;
        }
        
        
    }
    
    // Requires that the allowed list of sObjectTypes be entered into the Front End before dropping things in
    @AuraEnabled(cacheable=true)
    public static string retrieveOrgBaseURL(){
        
        return URL.getOrgDomainUrl().toExternalForm();
        
    }
    
    // Requires that the allowed list of sObjectTypes be entered into the Front End before dropping things in
    @AuraEnabled(cacheable=true)
    public static List<ListView> retrieveListViews(String sObjectType){
        
        return getListViewsBySObjectType(sObjectType);
        
    }
    
    // Requires that the allowed list of sObjectTypes be entered into the Front End before dropping things in
    @AuraEnabled(cacheable=true)
    public static List<ListView> retrieveListViewsByName(String sObjectType, String listViewName){
        
        return getListViewsBySObjectType(sObjectType, listViewName);
        
    }
    
    @testVisible
    private static List<ListView> getListViewsBySObjectType(String sObjectType){
        
        List<ListView> listViews = [SELECT Id, 
                                    Name, 
                                    DeveloperName,
                                    SObjectType 
                                    FROM ListView 
                                    WHERE SObjectType = :sObjectType
                                    ORDER BY Name
                                   ];
        
        return listViews;
        
    }
    
    @testVisible
    private static List<ListView> getListViewsBySObjectType(String sObjectType, String listViewName){
        
        List<ListView> listViews = [SELECT Id, 
                                    Name,
                                    DeveloperName,
                                    SObjectType 
                                    FROM ListView 
                                    WHERE SObjectType = :sObjectType
                                    AND DeveloperName = :listViewName
                                    ORDER BY Name
                                   ];
        
        return listViews;
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Sobject> retrieveSObjectsByListView(String filterId, String sObjectType){
        
        Map<String, Object> tokenResponse = retrieveSObjectsQueryByListView(filterID, sObjectType);
        
        String query = (String) tokenResponse.get('query');
        System.debug('QUERY FOUND ... ' + query);
        
        List<Object> columns = (List<Object>)tokenResponse.get('columns');
        System.debug('Columns FOUND ... ' + columns);
        
        for(Object o : columns){
            Map<String, Object> column = (Map<String, Object>) o;
            system.debug('COLUMN: ' + column);
            
            for(String ostr : column.keyset()){
                
                Object objAttr = column.get(ostr);
                system.debug('.........[' + ostr + ']' +  + objAttr);
                
            }
            
        }
        
        
        List<SObject> sobjects = Database.query(query);
        
        system.debug(sobjects);
        
        return sobjects;
        
    }
    
    
    
    private static Map<String, Object> retrieveSObjectsQueryByListView(String filterId, String sObjectType){
        
        String sessionId = '';
        // Refer to the Page
        PageReference reportPage;
        String vfContent;
        if(Test.isRunningTest()){
            
            vfContent = CustomListviewDisplayControllerTest.content;
            System.debug('vfContent '+vfContent);
            // Find the position of Start_Of_Session_Id and End_Of_Session_Id
            Integer startP = vfContent.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length(),
                endP = vfContent.indexOf('End_Of_Session_Id');
            // Get the Session Id
            sessionId = vfContent.substring(startP, endP);
            System.debug('sessionId '+sessionId);
            
        }else{
            reportPage = Page.GetSessionIdVFtoLWC;
            // Get the content of the VF page
            vfContent = reportPage.getContent().toString();
            System.debug('vfContent '+vfContent);
            // Find the position of Start_Of_Session_Id and End_Of_Session_Id
            Integer startP = vfContent.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length(),
                endP = vfContent.indexOf('End_Of_Session_Id');
            // Get the Session Id
            sessionId = vfContent.substring(startP, endP);
            System.debug('sessionId '+sessionId);
        }
        
        system.debug('filterId: ' + filterId);
        
        HttpRequest req = new HttpRequest();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String endPoinURL = baseUrl+'/services/data/v58.0/sobjects/'+ sobjectType +'/listviews/'+ filterId +'/describe';
        req.setEndpoint(endPoinURL);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        Http http = new Http();
        
        HttpResponse response;
        if(Test.isRunningTest()){
            response = new HttpResponse();
            response.setStatusCode(200);
            
            string body = JSON.serialize(CustomListViewDisplayControllerTest.bodyObject); 
            
            response.setBody(body);
        }else{
            response = http.send(req);
        }
        
        
        if( response.getStatusCode() == 200 ) {
            
            Map<String, Object> tokenResponse;
            
            tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            for(String key : tokenResponse.keyset()){
                
                system.debug('tokenResponse[' + key + ']: ' + tokenResponse.get(key));
                
            }
            
            String query = (String) tokenResponse.get('query');
            System.debug('QUERY FOUND ... ' + query);
            
            return tokenResponse;
            
        }else{
            
            
            system.debug('response.getBody(): ' + response.getBody());
            
            
        }
        
        
        return null;
        
    }
    
    
    
    
}