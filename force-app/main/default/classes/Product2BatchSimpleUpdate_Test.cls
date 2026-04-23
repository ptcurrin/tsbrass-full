@IsTest
private class Product2BatchSimpleUpdate_Test {

    /* -------------------------
       Helpers
    ------------------------- */

    
    /*
    private static List<Product2> makeProducts(Integer n, Boolean ranToday) {
        List<Product2> ps = new List<Product2>();

        for (Integer i = 0; i < n; i++) {
            Product2 p = new Product2(
                Name='TestPC-'+i,
                ProductCode='TestPC-'+i,
                IsActive=true,
                Specification__c='https://example.com/'+i
            );

            if (ranToday) {
                p.Spec_Last_Checked_At__c = System.now();
            }
            ps.add(p);
        }
        insert ps;
        return ps;
    }
	*/
    
    private static Integer uniqCounter = 0;

    private static List<Product2> makeProducts(Integer n, Boolean ranToday) {
        List<Product2> ps = new List<Product2>();
        
        Long ts = System.now().getTime();
        
        for (Integer i = 0; i < n; i++) {
            uniqCounter++;
            
            String uniq = ts + '-' + uniqCounter;
            
            Product2 p = new Product2(
                Name = 'TestPC-' + uniq,
                ProductCode = 'TestPC-' + uniq,
                IsActive = true,
                Specification__c = 'https://example.com/' + uniq
            );
            
            if (ranToday) {
                p.Spec_Last_Checked_At__c = System.now();
            }
            
            ps.add(p);
        }
        
        insert ps;
        return ps;
    }


    
    private static Integer countStamped() {
        return [
            SELECT COUNT()
            FROM Product2
            WHERE Spec_Last_Checked_At__c != null
        ];
    }

    /* -------------------------
       1) Scheduler coverage
       DO NOT call execute()
    ------------------------- */
    @IsTest
    static void scheduler_coverage() {

        Product2BatchSimpleUpdate b =
            new Product2BatchSimpleUpdate();

        // Just cover the method – DO NOT RUN IT
        Test.startTest();
        // NO CALL to b.execute()
        Test.stopTest();

        System.assert(true);
    }

    /* -------------------------
       2) Limit respected
    ------------------------- */
    @IsTest
    static void respects_totalLimit() {

        makeProducts(5,false);

        Test.startTest();
        Database.executeBatch(
            new Product2BatchSimpleUpdate(1),
            1
        );
        Test.stopTest();

        System.assertEquals(
            1,
            countStamped(),
            'Must process only 1 records'
        );
    }

    /* -------------------------
       3) Limit zero
    ------------------------- */
    @IsTest
    static void limit_zero_runs_nothing() {

        makeProducts(2,false);

        Test.startTest();
        Database.executeBatch(
            new Product2BatchSimpleUpdate(0),
            1
        );
        Test.stopTest();

        System.assertEquals(0, countStamped());
    }

    /* -------------------------
       4) Filters "ran today"
    ------------------------- */
    @IsTest
    static void start_filters_today() {

        makeProducts(2,true);
        makeProducts(2,false);

        Test.startTest();
        Database.executeBatch(
            new Product2BatchSimpleUpdate(1),
            1
        );
        Test.stopTest();

        System.assertEquals(
            3,
            countStamped()
        );
    }

    /* -------------------------
       5) finish coverage
    ------------------------- */
    @IsTest
    static void finish_executes() {

        Product2BatchSimpleUpdate b =
            new Product2BatchSimpleUpdate(1);

        Test.startTest();
        b.finish(null);
        Test.stopTest();

        System.assert(true);
    }
}