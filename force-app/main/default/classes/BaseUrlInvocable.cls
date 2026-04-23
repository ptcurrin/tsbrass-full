public class BaseUrlInvocable {
    
    @InvocableMethod(label='Get Organization Base Url' description='Returns the base url string for the current org' )
    public static List<String> getBaseOrgUrl(List<ID> ids) {
        
        List<String> orgStrings = new List<String>();
        System.Url org = URL.getOrgDomainUrl();
        for(Id i : ids){
        	orgStrings.add(org.toExternalForm());
        }
        system.debug('org Url: ' + orgStrings[0]);
        
        return orgStrings;
    }
    
}