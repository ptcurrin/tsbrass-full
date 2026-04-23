global class BOARD_API_MOCKS implements HttpCalloutMock {
    
    //global final string tokenEndpoint = 'https://tsbrass-idp.board.com/connect/token';
    global final string tokenEndpoint = 'callout:BOARDTokenNamedCredential';
    //global final string listEndpoint = 'https://tsbrass-c1.board.com/public/BI_Sales/query/SalesForce';
    //global final string listEndpoint = 'callout:NC_BOARD_API/public/BI_Sales/query/SalesForce';
    global final string listEndpoint = 'callout:NC_BOARD_API/public/BI_Sales/query/SalesForce_TR_and_TSZQ';
    
    
    // This is a shorter response string for quick tests, there is a much longer one for the scheduled batch
    //@testVisible
    //private static string listResponseSuccessResponseString = '{\"data\":[{\"\":176.646621704102, \"customer\":\"AT00175\"}, {\"\":196.080001831055, \"customer\":\"CA00195\"}]}';
    @testVisible
    private static string listResponseSuccessResponseString = '{\"data\":[{\"customer\":\"AT00999\",\"ytd Sales TR\":41924.7196683884,\"ytd Sales TSZQ\":0.0},{\"customer\":\"AW03999\",\"ytd Sales TR\":3710.82594680786,\"ytd Sales TSZQ\":196.080001831055}]}';
    @testVisible
    private static boolean isSuccessTokenCallout {get;set;}
    @testVisible
    private Static boolean isSuccessListCallout {get;set;}
    
    global HTTPResponse respond(HTTPRequest req){
        
        system.debug('req.Endpoint GET: ' + req.getEndpoint());
        system.debug('req tokenEndpoint ' + tokenEndpoint);
        
        if(req.getEndpoint().contains(tokenEndpoint)){
            
            // Create a fake TOKEN response
            HttpResponse res = new HttpResponse();
            
            res.setHeader('Content-Type', 'application/json');
            res.setBody(accessTokenResponseString);
            if(isSuccessTokenCallout){
                res.setStatusCode(200);
                res.setBody(accessTokenResponseString);
            }else{
                res.setStatusCode(401);
                res.setBody(accessTokenFailResponstString);
            }
            
            
            return res;
            
        }else if(req.getEndpoint().contains(listEndpoint)){
           
            // Create a fake LIST response
            HttpResponse res = new HttpResponse();
            
            res.setHeader('Content-Type', 'application/json');
            
            if(isSuccessListCallout == true){
                res.setStatusCode(200);
                res.setBody(listResponseSuccessResponseString);
            }else{
                res.setStatusCode(401);
                res.setBody(listResponsFailResponstString);
            }
            
            
            return res;
        }
        
        return null;
        
    }
    

    global string accessTokenResponseString = '{\"access_token\":\"eyJhbGciOiJSUzI1NiIsImtpZCI6IjY4MDk0RDE3NTRCNUE0REMxMkM1ODFFMkY1ODQ5Q0ZCRjc1OTA5MzZSUzI1NiIsIng1dCI6ImFBbE5GMVMxcE53U3hZSGk5WVNjLV9kWkNUWSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL3RzYnJhc3MtaWRwLmJvYXJkLmNvbSIsIm5iZiI6MTcwNzM0NTAzMSwiaWF0IjoxNzA3MzQ1MDMxLCJleHAiOjE3MDk5MzcwMzEsImF1ZCI6WyJwdWJsaWMtYXBpIiwiaHR0cHM6Ly90c2JyYXNzLWlkcC5ib2FyZC5jb20vcmVzb3VyY2VzIl0sInNjb3BlIjpbInB1YmxpYy1hcGkiXSwiY2xpZW50X2lkIjoiU2FsZXNmb3JjZSIsInJvbGVzXzIiOiJCSSBMaXRlIiwibGljZW5\",' 
        + '\"expires_in\":\"2592000\",'
        + '\"token_type\":\"Bearer\",'
        + '\"scope\":\"public-api\"'
        + '}';
    
    
    global string accessTokenFailResponstString = '{\"message\":\"Resource not found.\"}';
    
    global string listResponsFailResponstString = '{\"message\":\"Authorization has been denied for this request.\"}';
}