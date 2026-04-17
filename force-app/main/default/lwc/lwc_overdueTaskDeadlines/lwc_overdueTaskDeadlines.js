import { LightningElement } from 'lwc';

export default class Lwc_overdueTaskDeadlines extends LightningElement {
   /* overdueTasks = [
        { id: 1, daysOverdue: 18, description: 'Task title goes here', deadline: 'December 2nd, 2024' },
        { id: 2, daysOverdue: 8, description: 'Task title goes here', deadline: 'November 22nd, 2024' },
        { id: 3, daysOverdue: 8, description: 'Task title goes here', deadline: 'November 22nd, 2024' }
    ];
*/
    overdueTasks = [
        { id: 1, daysOverdue: 18, Owner: 'Olivier Carton',Status: 'Draft', Stage: 'Proposal' },
        { id: 2, daysOverdue: 8, Owner: 'Thomas Coullon',Status: 'Draft', Stage: 'Engineering' },
        { id: 3, daysOverdue: 8, Owner: 'Thomas Coullon',Status: 'Draft', Stage: 'Engineering' }
    ];
}