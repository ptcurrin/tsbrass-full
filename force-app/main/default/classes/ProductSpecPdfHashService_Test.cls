@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
private class ProductSpecPdfHashService_Test {

    // -------------------------
    // Data helpers
    // -------------------------
    public static String randomPicklistValue(SObjectType sobType, String fieldApiName) {
        Schema.DescribeFieldResult dfr =
            sobType.getDescribe()
                   .fields.getMap()
                   .get(fieldApiName)
                   .getDescribe();

        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();

        // Filter to active values only
        List<String> active = new List<String>();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                active.add(pe.getValue());
                system.debug('%%%% ' + pe.getValue());
            }
        }

        if (active.isEmpty()) {
            throw new AuraHandledException(
                'No active picklist values for ' + fieldApiName
            );
        }

        Integer idx = Math.mod(
            Math.abs(Crypto.getRandomInteger()),
            active.size()
        );

        system.debug('%%%% idx: ' + idx);
        
        return active[idx];
    }
    
    
    private static Product2 makeProduct(String code, String specUrl, Id canonicalDocId) {
        
        string codeName = 'Prod ' + code;
        
        Product2 p = new Product2(
            Name = codeName,
            ProductCode = codeName,
            IsActive = true,
            Specification__c = specUrl
        );
        if (canonicalDocId != null) {
            p.Canonical_Spec_Content_Document_Id__c = String.valueOf(canonicalDocId);
        }
        insert p;
        return p;
    }

    private static Id createPdfDocWithTitle(String titleWithOrWithoutExt) {
        // IMPORTANT: Your service expects Title to include ".pdf" for the chosen doc guard.
        // We'll accept either and normalize to include .pdf in Title.
        String t = titleWithOrWithoutExt;
        if (t == null) t = 'file.pdf';
        if (!t.toLowerCase().endsWith('.pdf')) t = t + '.pdf';

        ContentVersion cv = new ContentVersion(
            Title = t,
            PathOnClient = t,                 // PathOnClient is only needed to create the file
            VersionData = Blob.valueOf('PDF_BYTES_' + t),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    private static void linkDoc(Id docId, Id entityId) {
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = entityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static void assertAuraHandled(Exception e) {
        // In some orgs/tests AuraHandledException message can surface as "Script-thrown exception"
        // so we only assert type here.
        System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException, got: ' + e);
    }

    // -------------------------
    // Tests
    // -------------------------

    @IsTest
    static void test_auditProduct_nullProductId_throws() {
        Test.startTest();
        try {
            ProductSpecPdfHashService.auditProduct(null);
            System.assert(false, 'Expected AuraHandledException for null productId.');
        } catch (Exception e) {
            assertAuraHandled(e);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_auditProduct_incomingNull_returnsRecommendation() {
        // incoming fetch returns null when Specification__c is blank
        Product2 p = makeProduct('HS001', null, null);

        Test.startTest();
        ProductSpecPdfHashService.AuditResult res = ProductSpecPdfHashService.auditProduct(p.Id);
        Test.stopTest();

        System.assertEquals(p.Id, res.productId);
        System.assertEquals('Prod HS001', res.productCode);
        System.assertEquals(0, res.incomingSize);
        System.assertEquals(null, res.incomingSha256);
        System.assert(res.recommendation != null && res.recommendation.contains('could not be fetched'));
        System.assertNotEquals(null, res.rows);
        System.assertEquals(0, res.rows.size(), 'No rows when incoming cannot be fetched.');
    }

    @IsTest
    static void test_auditProduct_prefersCanonical_whenLinked_and_hashes_and_summarizesTypes() {
        // NOTE: In tests, fetchIncomingPdfBlob() returns Blob.valueOf('TEST_PDF_BYTES')
        // So incomingSha256 is deterministic. We'll set the chosen PDF VersionData to the same bytes to force a match.
        Product2 p = makeProduct('HS002', 'https://example.com/spec.pdf', null);

        // Create canonical doc + link to product
        // Make its VersionData equal to incoming ('TEST_PDF_BYTES') so hash matches.
        String title = 'hs002.pdf';
        ContentVersion cvCanon = new ContentVersion(
            Title = title,
            PathOnClient = title,
            VersionData = Blob.valueOf('TEST_PDF_BYTES'),
            IsMajorVersion = true
        );
        insert cvCanon;
        cvCanon = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvCanon.Id];
        Id canonicalDocId = cvCanon.ContentDocumentId;

        // Set canonical on product
        p.Canonical_Spec_Content_Document_Id__c = String.valueOf(canonicalDocId);
        update p;

        // Link canonical to Product + Account to exercise type breakdown
        linkDoc(canonicalDocId, p.Id);

        
        String val = randomPicklistValue(
            Account.SObjectType,
            'Salesman__c'
        ); 
        system.debug('%%%% val: ' + val);
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Rep Agency';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;   
        
        
        
        Account a = new Account(Name = 'HashSvc Acct',
                               salesman__c = val,
                                 SLSMan_Rep_Agency__c  = a1.Id
                               );
        insert a;
        linkDoc(canonicalDocId, a.Id);

        Test.startTest();
        ProductSpecPdfHashService.AuditResult res = ProductSpecPdfHashService.auditProduct(p.Id);
        Test.stopTest();

        System.assertEquals(1, res.totalCandidates);
        System.assertEquals(1, res.hashedCount);
        System.assertEquals(false, res.truncated);
        System.assertNotEquals(null, res.incomingSha256);
        System.assertEquals(Blob.valueOf('TEST_PDF_BYTES').size(), res.incomingSize);

        System.assertNotEquals(null, res.rows);
        System.assertEquals(1, res.rows.size());

        ProductSpecPdfHashService.AuditRow row = res.rows[0];
        System.assertEquals(canonicalDocId, row.contentDocumentId);
        System.assert(row.title != null && row.title.toLowerCase().endsWith('.pdf'));
        System.assertEquals(3, row.linkCount, 'Product2 + Account links');
        System.assert(row.linkTypesSummary.contains('Account: 1'), row.linkTypesSummary);
        System.assert(row.linkTypesSummary.contains('Product2: 1'), row.linkTypesSummary);

        System.assertEquals(true, row.matchesIncoming, 'Expected hash match when VersionData == TEST_PDF_BYTES');
        System.assert(res.recommendation != null && res.recommendation.contains('matches incoming'));
    }

    @IsTest
    static void test_auditProduct_fallbackToNewestMatchingTitle_whenNoCanonical() {
        // No canonical set, but two linked PDFs: one matches expected title, one not.
        // It should choose the newest matching title.
        Product2 p = makeProduct('HS003', 'https://example.com/spec.pdf', null);

        // Create a non-matching doc
        Id otherDoc = createPdfDocWithTitle('something_else.pdf');
        linkDoc(otherDoc, p.Id);

        // Create matching-title doc (expected: hs003.pdf)
        // Make it NOT match incoming bytes so we hit "does NOT match".
        String title = 'Prod HS003.PDF'; // case-insensitive match
        ContentVersion cvMatch = new ContentVersion(
            Title = title,
            PathOnClient = title,
            VersionData = Blob.valueOf('DIFFERENT_BYTES'),
            IsMajorVersion = true
        );
        insert cvMatch;
        cvMatch = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvMatch.Id];
        Id matchingDocId = cvMatch.ContentDocumentId;
        linkDoc(matchingDocId, p.Id);

        Test.startTest();
        ProductSpecPdfHashService.AuditResult res = ProductSpecPdfHashService.auditProduct(p.Id);
        Test.stopTest();

        System.assertEquals(1, res.totalCandidates);
        System.assertEquals(1, res.rows.size());

        ProductSpecPdfHashService.AuditRow row = res.rows[0];
        System.assertEquals(matchingDocId, row.contentDocumentId, 'Should choose newest matching title doc when no canonical.');
        System.assertEquals(false, row.matchesIncoming, 'DIFFERENT_BYTES should not match TEST_PDF_BYTES.');
        System.assert(res.recommendation != null && res.recommendation.contains('does NOT match'));
    }

    @IsTest
    static void test_auditProduct_noCanonical_and_noMatchingTitle_returnsEarly() {
        Product2 p = makeProduct('HS004', 'https://example.com/spec.pdf', null);

        // Link a PDF that does NOT match expectedTitle (hs004.pdf)
        Id doc = createPdfDocWithTitle('not_the_expected_name.pdf');
        linkDoc(doc, p.Id);

        Test.startTest();
        ProductSpecPdfHashService.AuditResult res = ProductSpecPdfHashService.auditProduct(p.Id);
        Test.stopTest();

        System.assertEquals(0, res.totalCandidates);
        System.assert(res.recommendation != null && res.recommendation.contains('No canonical spec PDF is set'));
        System.assertEquals(0, res.rows.size(), 'No chosen doc => no rows.');
        System.assertNotEquals(null, res.incomingSha256, 'Still returns incoming hash for UI.');
    }

    @IsTest
    static void test_auditProduct_canonicalSetButNotLinked_fallsBackOrReturnsNoMatch() {
        Product2 p = makeProduct('HS005', 'https://example.com/spec.pdf', null);

        // Create a canonical doc but do NOT link it to Product => service must ignore it.
        Id canonicalDocNotLinked = createPdfDocWithTitle('hs005.pdf');

        p.Canonical_Spec_Content_Document_Id__c = String.valueOf(canonicalDocNotLinked);
        update p;

        // Also link a different PDF that *does* match expected title so fallback can find it.
        // (If you remove this doc, the method will return the "no linked PDF matched expected title" early path.)
        ContentVersion cvMatch = new ContentVersion(
            Title = 'prod hs005.pdf',
            PathOnClient = 'prod hs005.pdf',
            VersionData = Blob.valueOf('DIFFERENT_BYTES_2'),
            IsMajorVersion = true
        );
        insert cvMatch;
        cvMatch = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvMatch.Id];
        Id fallbackDocId = cvMatch.ContentDocumentId;

        linkDoc(fallbackDocId, p.Id);

        Test.startTest();
        ProductSpecPdfHashService.AuditResult res = ProductSpecPdfHashService.auditProduct(p.Id);
        Test.stopTest();

        System.assertEquals(1, res.totalCandidates);
        System.assertEquals(fallbackDocId, res.rows[0].contentDocumentId, 'Should ignore unlinked canonical and fall back to matching title.');
    }
}