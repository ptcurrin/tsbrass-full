public class PhoneNumberFormatter {

    @InvocableMethod(label='FormatNumberInvocable' description='Replaces all non-digit characters and produces a purely numberic number' category='Custom Apex Utility Classes')
    public static List<String> formatNumbers(List<String> numbers) {
    
        List<String> numbersFormatted = new List<String>();
        
        for(String numForFormat : numbers){
        	
            numForFormat=numForFormat.replaceAll('[^0-9]', '');
        	
            numbersFormatted.add(numForFormat);
            
        }
            
        return numbersFormatted;
    }
  
    
}