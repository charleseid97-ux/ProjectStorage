import { LightningElement, api, track } from 'lwc';
import getProjectDataToExport from '@salesforce/apex/ExportProjectDataController.getProjectDataToExport';
 
export default class ExportProjectData extends LightningElement {
    @api recordId;
    @track projectData = [];
    @track columnHeader = [];
    @track isLoading = false;
 
exportToCsv() {
    if (!this.recordId) {
        alert('Project ID is missing.');
        return;
    }

    this.isLoading = true;

    getProjectDataToExport({ recordId: this.recordId })
        .then(data => {
            if (data.length === 0) {
                alert('No data available for export.');
                this.isLoading = false;
                return;
            }

            this.projectData = data;

            // Tri clair PP puis SC
            this.columnHeader = Object.keys(data[0]).sort((a, b) => {
                if (a.startsWith('PP -') && b.startsWith('SC -')) return -1;
                if (a.startsWith('SC -') && b.startsWith('PP -')) return 1;
                return 0;
            });

            // Génération CSV (virgule + échappement des guillemets)
            let csvContent = this.columnHeader.join('|') + '\n';
            this.projectData.forEach(row => {
                let rowData = this.columnHeader.map(field => 
                    `"${(row[field] || '').replace(/"/g, '""')}"`
                ).join('|');
                csvContent += rowData + '\n';
            });

            // Téléchargement CSV
            let element = 'data:application/vnd.ms-excel,' + encodeURIComponent(csvContent);
            let downloadElement = document.createElement('a');
            downloadElement.href = element;
            downloadElement.target = '_self';
            downloadElement.download = 'ExportProjectProduct.csv';
            document.body.appendChild(downloadElement);
            downloadElement.click();

            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching data:', error);
            alert('An error occurred while exporting data.');
            this.isLoading = false;
        });
}
}