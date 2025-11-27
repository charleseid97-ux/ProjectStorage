public class WTP_NotifyQueueable implements Queueable {
    private WTP_Notify.Notice notice;
    public WTP_NotifyQueueable(WTP_Notify.Notice n){ this.notice = n; }

    public void execute(QueueableContext qc) {
        WTP_Notify.alert(notice);
    }
}