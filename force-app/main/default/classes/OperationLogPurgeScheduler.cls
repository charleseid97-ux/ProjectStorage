public without sharing class OperationLogPurgeScheduler implements Schedulable {
    public static final String JOB_NAME = 'Operation Log Daily Purge';

    // Lance le batch de purge quand le scheduler est exécuté.
    public void execute(SchedulableContext context) {
        Database.executeBatch(new OperationLogPurgeBatch(), 200);
    }

    // Planifie la purge tous les jours à 02:00 dans le fuseau de l'utilisateur qui exécute cette méthode.
    public static String scheduleDailyAt2AM() {
        return scheduleDaily(2);
    }

    // Planifie la purge quotidienne à l'heure demandée et évite les doublons de job.
    public static String scheduleDaily(Integer hourOfDay) {
        Integer safeHour = normalizeHour(hourOfDay);
        abortExistingSchedule();

        String cronExpression = '0 0 ' + String.valueOf(safeHour) + ' * * ?';
        return System.schedule(JOB_NAME, cronExpression, new OperationLogPurgeScheduler());
    }

    // Supprime les anciennes planifications portant le même nom.
    public static void abortExistingSchedule() {
        for (CronTrigger cron : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(cron.Id);
        }
    }

    // Valide l'heure du scheduler avec 02:00 comme valeur par défaut.
    private static Integer normalizeHour(Integer hourOfDay) {
        if (hourOfDay == null || hourOfDay < 0 || hourOfDay > 23) {
            return 2;
        }

        return hourOfDay;
    }
}
