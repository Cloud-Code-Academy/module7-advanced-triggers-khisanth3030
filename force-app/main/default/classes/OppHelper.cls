public with sharing class OppHelper extends TriggerHandler {

    public override void beforeInsert() { 
        //defaultType(Trigger.new);
    }

    public override void beforeUpdate() {
        //validateAmount(Trigger.new);
        //setPrimaryContactToCEO(Trigger.new);
    }    

    public override void beforeDelete() {
        //preventClosedOpportunityDeletion(Trigger.old);
    }

    public override void afterInsert() {
        //createTaskForNewOpportunities(Trigger.new);
    }
    public override void afterUpdate() {
        //appendStageChangesInDescription(Trigger.new, Trigger.old);
    }

    public override void afterDelete() {
        //notifyOwnersOpportunityDeleted(Trigger.old);
        //preventClosedOpportunityDeletionForBankingAccounts(Trigger.old);           
    }
    
    public override void afterUndelete() {
        //assignPrimaryContact(Trigger.new);         
    }

 
    
}