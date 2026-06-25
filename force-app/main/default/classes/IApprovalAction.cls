public interface IApprovalAction {
    void execute(Id targetRecordId, Id currentUserId, Map<String, Object> context);
}