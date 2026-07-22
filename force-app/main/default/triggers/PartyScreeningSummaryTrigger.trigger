trigger PartyScreeningSummaryTrigger on PartyScreeningSummary (after insert, after update) {
    PartyScreeningSummaryTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}