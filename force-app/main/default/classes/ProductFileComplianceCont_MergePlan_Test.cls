@IsTest
private class ProductFileComplianceCont_MergePlan_Test {
    private static final String CP_DEV_NAME = 'Product_Cleanup_PDF_Access';
    private static final String ALIAS_WITH  = 'mpWith';
    private static final String ALIAS_NO    = 'mpNo';

    // ----------------------------
    // Setup users (setup-object DML only)
    // ----------------------------
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
            Email = 'mp-no+' + System.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = p.Id,
            UserName = 'mp-no+' + System.now().getTime() + '@example.com'
        );
        insert uNo;

        User uWith = new User(
            Alias = ALIAS_WITH,
            Email = 'mp-with+' + System.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WithAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = p.Id,
            UserName = 'mp-with+' + System.now().getTime() + '@example.com'
        );
        insert uWith;

        // Best-effort: assign a PermissionSet that grants the Custom Permission, if one exists.
        Id psId = findPermSetThatGrantsCustomPermission(CP_DEV_NAME);
        if (psId != null) {
            insert new PermissionSetAssignment(AssigneeId = uWith.Id, PermissionSetId = psId);
        }
    }

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
        return links.isEmpty() ? null : links[0].ParentId;
    }

    private static User getUserNoAccess() {
        return [SELECT Id FROM User WHERE Alias = :ALIAS_NO LIMIT 1];
    }

    private static User getUserWithAccessOrNull() {
        User u = [SELECT Id FROM User WHERE Alias = :ALIAS_WITH LIMIT 1];
        Integer psa = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :u.Id];
        return (psa > 0) ? u : null;
    }

    // ----------------------------
    // Data helpers (non-setup objects)
    // ----------------------------
    private static Product2 makeProduct(String code) {
        
        string nameString = 'Prod ' + code;
        
        Product2 p = new Product2(
            Name = nameString,
            ProductCode = nameString,
            IsActive = true
        );
        insert p;
        return p;
    }

    // IMPORTANT: your code checks cv.Title endswith ".PDF" — so Title MUST include ".pdf"
    private static Id createPdfDocWithTitle(String titleIncludingDotPdf) {
        ContentVersion cv = new ContentVersion(
            Title = titleIncludingDotPdf,
            PathOnClient = titleIncludingDotPdf, // also include .pdf here
            VersionData = Blob.valueOf('PDF-DATA'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    private static Id createTxtDoc(String title) {
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

    private static void linkDoc(Id docId, Id entityId) {
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = entityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    // Picklist-safe Task Subject helper (keeps Task DML stable across orgs)
    private static String pickAnyPicklistValue(Schema.SObjectField fld, String preferred) {
        Schema.DescribeFieldResult d = fld.getDescribe();
        List<Schema.PicklistEntry> vals = d.getPicklistValues();
        if (vals == null || vals.isEmpty()) return null;

        if (!String.isBlank(preferred)) {
            for (Schema.PicklistEntry pe : vals) {
                if (pe != null && pe.isActive() && pe.getValue() == preferred) return pe.getValue();
            }
        }
        for (Schema.PicklistEntry pe : vals) {
            if (pe != null && pe.isActive()) return pe.getValue();
        }
        return vals[0].getValue();
    }

    private static String getValidTaskSubject() {
        String v = pickAnyPicklistValue(Task.Subject, 'Call');
        if (String.isBlank(v)) v = pickAnyPicklistValue(Task.Subject, null);
        return String.isBlank(v) ? 'Call' : v;
    }

    // ----------------------------
    // Tests
    // ----------------------------

    @IsTest
    static void test_getMergePlan_noAccess_gate_throws() {
        User u = getUserNoAccess();
        System.runAs(u) {
            Test.startTest();
            try {
                ProductFileComplianceController.getMergePlan(null, null);
                System.assert(false, 'Expected AuraHandledException (no access).');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void test_getMergePlan_happyPath_counts_and_rows() {
        User u = getUserWithAccessOrNull();
        if (u == null) return; // if your org has no assignable permset granting CP, skip (gate is covered above)

        System.runAs(u) {
            // Product + expected filename rule
            Product2 p = makeProduct('P100');

            String expectedTitle = (p.ProductCode + '.pdf').toLowerCase(); // "p100.pdf"

            // Canonical doc MUST:
            // - be linked to product (canonicalLinkCount check)
            // - have latest ContentVersion: FileExtension='pdf' AND Title endswith ".PDF"
            Id canonicalDocId = createPdfDocWithTitle(expectedTitle);
            linkDoc(canonicalDocId, p.Id);

            // Duplicate docs linked to product:
            // Eligible duplicate: Title exactly equals expectedTitle (case-insensitive) + PDF
            Id dupEligible = createPdfDocWithTitle(expectedTitle);
            linkDoc(dupEligible, p.Id);

            // Ineligible duplicate (still qualifies as dashboard spec pdf, but fails strict title match)
            Id dupIneligible = createPdfDocWithTitle('somethingelse.pdf');
            linkDoc(dupIneligible, p.Id);

            // Non-qualifying doc (not pdf) - should not be treated as a duplicate at all
            Id nonPdf = createTxtDoc('notes');
            linkDoc(nonPdf, p.Id);

            //insert rep agency account
            //
            User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
            //
            Account a1 = new Account();
            a1.Name = 'Test Rep Agency';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            system.runas(integrationUser){insert a1;} 
            
            
            
            
            // Add a couple of non-protected linked entities for eligible duplicate
            Account a = new Account(Name = 'Acme',
                                   SLSMan_Rep_Agency__c  = a1.Id);
            insert a;

            Opportunity o = new Opportunity(
                Name = 'Opp1',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                AccountId = a.Id
            );
            insert o;

            // Link eligible duplicate to Account + Opportunity
            linkDoc(dupEligible, a.Id);
            linkDoc(dupEligible, o.Id);

            // Make canonical ALREADY linked to Account with same ShareType/Visibility to force skipInsert
            linkDoc(canonicalDocId, a.Id);

            // Try to add a User-linked CDL to hit the "005 protected" branch (best-effort).
            // If your org forbids this in tests, we swallow and continue.
            try {
                linkDoc(dupEligible, UserInfo.getUserId()); // 005...
            } catch (DmlException ex) {
                System.assert(true);
            }

            Test.startTest();
            ProductFileComplianceController.MergePlanResult plan =
                ProductFileComplianceController.getMergePlan(p.Id, canonicalDocId);
            Test.stopTest();

            System.assertEquals(p.Id, plan.productId);
            System.assertEquals(canonicalDocId, plan.canonicalDocId);
            System.assertEquals(expectedTitle, plan.expectedTitle);

            // Duplicate doc classification:
            // - eligible dup: expectedTitle => eligible
            // - ineligible dup: different title => ineligible
            System.assertEquals(1, plan.eligibleDuplicateDocCount, 'Expected 1 eligible duplicate doc.');
            System.assertEquals(1, plan.ineligibleDuplicateDocCount, 'Expected 1 ineligible duplicate doc.');
            System.assertEquals(2, plan.duplicateDocs.size(), 'Expected two duplicate candidates (eligible + ineligible).');

            // Rows: we should get:
            // - Product2 link is protected => row exists but willDelete=false/willInsert=false (skipped)
            // - Account link => delete planned, insert skipped (canonical already linked)
            // - Opportunity link => delete planned, insert planned
            //
            // Plus possibly a User-protected row if that link was successfully created.
            System.assert(plan.totalRows >= 3, 'Expected at least Product2+Account+Opp rows.');

            // Verify counts at least for the non-protected inserts/deletes:
            // Deletes should include Account + Opportunity (2)
            // Inserts should include Opportunity only (1) because Account is already linked
            System.assertEquals(2, plan.deleteCount, 'Expected 2 planned deletes (Account+Opportunity).');
            System.assertEquals(1, plan.insertCount, 'Expected 1 planned insert (Opportunity).');
            System.assertEquals(1, plan.skipInsertCount, 'Expected 1 skipped insert (Account already linked).');

            // Spot-check the per-row behavior
            Boolean sawProtectedProduct = false;
            Boolean sawAccountMoveDeleteOnly = false;
            Boolean sawOppMoveInsertDelete = false;

            for (ProductFileComplianceController.MergePlanRow r : plan.rows) {
                if (r == null) continue;

                if (r.linkedEntityId == p.Id) {
                    sawProtectedProduct = true;
                    System.assertEquals(true, r.skippedBecauseProtectedEntity);
                    System.assertEquals(false, r.willDelete);
                    System.assertEquals(false, r.willInsert);
                } else if (r.linkedEntityId == a.Id) {
                    // canonical already linked => delete-only
                    sawAccountMoveDeleteOnly = true;
                    System.assertEquals(true, r.willDelete);
                    System.assertEquals(false, r.willInsert);
                } else if (r.linkedEntityId == o.Id) {
                    // needs insert + delete
                    sawOppMoveInsertDelete = true;
                    System.assertEquals(true, r.willDelete);
                    System.assertEquals(true, r.willInsert);
                }
            }

            System.assertEquals(true, sawProtectedProduct, 'Expected to see protected Product2 row.');
            System.assertEquals(true, sawAccountMoveDeleteOnly, 'Expected Account row (delete-only).');
            System.assertEquals(true, sawOppMoveInsertDelete, 'Expected Opportunity row (insert+delete).');
        }
    }

    @IsTest
    static void test_getMergePlan_errorPaths_basicGuards() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        System.runAs(u) {
            Test.startTest();

            // null productId
            try {
                ProductFileComplianceController.getMergePlan(null, (Id)'069000000000000AAA');
                System.assert(false);
            } catch (AuraHandledException e) { System.assert(true); }

            // null canonicalDocId
            try {
                ProductFileComplianceController.getMergePlan((Id)'01t000000000000AAA', null);
                System.assert(false);
            } catch (AuraHandledException e) { System.assert(true); }

            Test.stopTest();
        }
    }

    // ------------------------------------------------------------
    // (1) rollbackOnly=true dry-run (should rollback even on success)
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_dryRun_rollsBack() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;
        
        
        
        //insert rep agency account
            //
            User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
            //
            Account a1 = new Account();
            a1.Name = 'Test Rep Agency';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            system.runas(integrationUser){insert a1;} 
           

        System.runAs(u) {
            Product2 p = makeProduct('MP200');

            
            
            Account a = new Account(Name = 'MergePlan Acct',
                                    SLSMan_Rep_Agency__c = a1.Id);
            insert a;
            
            Id canonicalDocId = createPdfDocWithTitle('mp200.pdf');
            Id duplicateDocId = createPdfDocWithTitle('mp200.pdf');
            
            linkDoc(canonicalDocId, p.Id);
            linkDoc(duplicateDocId, p.Id);


            // duplicate doc linked to Account (this will be deleted in the plan)
            linkDoc(duplicateDocId, a.Id);

            Id dupCdlId = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
                LIMIT 1
            ].Id;

            List<Map<String,Object>> insertLinks = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => a.Id,
                    'shareType'      => 'V',
                    'visibility'     => 'AllUsers'
                }
            };
            List<Id> deleteIds = new List<Id>{ dupCdlId };

            Test.startTest();
            ProductFileComplianceController.MergeExecutionResult dry =
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p.Id,
                    canonicalDocId,
                    duplicateDocId,
                    false,      // deleteDuplicateDoc
                    insertLinks,
                    deleteIds,
                    true,       // rollbackOnly
                    true        // strictAtomic (irrelevant in rollbackOnly mode)
                );
            Test.stopTest();

            System.assertEquals(true, dry.rollbackMode);
            System.assertEquals(true, dry.rolledBack, 'Dry-run should always rollback.');
            System.assertEquals(1, dry.insertedLinksAttempted);
            System.assertEquals(1, dry.insertedLinksSucceeded);
            System.assertEquals(1, dry.deletedLinksAttempted);
            System.assertEquals(1, dry.deletedLinksSucceeded);

            // DB should be unchanged after rollback
            Integer canonicalToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonicalDocId
                AND LinkedEntityId = :a.Id
            ];
            Integer dupToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
            ];
            System.assertEquals(0, canonicalToAcct, 'Dry-run should not persist canonical link.');
            System.assertEquals(1, dupToAcct, 'Dry-run should not delete duplicate link.');
        }
    }

    // ------------------------------------------------------------
    // (2) strictAtomic=true gate-fail path (throw + rollback)
    // Force an insert failure (duplicate CDL) by pre-linking canonical->Account,
    // then attempting to insert it again.
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_strictAtomic_gateFail_throwsAndRollsBack() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;
        
        
        //insert rep agency account
            //
            User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
            //
            Account a1 = new Account();
            a1.Name = 'Test Rep Agency';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            system.runas(integrationUser){insert a1;} 
           
			// SLSMan_Rep_Agency__c = a1.Id
        

        System.runAs(u) {
            Product2 p = makeProduct('MP201');

            Account a = new Account(Name = 'MergePlan Acct 2',
                                   SLSMan_Rep_Agency__c = a1.Id
                                   );
            insert a;

            Id canonicalDocId = createPdfDocWithTitle('mp201.pdf');
            Id duplicateDocId = createPdfDocWithTitle('mp201.pdf');

            // Seed duplicate link that we will try to delete
            linkDoc(duplicateDocId, a.Id);

            // Seed canonical link so the attempted insert will fail as duplicate
            linkDoc(canonicalDocId, a.Id);

            Id dupCdlId = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
                LIMIT 1
            ].Id;

            List<Map<String,Object>> insertLinks = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => a.Id,
                    'shareType'      => 'V',
                    'visibility'     => 'AllUsers'
                }
            };

            Boolean threw = false;

            Test.startTest();
            try {
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p.Id,
                    canonicalDocId,
                    duplicateDocId,
                    false,                 // deleteDuplicateDoc
                    insertLinks,           // will fail (duplicate insert)
                    new List<Id>{dupCdlId},
                    false,                 // rollbackOnly
                    true                   // strictAtomic => rollback + throw
                );
                System.assert(false, 'Expected AuraHandledException on strictAtomic gate fail.');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assertEquals(true, threw);

            // Verify rollback: duplicate link still exists; canonical still exactly one
            Integer canonicalToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonicalDocId
                AND LinkedEntityId = :a.Id
            ];
            Integer dupToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
            ];
            System.assertEquals(1, canonicalToAcct);
            System.assertEquals(1, dupToAcct, 'Should rollback delete due to strictAtomic.');
        }
    }

    // ------------------------------------------------------------
    // (3) strictAtomic=false partial-commit path
    // Same gate-fail (duplicate insert) but strictAtomic=false => no throw,
    // commits successes and returns warnings.
    // Delete should succeed because canonicalExistingKeys allows it.
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_partialCommit_returnsWarnings_andCommitsDelete() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;
        
         //insert rep agency account
            //
            User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
            //
            Account a1 = new Account();
            a1.Name = 'Test Rep Agency';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            system.runas(integrationUser){insert a1;} 
           
			// SLSMan_Rep_Agency__c = a1.Id
        

        System.runAs(u) {
            Product2 p = makeProduct('MP202');

            Account a = new Account(Name = 'MergePlan Acct 3',
                                   SLSMan_Rep_Agency__c = a1.Id);
            insert a;

            Id canonicalDocId = createPdfDocWithTitle('mp202.pdf');
            Id duplicateDocId = createPdfDocWithTitle('mp202.pdf');
            
            linkDoc(canonicalDocId, p.Id);
            linkDoc(duplicateDocId, p.Id);
            

            // Seed duplicate link that we will delete
            linkDoc(duplicateDocId, a.Id);

            // Seed canonical link so insert will fail as duplicate, but delete is still allowed
            linkDoc(canonicalDocId, a.Id);

            Id dupCdlId = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
                LIMIT 1
            ].Id;

            List<Map<String,Object>> insertLinks = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => a.Id,
                    'shareType'      => 'V',
                    'visibility'     => 'AllUsers'
                }
            };

            Test.startTest();
            ProductFileComplianceController.MergeExecutionResult res =
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p.Id,
                    canonicalDocId,
                    duplicateDocId,
                    false,                // deleteDuplicateDoc
                    insertLinks,          // will fail
                    new List<Id>{dupCdlId}, // delete should succeed
                    false,                // rollbackOnly
                    false                 // strictAtomic=false => commit successes, return warnings
                );
            Test.stopTest();

            System.assertEquals(false, res.rollbackMode);
            System.assertEquals(false, res.rolledBack);
            System.assert(res.warnings != null && !res.warnings.isEmpty(), 'Expected warning message on gate fail.');
            System.assertEquals(1, res.insertedLinksAttempted);
            System.assertEquals(0, res.insertedLinksSucceeded, 'Duplicate insert should fail.');
            System.assertEquals(1, res.deletedLinksAttempted);
            System.assertEquals(1, res.deletedLinksSucceeded, 'Delete should succeed.');

            // Verify DB state committed: canonical link still there; duplicate link gone
            Integer canonicalToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonicalDocId
                AND LinkedEntityId = :a.Id
            ];
            Integer dupToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
            ];
            System.assertEquals(1, canonicalToAcct);
            System.assertEquals(0, dupToAcct, 'Duplicate link should be deleted in partial-commit mode.');
        }
    }

    // ------------------------------------------------------------
    // (4) safeToDeleteDoc == true path
    // deleteDuplicateDoc=true AND gate passes => duplicate ContentDocument deleted
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_safeToDeleteDoc_deletesDuplicateDocument() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;

        //insert rep agency account
            //
            User integrationUser = [select Id from User where User.Name='Integration User' limit 1]; 
            //
            Account a1 = new Account();
            a1.Name = 'Test Rep Agency';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            system.runas(integrationUser){insert a1;} 
           
			// SLSMan_Rep_Agency__c = a1.Id
        
        
        System.runAs(u) {
            Product2 p = makeProduct('MP203');

            Account a = new Account(Name = 'SafeToDeleteDoc Acct',
                                   SLSMan_Rep_Agency__c = a1.Id);
            insert a;

            Id canonicalDocId = createPdfDocWithTitle('mp203.pdf');
            Id duplicateDocId = createPdfDocWithTitle('mp203.pdf');
            
            linkDoc(canonicalDocId, p.Id);
            linkDoc(duplicateDocId, p.Id);
            

            // Link duplicate -> Account (this link will be deleted)
            linkDoc(duplicateDocId, a.Id);

            Id dupCdlId = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicateDocId
                AND LinkedEntityId = :a.Id
                LIMIT 1
            ].Id;

            // Plan: insert canonical->Account, delete duplicate->Account, then delete duplicate doc
            List<Map<String,Object>> insertLinks = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => a.Id,
                    'shareType'      => 'V',
                    'visibility'     => 'AllUsers'
                }
            };
            List<Id> deleteIds = new List<Id>{ dupCdlId };

            Test.startTest();
            ProductFileComplianceController.MergeExecutionResult res =
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p.Id,
                    canonicalDocId,
                    duplicateDocId,
                    true,       // deleteDuplicateDoc => safeToDeleteDoc can be true
                    insertLinks,
                    deleteIds,
                    false,      // rollbackOnly
                    true        // strictAtomic (doesn't matter; gate should pass)
                );
            Test.stopTest();

            System.assertEquals(false, res.rolledBack, 'Should not rollback on a fully successful run.');
            System.assertEquals(true, res.deletedDuplicateDoc, 'Expected duplicate ContentDocument deletion.');
            System.assertEquals(1, res.deletedDocuments, 'Expected exactly 1 ContentDocument deleted.');

            Integer dupDocStillThere = [
                SELECT COUNT() FROM ContentDocument WHERE Id = :duplicateDocId
            ];
            System.assertEquals(0, dupDocStillThere, 'Duplicate ContentDocument should be deleted.');

            // Sanity: canonical link should exist now
            Integer canonicalToAcct = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonicalDocId
                AND LinkedEntityId = :a.Id
            ];
            System.assertEquals(1, canonicalToAcct, 'Canonical should be linked to Account after merge.');
        }
    }

    
    // ------------------------------------------------------------
    // (5A) strictAtomic=true gate fail (duplicate insert) => throw + rollback
    // NOTE: exactly ONE startTest/stopTest per test method.
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_gateFail_strictAtomic_throwsAndRollsBack() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;
        
        System.runAs(u) {
            // Use Task as the linked entity to avoid cross-reference access issues in prod.
            Task t1 = new Task(Subject = getValidTaskSubject());
            insert t1;
            
            Product2 p1 = makeProduct('MP204');
            
            Id canonical1 = createPdfDocWithTitle('mp204.pdf');
            Id duplicate1 = createPdfDocWithTitle('mp204.pdf');
            
            // Seed duplicate link we will delete
            linkDoc(duplicate1, t1.Id);
            
            // Seed canonical link so the attempted insert will FAIL (duplicate insert)
            linkDoc(canonical1, t1.Id);
            
            Id dupCdl1 = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicate1
                AND LinkedEntityId = :t1.Id
                LIMIT 1
            ].Id;
            
            List<Map<String,Object>> inserts1 = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => t1.Id,
                        'shareType'      => 'V',
                        'visibility'     => 'AllUsers'
                        }
            };
                List<Id> deletes1 = new List<Id>{ dupCdl1 };
                    
                    Boolean threw = false;
            
            Test.startTest();
            try {
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p1.Id,
                    canonical1,
                    duplicate1,
                    false,               // deleteDuplicateDoc
                    inserts1,            // will fail (duplicate insert)
                    deletes1,            // delete would succeed, but strictAtomic rolls back on gate fail
                    false,               // rollbackOnly
                    true                 // strictAtomic => rollback + throw
                );
                System.assert(false, 'Expected AuraHandledException due to gate fail (strictAtomic).');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            
            System.assertEquals(true, threw);
            
            // Verify rollback: duplicate link should still exist; canonical link remains the single seeded one
            Integer canonical1ToTask = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonical1
                AND LinkedEntityId = :t1.Id
            ];
            Integer duplicate1ToTask = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicate1
                AND LinkedEntityId = :t1.Id
            ];
            System.assertEquals(1, canonical1ToTask);
            System.assertEquals(1, duplicate1ToTask, 'StrictAtomic rollback should restore duplicate link.');
        }
    }
    
    
    // ------------------------------------------------------------
    // (5B) strictAtomic=false gate fail (duplicate insert) => warnings + partial commit
    // Also covers: "Duplicate ContentDocument was NOT deleted because merge gate did not fully pass."
    // NOTE: exactly ONE startTest/stopTest per test method.
    // ------------------------------------------------------------
    @IsTest
    static void test_executeMergeForOneDuplicate_gateFail_partialCommit_warnsAndDoesNotDeleteDoc() {
        User u = getUserWithAccessOrNull();
        if (u == null) return;
        
        System.runAs(u) {
            Task t2 = new Task(Subject = getValidTaskSubject());
            insert t2;
            
            Product2 p2 = makeProduct('MP205');
            
            Id canonical2 = createPdfDocWithTitle('mp205.pdf');
            Id duplicate2 = createPdfDocWithTitle('mp205.pdf');
            
            linkDoc(canonical2, p2.Id);
            linkDoc(duplicate2, p2.Id);
            
            
            // Seed duplicate link we will delete
            linkDoc(duplicate2, t2.Id);
            
            // Seed canonical link so the attempted insert will FAIL (duplicate insert)
            linkDoc(canonical2, t2.Id);
            
            Id dupCdl2 = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicate2
                AND LinkedEntityId = :t2.Id
                LIMIT 1
            ].Id;
            
            List<Map<String,Object>> inserts2 = new List<Map<String,Object>>{
                new Map<String,Object>{
                    'linkedEntityId' => t2.Id,
                        'shareType'      => 'V',
                        'visibility'     => 'AllUsers'
                        }
            };
                List<Id> deletes2 = new List<Id>{ dupCdl2 };
                    
                    Test.startTest();
            ProductFileComplianceController.MergeExecutionResult res =
                ProductFileComplianceController.executeMergeForOneDuplicate(
                    p2.Id,
                    canonical2,
                    duplicate2,
                    true,               // deleteDuplicateDoc requested, but SHOULD NOT happen due to gate fail
                    inserts2,           // will fail
                    deletes2,           // should succeed (allowed via canonicalExistingKeys)
                    false,              // rollbackOnly
                    false               // strictAtomic=false => commit successes + warnings
                );
            Test.stopTest();
            
            System.assertEquals(false, res.rolledBack, 'Partial mode should not rollback on gate fail.');
            System.assert(res.warnings != null && !res.warnings.isEmpty(), 'Expected warnings on gate fail.');
            
            System.assertEquals(1, res.insertedLinksAttempted);
            System.assertEquals(0, res.insertedLinksSucceeded, 'Duplicate insert should fail.');
            
            System.assertEquals(1, res.deletedLinksAttempted);
            System.assertEquals(1, res.deletedLinksSucceeded, 'Delete should succeed.');
            
            // Because gate failed, duplicate document should NOT be deleted even though requested
            Integer dupDocStillThere2 = [
                SELECT COUNT() FROM ContentDocument WHERE Id = :duplicate2
            ];
            System.assertEquals(1, dupDocStillThere2,
                                'Duplicate ContentDocument should NOT be deleted on gate fail (partial mode).'
                               );
            
            // Verify committed partial state:
            // - canonical link still exists (seeded)
            // - duplicate link should be gone (delete committed)
            Integer canonical2ToTask = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonical2
                AND LinkedEntityId = :t2.Id
            ];
            Integer duplicate2ToTask = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :duplicate2
                AND LinkedEntityId = :t2.Id
            ];
            System.assertEquals(1, canonical2ToTask);
            System.assertEquals(0, duplicate2ToTask, 'Duplicate link should be deleted in partial mode.');
        }
    }

    
}