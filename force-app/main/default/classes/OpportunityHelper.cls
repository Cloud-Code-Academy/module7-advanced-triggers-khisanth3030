public with sharing class OpportunityHelper extends TriggerHandler {

    public override void beforeInsert() { 
        defaultType(Trigger.new);
    }
    public override void beforeUpdate() {
        validateAmount(Trigger.new);
        setPrimaryContactToCEO(Trigger.new);
    }    
    public override void beforeDelete() {
        preventClosedOpportunityDeletion(Trigger.old);
    }
    public override void afterInsert() {
        createTaskForNewOpportunities(Trigger.new);
    }
    public override void afterUpdate() {
        appendStageChangesInDescription(Trigger.new, Trigger.old);
    }
    public override void afterDelete() {
        notifyOwnersOpportunityDeleted(Trigger.old);
        preventClosedOpportunityDeletionForBankingAccounts(Trigger.old);           
    }    
    public override void afterUndelete() {
        assignPrimaryContact(Trigger.new);         
    }
    
public void defaultType(List<Opportunity> opps) {
             // Set default Type for new Opportunities
             for (Opportunity opp : opps){
                if (opp.Type == null){
                    opp.Type = 'New Customer';}    
            }    
 }          
public void preventClosedOpportunityDeletion(List<Opportunity> oldOpps) {            
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : oldOpps){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
public void createTaskForNewOpportunities(List<Opportunity> opps) { 
    List<Task> taskList = new List<Task>(); 
            // Create a new Task for newly inserted Opportunities
            for (Opportunity opp : opps){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                taskList.add(tsk);
            }

            insert taskList;
}
        
public void appendStageChangesInDescription(List<Opportunity> newOpps, List<Opportunity> oldOpps) {
// Append Stage changes in Opportunity Description
List<Opportunity> oppsToUpdate = new List<Opportunity>();
Map<Id, Opportunity> oppOMap = new Map<Id, Opportunity>(oldOpps); 
        String currentDateTime = DateTime.now().format();
        for (Opportunity opp : newOpps) {
            if (opp.StageName != null && opp.StageName != oppOMap.get(opp.Id).StageName) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Description += '\n  Stage Change:' + opp.StageName + ':' + currentDateTime;
                oppsToUpdate.add(oppToUpdate);
            }
        }
        if (oppsToUpdate.size() > 0){
            System.debug('Number of Opportunities updated: ' + oppsToUpdate.size());
            if (Schema.sObjectType.Opportunity.isUpdateable()){
                try{update oppsToUpdate;} catch (Exception e){
                    System.debug('Exception: ' + e.getMessage());
                    throw e;}    
                } else {System.debug('Insufficient permissions to update Opportunity records.');} 
            }        
        }

    
    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */

        private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
            Set<Id> ownerIds = new Set<Id>();
            for (Opportunity opp : opps) {
                ownerIds.add(opp.OwnerId);
            }
        
            Map<Id, String> ownerEmails = new Map<Id, String>();        
                for (User user : [SELECT Id, Email FROM User WHERE Id IN :ownerIds]) {
                    ownerEmails.put(user.Id, user.Email);
                } 

            List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
            for (Opportunity opp : opps){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                String[] toAddresses = ownerEmails.values();
                mail.setToAddresses(toAddresses);
                mail.setSubject('Opportunity Deleted : ' + opp.Name);
                mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
                mails.add(mail);
            }        
            
            try {
                Messaging.sendEmail(mails);
            } catch (Exception e){
                System.debug('Exception: ' + e.getMessage());
            }
        }
    
        /*
        assignPrimaryContact:
        - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
        - Only updates the Opportunities that don't already have a primary contact.
        */
        public static void assignPrimaryContact(List<Opportunity> opps) {        
            Map<Id, Opportunity> oppNewMap = new Map<Id, Opportunity>(opps);   
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
            Map<Id,Contact> primaryContacts = getPrimaryContacts(opps);

            for (Opportunity opp : oppNewMap.values()){            
                Contact primaryContact = primaryContacts.get(opp.AccountId);
                if (opp.Primary_Contact__c == null){
                    Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                    oppToUpdate.Primary_Contact__c = primaryContact.Id;
                    oppMap.put(opp.Id, oppToUpdate);
                }
            }
        if (!oppMap.isEmpty() && Schema.sObjectType.Opportunity.isUpdateable()) {
            try { 
                update oppMap.values();
            } catch (Exception e) {
                System.debug('Exception: ' + e.getMessage());
                throw e;
            }
        } else if (oppMap.isEmpty()) {
            System.debug('No Opportunities to update.');
        } else {
            System.debug('Insufficient permissions to update Opportunity records.');
        }        
    }
    private static Map<Id,Contact> getPrimaryContacts(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps) {
            accountIds.add(opp.AccountId);
        }
    
        Map<Id, Contact> primaryContacts = new Map<Id, Contact>();
        if (Schema.sObjectType.Contact.fields.AccountId.isAccessible()) {
            for (Contact contact : [SELECT Id, AccountId FROM Contact
                WHERE Title = 'VP Sales' AND AccountId IN :accountIds]) {
                if (!primaryContacts.containsKey(contact.AccountId)) {
                    primaryContacts.put(contact.AccountId, contact);
                }
            }
        } else {
            System.debug('Insufficient permissions to access Contact records.');
        }
        return primaryContacts;
    }


   /*
    * Opportunity Trigger
    * When an opportunity is updated validate that the amount is greater than 5000.
    * Trigger should only fire on update.
    */
public void validateAmount(List<Opportunity> opps) {
    for(Opportunity opp : opps){
        if(opp.Amount < 5000){
            opp.addError('Opportunity amount must be greater than 5000');
        }
    }
}

   /*
    * Opportunity Trigger
    * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
    * Trigger should only fire on delete.
    */
 public void preventClosedOpportunityDeletionForBankingAccounts(List<Opportunity> oldOpps) {
   
        //Account related to the opportunities 
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oldOpps)]);

        for(Opportunity opp : oldOpps){
            if(opp.StageName == 'Closed Won'){
                if(accounts.get(opp.AccountId).Industry == 'Banking'){
                    opp.addError('Cannot delete a closed won opportunity for a banking account');
                }
            }
        }
    }

   /*
    * Opportunity Trigger
    * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
    * Trigger should only fire on update.
    */
    public void setPrimaryContactToCEO(List<Opportunity> opps){
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : opps){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : opps){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }    

}