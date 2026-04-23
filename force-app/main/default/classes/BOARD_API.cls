public class BOARD_API {
    
    //private string endpoint_POST_getToken = 'https://tsbrass-idp.board.com/connect/token';
    private string calloutTokenMethod = 'POST';
    
    public class BAPI_TokenResponse{
        public string access_token {get;set;}
        public string expires_in {get;set;}
        public string token_type {get;set;}
        public string scope {get;set;}
        public string message {get;set;}
    }
    
    public class MissingTokenException extends Exception {}
    
    @testVisible
    public string GET_AccessToken(){
        
        String accessToken;
        String expires_in;
        String token_Type;
        String scopeReturned;
        String message;
        
        Map<String, String> bodyParams = new Map<String, String>();
        
        bodyParams.put('grant_type', '{!$Credential.BOARDTokenExternalCredential.grant_type}');
        bodyParams.put('scope', '{!$Credential.BOARDTokenExternalCredential.scope}');
        bodyParams.put('client_id', '{!$Credential.BOARDTokenExternalCredential.client_id}');
        bodyParams.put('client_secret', '{!$Credential.BOARDTokenExternalCredential.client_secret}');
        
        integer count = 0;
        
        string body = '';
        for(String key : bodyParams.keyset()){
            
            body += (count == 0 ? '' : '&') + key + '=' + bodyParams.get(key);
            
            count++;
        }
        system.debug('body: '+ body);
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('content-type', 'application/x-www-form-urlencoded');
        //req.setHeader('scope', scope);
        req.setBody(body);
        //req.setEndpoint(endpoint_POST_getToken);
        req.setEndpoint('callout:BOARDTokenNamedCredential');
        req.setMethod(calloutTokenMethod);
        
        HttpResponse res;
        
        system.debug('$$$ %%% req: ' + req);
        
        res = h.send(req);
        
        system.debug('$$$ res: ' + res);
        
        String resbody = res.getBody();
        
        system.debug('$$$ resbody: ' + resbody);
        
        BAPI_TokenResponse bapiResponse = (BAPI_TokenResponse)JSON.deserialize(resbody, BOARD_API.BAPI_TokenResponse.class);
        
        system.debug('$$$ bapiResponse: ' + bapiResponse);
        
        accessToken = bapiResponse.access_token;
        system.debug('$$$ accessToken: ' + accessToken);
        expires_in = bapiResponse.expires_in;
        system.debug('$$$ expires_in: ' + expires_in);
        token_type = bapiResponse.token_type;
        system.debug('$$$ token_type: ' + token_type);
        scopeReturned = bapiResponse.scope;
        system.debug('$$$ scope(returned): ' + scopeReturned);
        message = bapiResponse.message;
        system.debug('$$$ message: ' + message);
        
        
        
        
        
        if(accessToken == null || accessToken == ''){
            throw new MissingTokenException(message);
        }
        
        system.debug('accessToken: ' + accessToken);
        
        return accessToken;
    }
    
    
    
    @testVisible    
    private List<Account> convert_GET_BIxSales_ToAccountList(HTTPResponse res){
        
        string body = res.getBody();
        
        // Parse response
        
        Map<String, Object> resMap = (Map<String, Object>)JSON.deserializeUntyped(body);
        system.debug('resmap: ' + resmap);
        List<Object> objList = (List<Object>)resmap.get('data');
        system.debug('data:' + objList);
        
        List<Account> acctsForUpdate = mapObjects(objList);
        
        return acctsForUpdate;
    }
    
    
    
    @testVisible
    private List<Account> mapObjects(List<Object> boardList){
        
        List<Account> accounts = new List<Account>();
        
        /*
        Map<string, Account> mapChina = selectChinaAccountsByCustNum();
        Map<string, Account> mapTR    = selectTRAccountsByCustNum();
        */
        
        if(boardlist != null && !boardlist.isEmpty()){
            
            system.debug('boardList[size]: ' + boardlist.size());
            
            for(Object o : boardList){
                
                Map<String, Object> oTempMap = (Map<String, Object>)o;
                
                string extId =  (String)oTempMap.get('customer');
                Decimal valueTR =  (Decimal)oTempMap.get('ytd Sales TR');
                Decimal valueChina = (Decimal)oTempMap.get('ytd Sales TSZQ');
                
                
                
                
                // The Account Slug only serves as a carrier. We are not saving this account...
                system.debug('...Acct ExtId: ' + extid);
                system.debug('........TR...> ' + valueTR);
                system.debug('........China> ' + valueChina);
                system.debug('----------------------------------------------------');
                if(extId != null){
                    Account a = new Account();
                    a.Cust_Num__c = extId;
                    Decimal decChinaVal = valueChina.setScale(2);
                    a.YTD_Sales_TSZQ__c = decChinaVal;
                    Decimal decVal = valueTR.setScale(2);
                    a.Sales_YTD__c = decVal;
                    accounts.add(a); // this is not an account to save, it is a slug
                }
                
            }
            
        }else{
            system.debug('boardList[size]: 0 ... empty');
        }
        
        return accounts;
    }
    
    private string endpoint_GET_BIxSalesMethod = 'GET';
    private string endpoint_GET_BIxSales = 'callout:NC_BOARD_API' + '/public/BI_Sales/query/SalesForce';
    // 2025-03-25 Addition for Other variables
    
    private string endpoint_GET_BIxSalesxChina = 'callout:NC_BOARD_API' + '/public/BI_Sales/query/SalesForce_TR_and_TSZQ';
    // NOTE FOR OTHER DEVS >>>>>>  the query name has a capital 'F' in Salesforce. It's case sensitive. Don't burn an hour or an afternoon.....
    
    // This one call is designed to find the current year and month, combine as strings appropriate, and pass with the
    // access token to the board API at a specific endpoint. If other calls are needed, they should be able to use the same 
    // utility method "createHTTPRequestAndCall" to get information from other paths off of the same endpoint on
    // "callout:NC_BOARD_API" ... (H.A.N.D.)
    
    
    @testVisible
    public HTTPResponse GET_BIxSales(string accessToken){
        
        
        Datetime nw = Datetime.now();
        
        Integer currentYear = nw.year();
        String currentYearStr = currentYear + '';
        system.debug('Param Built(currentYear>year): ' + currentYearStr);
        
        //Integer currentMonth = nw.month();
        //String currentMonthStr = currentMonth + '';
        //if(currentMonth < 10){
        //    currentMonthStr = '0' + currentMonthStr;
        //}
        //currentMonthStr = currentYearStr + currentMonthStr;
        //system.debug('Param Built(currentMonthStr>Month): ' + currentMonthStr);
        
        string endpoint = endpoint_GET_BIxSales;
        String method = endpoint_GET_BIxSalesMethod;
        
        Map<String, String> params = new Map<String, String>
        {'year' => (currentYearStr)
            ,
            //'month' => (currentMonthStr),
            'json' => 'Full'
            };
                
                
                HTTPResponse res = createHTTPRequestAndCall(/*username, clientSecret,*/ endpoint_GET_BIxSales, method, params, accessToken);
        
        system.debug('res: ' + res);
        
        
        return res;
        
    }
    
    
    // This call should be useful for any BOARD call, provided you have a correspoding Named Credential
    
    @testVisible 
    private HTTPResponse createHTTPRequestAndCall(/*string username, string clientSecret, */ string endpoint, string method, Map<String, String> params, string accessToken){
        
        //system.debug('2 username : ' + username);
        //system.debug('2 clientSecret : ' + clientSecret);
        system.debug('2 endpoint : ' + endpoint);
        system.debug('2 method : ' + method);
        system.debug('2 params : ' + params);
        system.debug('2 accesstoken : ' + accesstoken);
        
        if(params != null && params.keyset() != null && params.keyset().size() > 0){
            
            integer count = 0;
            
            for(string key : params.keyset()){
                endpoint += (count == 0 ? '?' : '&') + key + '=' + params.get(key);
                
                count++;
            }    
        }
        
        system.debug('2 endpoint: ' + endpoint);
        
        //String reqbody = 'client_secret=' + clientSecret + '&username=' + username;
        
        HTTP h2 = new HTTP();
        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint(endpoint);
        req2.setMethod(method);
        req2.setHeader('Accept', 'application/json');
        req2.setHeader('Authorization', 'Bearer ' + accessToken);
        
        system.debug('req2Method: ' + req2.getMethod());
        
        HttpResponse res = h2.send(req2);
        
        system.debug('res: '  +res);
        
        return res;
        
        
    }
    
    public List<Account> GETDATA_for_YTDSalesUpdate(Integer testLimit){
        
        string accessToken = GET_AccessToken();
        HTTPResponse res = GET_BIxSalesxChina(accesstoken);
        
        List<Account> acctListReturned = convert_GET_BIxSales_ToAccountList(res);
        List<Account> accountsPassed = new List<Account>();
        if(testLimit != null){ 
            
            for(Integer i = 0; i < testLimit; i++){
                accountsPassed.add(acctListReturned.get(i));
            }
            system.debug('^^^ ACCOUNTS with TestLimit[' + testLimit + ']: ' + accountsPassed.Size());
        }else{
            
            system.debug('^^^ It thinks there isnt a testLimit ... ');
            
            accountsPassed = acctListReturned;
        }
        
        return accountsPassed;
        
    }

	@testVisible
    public HTTPResponse GET_BIxSalesxChina(string accessToken){
        
        
        Datetime nw = Datetime.now();
        
        Integer currentYear = nw.year();
        String currentYearStr = currentYear + '';
        system.debug('Param Built(currentYear>year): ' + currentYearStr);
        
        string endpoint = endpoint_GET_BIxSalesxChina;
        String method = endpoint_GET_BIxSalesMethod;
        
        Map<String, String> params = new Map<String, String>
        {'year' => (currentYearStr)
            ,
            //'month' => (currentMonthStr),
            'json' => 'Full'
            };
                
                
                HTTPResponse res = createHTTPRequestAndCall(/*username, clientSecret,*/ endpoint, method, params, accessToken);
        
        system.debug('res: ' + res);
        
        
        return res;
        
    }    

}