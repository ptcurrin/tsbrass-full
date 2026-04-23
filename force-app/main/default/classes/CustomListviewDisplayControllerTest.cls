@isTest
public class CustomListviewDisplayControllerTest {
    
    public static string content = 
        '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' +
        '<html><head><script src="/static/111213/js/perf/stub.js" type="text/javascript"></script><script src="/jslibrary/1699262264248/sfdc/main.js" type="text/javascript"></script><script src="/jslibrary/jslabels/1704575266000/en_US.js" type="text/javascript"></script><link class="user" href="/sCSS/60.0/sprites/1699976260000/Theme3/default/gc/zen-componentsCompatible.css" ></script></head><body>' +
        'Start_Of_Session_IdSESSION_ID_REMOVEDEnd_Of_Session_Id<script>if (this.SfdcApp && this.SfdcApp.projectOneNavigator) { SfdcApp.projectOneNavigator.sendTitleToParent(\'GetSessionIdVFtoLWC\'); } </script></body></html>';
        
    
    
    
    
    
    @testVisible
    private static string query = 'SELECT StartDateTime, EndDateTime, toLabel(Subject), Who.Name, What.Name, Owner.Alias, IsAllDayEvent, EndDate, ActivityDate, Id, CreatedDate, LastModifiedDate, SystemModstamp, Who.Id, WhoId, What.Id, WhatId, Owner.Id, OwnerId FROM Event USING SCOPE mine WHERE GroupEventType != \'2\' AND GroupEventType != \'3\' AND ActivityDate = LAST_N_DAYS:60 ORDER BY StartDateTime ASC NULLS FIRST, Id ASC NULLS FIRST';
    
    @testVisible
    private class column {
        public string ascendingLabel='New to Old'; 
        public string descendingLabel='Old to New';
        public string fieldNameOrPath='StartDateTime';
        public boolean hidden=false;
        public string label='Start Date & Time';
        public boolean searchable=false;
        public string selectListItem='StartDateTime';
        public string sortDirection='ascending';
        public Integer sortIndex=0;
        public boolean sortable=true;
        
    }
    
    @testVisible
    public static Map<String, Object> bodyObject;
    
    private static testmethod void touchPermissionSetAssignment(){
        
        CustomListviewDisplayController.setUpAndCheckPermissions();
        
    }
    
    private static testmethod void touchBaseOrgURL(){
        CustomListviewDisplayController.retrieveOrgBaseURL();
    }
    
    private static testmethod void touchRetrieveListViews(){
        CustomListviewDisplayController.retrieveListViews('Event');
    }
    
    private static testmethod void tryGenericSOSLCall_Event(){
        
        bodyObject = new Map<String, Object>();
        bodyObject.put('query', query);
        bodyObject.put('columns', new List<Column>{new column()});
        
        string listViewName = 'MyRecentEvents';
        string sObjectType = 'Event';
        
        List<ListView> listViews = CustomListviewDisplayController.retrieveListViewsByName(sObjectType, listViewName);
        
        Id filterId = listViews[0].Id;
        
        CustomListviewDisplayController.retrieveSObjectsByListView(filterId, sObjectType);
        
    }
    
}