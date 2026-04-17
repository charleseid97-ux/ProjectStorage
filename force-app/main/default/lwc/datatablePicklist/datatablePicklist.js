import LightningDatatable from 'lightning/datatable';
import picklistView from './picklistView.html';
import picklistEdit from './picklistEdit.html';
import CriticityColumn from './customCriticity.html';
 
export default class DatatablePicklist extends LightningDatatable {
    static customTypes = {
        customPicklist: {
            template: picklistView,
            editTemplate: picklistEdit,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant', 'name']
        },
        customCriticity: {
            template: CriticityColumn,
            typeAttributes: ['value']
        }
    };
}