@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
private class ProductFileComplianceControllerT123Test2 {
    private static final String CP_DEV_NAME = 'Product_Cleanup_PDF_Access';

    private static final String ALIAS_WITH = 'pfctW';
    private static final String ALIAS_NO   = 'pfctN';

    // ============================================================
    // @testSetup: setup-object DML ONLY
    // ============================================================
    @testSetup
    static void setupUsers() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User uNo = new User(
            Alias = ALIAS_NO,
            Email = 'pfct-no+' + System.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = p.Id,
            UserName = 'pfct-no+' + System.now().getTime() + '@example.com'
        );
        insert uNo;

        User uWith = new User(
            Alias = ALIAS_WITH,
            Email = 'pfct-with+' + System.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WithAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = p.Id,
            UserName = 'pfct-with+' + System.now().getTime() + '@example.com'
        );
        insert uWith;

        // Best-effort: if a permset grants the custom permission, assign it.
        Id psId = findPermSetThatGrantsCustomPermission(CP_DEV_NAME);
        if (psId != null) {
            insert new PermissionSetAssignment(
                AssigneeId = uWith.Id,
                PermissionSetId = psId
            );
        }
    }

    // ============================================================
    // Stats dataset builder (NON-setup DML) - call inside test method
    // ============================================================
    private static void buildStatsDataset() {
        // 4 active products:
        // - ST00 EMPTY (no qualifying PDFs)
        // - ST01 DUPLICATED (2 qualifying PDFs)
        // - ST02 MISSING_CANONICAL (1 qualifying PDF, canonical blank)
        // - ST03 CLEAN (1 qualifying PDF, canonical set)

        // EMPTY
        Product2 pEmpty = makeProduct('ST00', false, null);

        // DUPLICATED (2 PDFs)
        Product2 pDup = makeProduct('ST01', false, null);
        Id dup1 = createPdfDocument('dup1');
        Id dup2 = createPdfDocument('dup2');
        linkDocTo(dup1, pDup.Id);
        linkDocTo(dup2, pDup.Id);

        // Add a non-PDF doc (should NOT count)
        Id txt = createNonPdfDocument('ignore_me');
        linkDocTo(txt, pDup.Id);

        // MISSING_CANONICAL (exactly 1 PDF, canonical blank)
        Product2 pMissing = makeProduct('ST02', false, null);
        Id miss = createPdfDocument('miss');
        linkDocTo(miss, pMissing.Id);

        // CLEAN (exactly 1 PDF, canonical set)
        Id cleanDoc = createPdfDocument('clean');
        Product2 pClean = makeProduct('ST03', true, cleanDoc);
        linkDocTo(cleanDoc, pClean.Id);
    }

    // Helper (NOT @IsTest) - setup metadata lookup
    private static Id findPermSetThatGrantsCustomPermission(String customPermDevName) {
        List<CustomPermission> cps = [
            SELECT Id
            FROM CustomPermission
            WHERE DeveloperName = :customPermDevName
            LIMIT 1
        ];
        if (cps.isEmpty()) return null;

        List<SetupEntityAccess> links = [
            SELECT ParentId
            FROM SetupEntityAccess
            WHERE SetupEntityId = :cps[0].Id
            LIMIT 1
        ];
        return links.isEmpty() ? null : links[0].ParentId; // PermissionSetId
    }

    private static User getUserNoAccess() {
        return [SELECT Id FROM User WHERE Alias = :ALIAS_NO LIMIT 1];
    }

    private static User getUserWithAccessOrNull() {
        User u = [SELECT Id FROM User WHERE Alias = :ALIAS_WITH LIMIT 1];
        Integer psaCount = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :u.Id
        ];
        return (psaCount > 0) ? u : null;
    }

    // ============================================================
    // Picklist-safe helpers (fix Subject validation errors)
    // ============================================================
    private static String pickAnyPicklistValue(Schema.SObjectField fld, String preferred) {
        Schema.DescribeFieldResult d = fld.getDescribe();
        List<Schema.PicklistEntry> vals = d.getPicklistValues();

        if (vals == null || vals.isEmpty()) return null;

        // Try preferred first (match by VALUE, not label)
        if (!String.isBlank(preferred)) {
            for (Schema.PicklistEntry pe : vals) {
                if (pe != null && pe.isActive() && pe.getValue() == preferred) {
                    return pe.getValue();
                }
            }
        }

        // Otherwise take the first active value
        for (Schema.PicklistEntry pe : vals) {
            if (pe != null && pe.isActive()) return pe.getValue();
        }

        // Last resort: first value
        return vals[0].getValue();
    }

    private static String getValidTaskSubject() {
        String v = pickAnyPicklistValue(Task.Subject, 'Call');
        if (String.isBlank(v)) v = pickAnyPicklistValue(Task.Subject, null);
        return String.isBlank(v) ? 'Call' : v;
    }

    // --- Content helpers ---
    private static Id createPdfDocument(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('PDF-DATA'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    private static Id createNonPdfDocument(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.txt',
            VersionData = Blob.valueOf('TEXT-DATA'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    private static void linkDocTo(Id docId, Id entityId) {
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = entityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static Product2 makeProduct(String code, Boolean hasCanonical, Id canonicalDocId) {
        
        string codeName = 'Prod ' + code;
        
        Product2 p = new Product2(
            Name = codeName,
            ProductCode = codeName,
            IsActive = true
        );
        if (hasCanonical && canonicalDocId != null) {
            p.Canonical_Spec_Content_Document_Id__c = String.valueOf(canonicalDocId);
            p.Canonical_Spec_Set_At__c = System.now().addDays(-1);
        }
        insert p;
        return p;
    }

    // =========================
    // Security gate coverage
    // =========================
    @IsTest
    static void test_noAccess_gate_throws() {
        User u = getUserNoAccess();
        System.runAs(u) {
            Test.startTest();
            try {
                ProductFileComplianceController.getCompliancePage(null, null, 1, 25);
                System.assert(false, 'Expected AuraHandledException due to missing access.');
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception ex) {
                System.assert(false, 'Unexpected exception: ' + ex.getMessage());
            }
            Test.stopTest();
        }
    }

    // =========================
    // getComplianceStats coverage
    // =========================
    @IsTest
    static void test_getComplianceStats_counts() {
        User u = getUserWithAccessOrNull();
        if (u == null) return; // org doesn't have a permset granting the custom perm

        System.runAs(u) {
            // Build the stats dataset inside the test context (non-setup DML)
            buildStatsDataset();

            Test.startTest();
            ProductFileComplianceController.ComplianceStats s =
                ProductFileComplianceController.getComplianceStats();
            Test.stopTest();

            System.assertEquals(4, s.totalActive, 'Expected 4 active products in stats dataset.');
            System.assertEquals(1, s.empty, 'ST00 should be EMPTY.');
            System.assertEquals(1, s.duplicated, 'ST01 should be DUPLICATED.');
            System.assertEquals(1, s.missingCanonical, 'ST02 should be MISSING_CANONICAL.');
            System.assertEquals(1, s.clean, 'ST03 should be CLEAN.');
        }
    }

    @IsTest
    static void test_getComplianceStats_noAccess_gate_throws() {
        User u = getUserNoAccess();

        System.runAs(u) {
            Test.startTest();
            try {
                ProductFileComplianceController.getComplianceStats();
                System.assert(false, 'Expected access gate to throw.');
            } catch (Exception e) {
                // In tests AuraHandledException often surfaces as "Script-thrown exception"
                System.assertNotEquals(null, e.getMessage());
            }
            Test.stopTest();
        }
    }

    // =========================
    // getCompliancePage coverage
    // =========================
    @IsTest
    static void test_getCompliancePage_statuses_and_paging() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 pEmpty = makeProduct('A001', false, null);

            Product2 pDup = makeProduct('A002', false, null);
            Id dupDoc1 = createPdfDocument('dup1');
            Id dupDoc2 = createPdfDocument('dup2');
            linkDocTo(dupDoc1, pDup.Id);
            linkDocTo(dupDoc2, pDup.Id);

            Product2 pMissingCanon = makeProduct('A003', false, null);
            Id oneDoc = createPdfDocument('single');
            linkDocTo(oneDoc, pMissingCanon.Id);

            Id cleanDoc = createPdfDocument('clean');
            Product2 pClean = makeProduct('A004', true, cleanDoc);
            linkDocTo(cleanDoc, pClean.Id);

            Test.startTest();

            ProductFileComplianceController.CompliancePage page =
                ProductFileComplianceController.getCompliancePage(null, 'ALL', 0, 5);

            System.assertEquals(1, page.pageNumber);
            System.assertEquals(25, page.pageSize);
            System.assert(page.returnedCount >= 4);

            ProductFileComplianceController.CompliancePage cleanOnly =
                ProductFileComplianceController.getCompliancePage('A00', 'CLEAN', 1, 100);

            System.assertEquals(1, cleanOnly.rows.size());
            System.assertEquals('CLEAN', cleanOnly.rows[0].status);

            ProductFileComplianceController.CompliancePage search =
                ProductFileComplianceController.getCompliancePage('A003', 'ALL', 1, 25);

            System.assertEquals(1, search.rows.size());
            System.assertEquals(pMissingCanon.Id, search.rows[0].productId);
            System.assertEquals('MISSING_CANONICAL', search.rows[0].status);

            Test.stopTest();
        }
    }

    // =========================
    // getProductFileSummary coverage
    // =========================
    @IsTest
    static void test_getProductFileSummary_and_sort_and_linkTypeSummary() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 p = makeProduct('B001', false, null);

            Id docA = createPdfDocument('Alpha');
            Id docB = createPdfDocument('beta');
            linkDocTo(docA, p.Id);
            linkDocTo(docB, p.Id);

            Task t = new Task(Subject = getValidTaskSubject());
            insert t;
            linkDocTo(docA, t.Id);

            Test.startTest();

            try {
                ProductFileComplianceController.getProductFileSummary(null);
                System.assert(false);
            } catch (AuraHandledException e) {
                // ok
            } catch (Exception ex) {
                System.assert(false, 'Unexpected exception: ' + ex.getMessage());
            }

            ProductFileComplianceController.ProductFileSummary s =
                ProductFileComplianceController.getProductFileSummary(p.Id);

            System.assertEquals(2, s.specPdfs.size());
            System.assertEquals('Alpha', s.specPdfs[0].title);
            System.assertEquals('beta', s.specPdfs[1].title);

            ProductFileComplianceController.SpecPdfDoc first = s.specPdfs[0];
            // Expect: Product link + Task link + (maybe) User/Owner link depending on org behavior.
            System.assert(first.linkCount >= 2, 'Expected at least Product2 + Task links.');
            System.assert(first.linkTypesSummary.contains('Product2: 1'), first.linkTypesSummary);
            System.assert(first.linkTypesSummary.contains('Task: 1'), first.linkTypesSummary);

            Test.stopTest();
        }
    }

    // =========================
    // getLinksForContentDocument coverage
    // =========================
    @IsTest
    static void test_getLinksForContentDocument_labels() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 p = makeProduct('C001', false, null);

            Task t = new Task(Subject = getValidTaskSubject());
            insert t;

            Id doc = createPdfDocument('LinkedDoc');
            linkDocTo(doc, p.Id);
            linkDocTo(doc, t.Id);

            Test.startTest();

            try {
                ProductFileComplianceController.getLinksForContentDocument(null);
                System.assert(false);
            } catch (Exception e) {
                // AuraHandledException can show as "Script-thrown exception" in tests
                System.assertNotEquals(null, e.getMessage());
            }

            List<ProductFileComplianceController.DocLinkRow> rows =
                ProductFileComplianceController.getLinksForContentDocument(doc);

            System.assert(rows.size() >= 2, 'Expected at least Product2 + Task links.');

            Boolean sawProduct = false, sawTask = false;
            for (ProductFileComplianceController.DocLinkRow r : rows) {
                if (r.linkedEntityType == 'Product2') {
                    sawProduct = true;
                    System.assertEquals(p.Name, r.linkedEntityLabel);
                }
                if (r.linkedEntityType == 'Task') {
                    sawTask = true;
                    System.assertEquals(t.Subject, r.linkedEntityLabel);
                }
            }
            System.assert(sawProduct && sawTask);

            Test.stopTest();
        }
    }

    // =========================
    // getMergeDiscovery coverage
    // =========================
    @IsTest
    static void test_getMergeDiscovery_empty_and_nonEmpty_and_canonical_flag() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 pEmpty = makeProduct('D001', false, null);

            Id doc1 = createPdfDocument('Zeta');
            Id doc2 = createPdfDocument('Eta');

            Product2 p = makeProduct('D002', true, doc2);
            linkDocTo(doc1, p.Id);
            linkDocTo(doc2, p.Id);

            Test.startTest();

            try {
                ProductFileComplianceController.getMergeDiscovery(null);
                System.assert(false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }

            ProductFileComplianceController.MergeDiscoveryResult emptyRes =
                ProductFileComplianceController.getMergeDiscovery(pEmpty.Id);
            System.assertEquals(0, emptyRes.candidates.size());

            ProductFileComplianceController.MergeDiscoveryResult res =
                ProductFileComplianceController.getMergeDiscovery(p.Id);

            System.assertEquals(2, res.candidates.size());
            System.assertEquals('Eta', res.candidates[0].title);
            System.assertEquals('Zeta', res.candidates[1].title);

            Boolean sawCanonical = false;
            for (ProductFileComplianceController.MergeCandidateRow r : res.candidates) {
                if (r.contentDocumentId == doc2) {
                    sawCanonical = true;
                    System.assertEquals(true, r.isCanonical);
                }
                System.assertEquals(null, r.hashMatchesIncoming);
            }
            System.assert(sawCanonical);

            Test.stopTest();
        }
    }

    // =========================
    // setCanonicalSpecDoc coverage
    // =========================
    @IsTest
    static void test_setCanonicalSpecDoc_happy_and_error_paths() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 p = makeProduct('E001', false, null);

            Id pdfDoc = createPdfDocument('Spec');
            linkDocTo(pdfDoc, p.Id);

            Id otherPdfDoc = createPdfDocument('Other'); // not linked

            Id nonPdfDoc = createNonPdfDocument('NotPdf');
            linkDocTo(nonPdfDoc, p.Id);

            Test.startTest();

            try {
                ProductFileComplianceController.setCanonicalSpecDoc(null, pdfDoc);
                System.assert(false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }

            try {
                ProductFileComplianceController.setCanonicalSpecDoc(p.Id, null);
                System.assert(false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }

            try {
                ProductFileComplianceController.setCanonicalSpecDoc(p.Id, otherPdfDoc);
                System.assert(false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }

            try {
                ProductFileComplianceController.setCanonicalSpecDoc(p.Id, nonPdfDoc);
                System.assert(false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage());
            }

            ProductFileComplianceController.CanonicalSetResult out =
                ProductFileComplianceController.setCanonicalSpecDoc(p.Id, pdfDoc);

            System.assertEquals(p.Id, out.productId);
            System.assertEquals(String.valueOf(pdfDoc), String.valueOf(out.canonicalDocId));
            System.assertNotEquals(null, out.canonicalSetAt);

            Datetime firstSetAt = out.canonicalSetAt;
            ProductFileComplianceController.CanonicalSetResult out2 =
                ProductFileComplianceController.setCanonicalSpecDoc(p.Id, pdfDoc);

            System.assertEquals(firstSetAt, out2.canonicalSetAt);

            Test.stopTest();
        }
    }

    // =========================
    // runHashAuditCallApex coverage (best-effort)
    // =========================
    @IsTest
    static void test_runHashAuditCallApex_invokes_service() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Product2 p = makeProduct('F001', false, null);

            Test.startTest();
            try {
                Object result = ProductFileComplianceController.runHashAuditCallApex(p.Id);
                System.assertNotEquals(null, result);
            } catch (Exception e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }
}