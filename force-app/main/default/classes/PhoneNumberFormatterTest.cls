@isTest
public class PhoneNumberFormatterTest {

    static testmethod void touch(){
        
        List<String> results = PhoneNumberFormatter.formatNumbers(new List<String>{'+1 919-812---7702'});
        system.assertEquals('19198127702', results[0]);
        
    }
    
}