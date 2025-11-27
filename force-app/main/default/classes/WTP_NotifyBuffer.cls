public class WTP_NotifyBuffer {
    public static List<WTP_Notify.Notice> bag = new List<WTP_Notify.Notice>();
    public static void add(WTP_Notify.Notice n) {
        if (n != null) bag.add(n);
    }
    public static void flushAsync(String contexte) {
        if (bag.isEmpty()) return;
        // un seul enqueue APRÈS tous les callouts → pas de rollback / pas de limite
        WTP_Notify.alertAsync(WTP_Notify.mergeNotices(contexte, bag));
        bag.clear();
    }
}