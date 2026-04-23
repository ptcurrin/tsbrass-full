({
    doInit : function(component, event, helper) {
        helper.loadPage(component, true);
    },

    runSearch : function(component, event, helper) {
        component.set("v.pageNumber", 1);
        helper.loadPage(component, true);
    },

    nextPage : function(component, event, helper) {
        component.set("v.pageNumber", component.get("v.pageNumber") + 1);
        helper.loadPage(component, false);
    },
    
    prevPage : function(component, event, helper) {
        var n = component.get("v.pageNumber");
        
        if (n > 1) {
            component.set("v.pageNumber", n - 1);
            helper.loadPage(component, false);
        }
    },
    
    resetSearch : function(component, event, helper) {
        component.set("v.searchTerm", "");
        component.set("v.mode", "ALL");
        component.set("v.pageNumber", 1);
        helper.loadPage(component, true);
    },


    
    onRowAction : function(component, event, helper) {
        var action = event.getParam("action");
        var row = event.getParam("row");
        if (!action || !row) return;
        
        if (action.name === "openCleanup") {
            component.set("v.selectedProductId", row.productId);
            component.set("v.selectedProductLabel", (row.productCode || '') + " — " + (row.productName || ''));
            
            component.set("v.activeTabId", "files");
            helper.loadFilesTab(component);
        }
    },
    
    onPdfRowAction : function(component, event, helper) {
        var action = event.getParam("action");
        var row = event.getParam("row");
        if (!action || !row) return;
        
        if (action.name === "viewLinks") {
            component.set("v.selectedDocId", row.contentDocumentId);
            component.set("v.selectedDocTitle", row.title || "(no title)");
            helper.loadDocLinks(component, row.contentDocumentId);
        }
    },
    
    closeLinks : function(component, event, helper) {
        component.set("v.selectedDocId", null);
        component.set("v.selectedDocTitle", null);
        component.set("v.docLinkRows", []);
    },

    
    runHashAudit : function(component, event, helper) {
        // HARD STOP: if already running, don't enqueue anything
        if (component.get("v.auditIsRunning")) {
            console.log('[HashAudit] blocked: already running');
            return;
        }

        // Debounce: block rapid double-fire within 1 second
        var last = component.get("v._auditLastClickTs");
        var now = Date.now();
        if (last && (now - last) < 1000) {
            console.log('[HashAudit] blocked: debounce');
            return;
        }
        component.set("v._auditLastClickTs", now);

        console.log('[HashAudit] controller fired once');
        helper.runHashAudit(component);
    },
    
    
    loadMergeCandidates : function(component, event, helper) {
        helper.loadMergeCandidates(component);
    },
    
    refreshMergeHashes : function(component, event, helper) {
        helper.refreshMergeHashes(component);
    },

    
    
    onMergeRowAction : function(component, event, helper) {
        var action = event.getParam("action");
        var row = event.getParam("row");
        
        if (action && action.name === "selectCanonical") {
            helper.confirmAndSetCanonical(component, row);
        }
    },

        
    buildMergePlan : function(component, event, helper) {
        helper.buildMergePlan(component);
    },

    
    onInsertSelection : function(component, event, helper) {
        var selected = event.getParam("selectedRows") || [];
        component.set("v.selectedInsertKeys", selected.map(function(r){ return r.insertKey; }));
    },
    
    onDeleteSelection : function(component, event, helper) {
        var selected = event.getParam("selectedRows") || [];
        component.set("v.selectedDeleteLinkIds", selected.map(function(r){ return r.contentDocumentLinkIdToDelete; }));
    },

    
    startMergeWizard : function(component, event, helper) {
        
        component.set("v.mergePlanIsLoading", true);
        
        
        // RESET SELECTION STATE
        component.set("v.mergeStepSelectedInsertRows", []);
        component.set("v.mergeStepSelectedDeleteRows", []);
        component.set("v.mergeStepDeleteDocChecked", false);
        
        
        var action = component.get("c.getMergePlan");
        action.setParams({
            productId : component.get("v.selectedProductId"),
            canonicalDocId : component.get("v.selectedCanonicalDocId")
        });
        
        action.setCallback(this, function(resp) {
            component.set("v.mergePlanIsLoading", false);
            
            
            if (resp.getState() !== "SUCCESS") {
                helper.showError(component, resp);
                return;
            }
            
            component.set("v.mergeExecIsRunning", false);

            
            var plan = resp.getReturnValue();
            
            component.set("v.mergePlan", plan);
            component.set("v.mergeDuplicateDocs", plan.duplicateDocs);
            component.set("v.mergeStepIndex", 0);
            component.set("v.showMergeWizard", true);
            
            helper.loadWizardStep(component);
        });
        
        $A.enqueueAction(action);
    },
    
    closeMergeWizard : function(component) {
        component.set("v.mergeExecIsRunning", false);

        component.set("v.showMergeWizard", false);
    },
    
    nextMergeStep : function(component, event, helper) {
        var idx = component.get("v.mergeStepIndex");
        component.set("v.mergeStepIndex", idx + 1);
        
        
        // RESET SELECTION STATE
        component.set("v.mergeStepSelectedInsertRows", []);
        component.set("v.mergeStepSelectedDeleteRows", []);
        component.set("v.mergeStepDeleteDocChecked", false);
        component.set("v.mergeStepLocked", false);

        
        helper.loadWizardStep(component);
    },
    
    prevMergeStep : function(component, event, helper) {
        var idx = component.get("v.mergeStepIndex");
        component.set("v.mergeStepIndex", idx - 1);
        
        // RESET SELECTION STATE
        component.set("v.mergeStepSelectedInsertRows", []);
        component.set("v.mergeStepSelectedDeleteRows", []);
        component.set("v.mergeStepDeleteDocChecked", false);
        component.set("v.mergeStepLocked", false);

        
        helper.loadWizardStep(component);
    },
    
    onStepInsertSelection : function(component, event) {
        component.set("v.mergeStepSelectedInsertRows",
                      event.getParam("selectedRows"));
    },
    
    onStepDeleteSelection : function(component, event) {
        component.set("v.mergeStepSelectedDeleteRows",
                      event.getParam("selectedRows"));
    },
    
    /*
    executeCurrentMergeDoc : function(component, event, helper) {
        
        component.set("v.mergeExecIsRunning", true);
        
        var inserts = component.get("v.mergeStepSelectedInsertRows") || [];
        var deletes = component.get("v.mergeStepSelectedDeleteRows") || [];
        var deleteDoc = component.get("v.mergeStepDeleteDocChecked");
        var stepDoc = component.get("v.mergeStepDoc");
        
        var action = component.get("c.executeMergeForOneDuplicate");
        action.setParams({
            canonicalDocId : component.get("v.selectedCanonicalDocId"),
            duplicateDocId : stepDoc.duplicateDocId,
            insertRows : inserts,
            deleteCdlIds : deletes.map(r => r.contentDocumentLinkIdToDelete),
            deleteDuplicateDoc : deleteDoc
        });
        
        action.setCallback(this, function(resp) {
            component.set("v.mergeExecIsRunning", false);
            
            if (resp.getState() !== "SUCCESS") {
                helper.showError(component, resp);
                return;
            }
            
            component.set("v.mergeExecLog",
                          JSON.stringify(resp.getReturnValue(), null, 2)
                         );
        });
        
        $A.enqueueAction(action);
    },*/
    
    onTabChange : function(component, event, helper) {
        var tabId = event.getParam("id");
        
        console.log('tabId: ' + tabId);
        
        // Leaving merge tab
        if (tabId !== "merge") {
            helper.resetMergeState(component);
        }else{
            helper.loadMergeCandidates(component);
        }
        
        // Entering Hash Audit
        if (tabId === "audit") {
            helper.clearHashAuditUI(component);
            helper.runHashAudit(component); // auto-run
        }
    },
    
    //
    
    executeMergeRollback : function(component, event, helper) {
        console.log("executeMergeRollback clicked");

        //if (!confirm("⚠️ THIS WILL ROLLBACK ANY DELETED RECORDS. Proceed?")) return;
        helper.executeMerge(component, true, true);
    },
    
    executeMergeReal : function(component, event, helper) {
        if (!confirm("⚠️ THIS WILL DELETE RECORDS and COMMIT partial successes.... Proceed?")) return;
        helper.executeMerge(component, false, false);
    },
    
    onExecuteForReal : function(component, event, helper) {
        helper.executeMerge(component, false, true);
        
    },
    



})