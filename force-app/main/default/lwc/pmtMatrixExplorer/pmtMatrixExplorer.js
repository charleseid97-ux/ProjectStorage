import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getModel from '@salesforce/apex/PMTMatrixExplorerController.getModel';
import PmtRuleLineEditor from 'c/pmtRuleLineEditor';

// Sharing statuses computed by PMTMatrixExplorerController, from the least to the most constraining
const STATUSES = {
    UNUSED: { label: 'Unused', description: 'No team uses the field' },
    SINGLE: { label: 'Single team', description: 'One team fills the field' },
    SCOPE_SPLIT: { label: 'Scope split', description: 'Teams of different scopes (IS / PS): only one of them applies to a project' },
    CONDITION_SPLIT: { label: 'Condition split', description: 'Every line has a condition: check that the conditions exclude each other' },
    SHARED: { label: 'Shared', description: 'Several teams fill the field on the same project' }
};
const VIEW_OPTIONS = [
    { label: 'Matrix', value: 'matrix' },
    { label: 'By team', value: 'team' },
    { label: 'By stage', value: 'stage' }
];
const MODIFIABLE_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Modifiable', value: 'true' },
    { label: 'Not modifiable', value: 'false' }
];
const ACTIVE_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Active', value: 'true' },
    { label: 'Inactive', value: 'false' }
];
// Legend pop-up, second column: what the chips and badges mean
const CHIP_LEGEND = [
    { key: 'required', className: 'chip chip_single chip_required', label: 'Required', description: 'Counted in the completion goal and checked before the team validates the stage' },
    { key: 'conditional', className: 'chip chip_single chip_conditional', label: 'Conditional', description: 'Required only when its Required when condition is true' },
    { key: 'optional', className: 'chip chip_single chip_optional', label: 'Optional', description: 'Shown to the team only' },
    { key: 'condition', className: 'chip chip_single chip_optional', label: 'Condition', icon: 'utility:filterList', description: 'Used only when its condition is true (formula in the tooltip)' },
    { key: 'error', className: 'chip chip_single chip_optional chip_error', label: 'Invalid condition', icon: 'utility:error', description: 'A condition that does not compile or reads the wrong object' },
    { key: 'inactive', className: 'slds-badge inactive-badge', label: 'Inactive', description: 'Line switched off: used nowhere' }
];
const SETUP_URL = '/lightning/setup/CustomMetadata/page?address=%2F';
// US-20194 V1.6: result of a deployment started by the rule line editor (PMTMatrixExplorerController.DeployCallback)
const DEPLOY_CHANNEL = '/event/PMTConfigurationDeploy__e';
const DEFAULT_FILTERS = { searchText: '', teamFilter: '', stageFilter: '', levelFilter: '', requirementFilter: '', modifiableFilter: '', activeFilter: '', statusFilter: '' };

export default class PmtMatrixExplorer extends LightningElement {
    model;
    fields = [];
    error;
    isLoading = true;
    view = 'matrix';
    viewOptions = VIEW_OPTIONS;
    modifiableOptions = MODIFIABLE_OPTIONS;
    activeOptions = ACTIVE_OPTIONS;
    chipLegend = CHIP_LEGEND;
    isLegendOpen = false;
    expandedFieldIds = [];
    // By team / By stage: sections whose open state differs from their default (a team or stage opens by default when 3 or fewer are shown, an inner table always)
    toggledGroupKeys = [];
    toggledSubgroupKeys = [];
    searchText = '';
    teamFilter = '';
    stageFilter = '';
    levelFilter = '';
    requirementFilter = '';
    modifiableFilter = '';
    activeFilter = '';
    statusFilter = '';
    wiredModelResult;
    deploySubscription;
    // Deployments started here, by their 15-character job Id, until their PMTConfigurationDeploy__e arrives
    pendingJobIds = [];

    @wire(getModel)
    wiredModel(result) {
        this.wiredModelResult = result;
        const { data, error } = result;
        if (data) {
            this.model = data;
            this.fields = [...data.fields].sort((a, b) => (b.isFund - a.isFund) || a.label.localeCompare(b.label));
            this.error = undefined;
        }
        else if (error) {
            this.error = error.body?.message ?? 'The PMT configuration could not be loaded.';
        }
        this.isLoading = !data && !error;
    }

    // Subscribed once on load, so a deployment ending right after the save is not missed
    connectedCallback() {
        onError(() => this.showToast('Deployment notifications unavailable', 'Refresh the page after saving to see the change.', 'warning'));
        subscribe(DEPLOY_CHANNEL, -1, message => this.handleDeployEvent(message.data.payload)).then(subscription => {
            this.deploySubscription = subscription;
        });
        document.addEventListener('click', this.closeLegend);
    }

    disconnectedCallback() {
        if (this.deploySubscription) unsubscribe(this.deploySubscription);
        document.removeEventListener('click', this.closeLegend);
    }

    // Any click outside the legend closes it: the legend and its button stop their own clicks
    closeLegend = () => {
        this.isLegendOpen = false;
    };

    get canEdit() {
        return this.model?.canEdit === true;
    }

    get isDeploying() {
        return this.pendingJobIds.length > 0;
    }

    get isMatrixView() {
        return this.view === 'matrix';
    }

    get allLines() {
        return this.fields.flatMap(field => field.lines);
    }

    // Stages holding at least one line: a stage without fields (e.g. Design) would only add an empty column
    get usedStages() {
        const stageNames = new Set(this.allLines.map(line => line.stage));
        return this.model.stages.filter(stage => stageNames.has(stage.name));
    }

    get summary() {
        const lines = this.allLines;
        const errorCount = lines.filter(line => line.conditionError || line.requiredConditionError).length + this.model.ownerRules.filter(rule => rule.conditionError).length;
        return [
            { key: 'stages', label: 'Stages', value: this.usedStages.length },
            { key: 'teams', label: 'Teams', value: this.model.teams.length },
            { key: 'fields', label: 'Fields', value: this.fields.length },
            { key: 'modifiable', label: 'Modifiable fields', value: this.fields.filter(field => field.isModifiable).length },
            { key: 'lines', label: 'Rule lines', value: lines.length },
            { key: 'conditional', label: 'Conditional lines', value: lines.filter(line => line.isConditional).length },
            { key: 'inactive', label: 'Inactive lines', value: lines.filter(line => !line.isActive).length },
            { key: 'conditions', label: 'Conditions', value: lines.filter(line => line.condition).length },
            { key: 'errors', label: 'Invalid conditions', value: errorCount, className: errorCount ? 'summary-item summary-item_error' : 'summary-item' }
        ].map(item => ({ className: 'summary-item', ...item }));
    }

    // Sharing filter: each status with its number of fields
    get statusOptions() {
        const options = Object.entries(STATUSES).map(([key, status]) => ({ label: `${status.label} (${this.fields.filter(field => field.sharingStatus === key).length})`, value: key }));
        return [{ label: `All (${this.fields.length})`, value: '' }, ...options];
    }

    // Legend pop-up, first column: the sharing statuses with their colours
    get statusLegend() {
        return Object.entries(STATUSES).map(([key, status]) => ({ key, ...status, className: `status status_${key.toLowerCase()}` }));
    }

    get legendButtonVariant() {
        return this.isLegendOpen ? 'brand' : 'neutral';
    }

    get teamOptions() {
        return this.buildOptions('All teams', this.model.teams.map(team => team.name));
    }

    get stageOptions() {
        return this.buildOptions('All stages', this.usedStages.map(stage => stage.name));
    }

    get levelOptions() {
        return this.buildOptions('All objects', [...new Set(this.fields.map(field => field.level))]);
    }

    get requirementOptions() {
        return this.buildOptions('All', [...new Set(this.allLines.map(line => line.requirement))]);
    }

    get hasLineFilter() {
        return !!(this.teamFilter || this.stageFilter || this.requirementFilter || this.activeFilter);
    }

    get hasFilter() {
        return this.hasLineFilter || !!(this.searchText || this.levelFilter || this.modifiableFilter || this.statusFilter);
    }

    get filteredFields() {
        const search = this.searchText.toLowerCase();
        return this.fields.filter(field => (!search || field.label.toLowerCase().includes(search) || field.apiName.toLowerCase().includes(search))
            && (!this.levelFilter || field.level === this.levelFilter)
            && (!this.modifiableFilter || String(field.isModifiable) === this.modifiableFilter)
            && (!this.statusFilter || field.sharingStatus === this.statusFilter)
            && (!this.hasLineFilter || field.lines.some(line => this.matchesLine(line))));
    }

    get fieldCountLabel() {
        return `${this.filteredFields.length} of ${this.fields.length} fields`;
    }

    get matrixColspan() {
        return this.usedStages.length + 2;
    }

    // Fields grouped by level (Fund first), one cell per stage holding a chip per team
    get matrixGroups() {
        const stages = this.usedStages;
        const groups = [];
        for (const field of this.filteredFields) {
            let group = groups.find(item => item.key === field.level);
            if (!group) {
                group = { key: field.level, rows: [] };
                groups.push(group);
            }
            group.rows.push(this.buildMatrixRow(field, stages));
        }
        return groups.map(group => ({ ...group, label: `${group.key} fields (${group.rows.length})` }));
    }

    get hasMatrixRows() {
        return this.filteredFields.length > 0;
    }

    get groups() {
        const teamGroups = this.view === 'team';
        const outerItems = teamGroups ? this.model.teams : this.usedStages;
        const innerItems = teamGroups ? this.usedStages : this.model.teams;
        const entries = this.filteredFields.flatMap(field => field.lines.filter(line => this.matchesLine(line)).map(line => ({ field, line })));
        const groups = outerItems.map(outer => {
            const outerEntries = entries.filter(entry => entry.line[this.view] === outer.name);
            const subgroups = innerItems.map(inner => {
                const rows = outerEntries.filter(entry => entry.line[teamGroups ? 'stage' : 'team'] === inner.name).map(entry => this.buildGroupRow(entry.field, entry.line, teamGroups));
                const key = `${this.view}-${outer.name}-${inner.name}`;
                return { key, title: inner.name, counts: `${rows.length} fields`, rows, ...this.buildToggle(!this.toggledSubgroupKeys.includes(key)) };
            }).filter(subgroup => subgroup.rows.length);
            const requiredCount = outerEntries.filter(entry => entry.line.isRequired).length;
            const conditionalCount = outerEntries.filter(entry => entry.line.isConditional).length;
            return {
                key: `${this.view}-${outer.name}`,
                title: outer.name,
                counts: `${outerEntries.length} fields · ${requiredCount} required · ${conditionalCount} conditional`,
                info: teamGroups ? this.buildTeamInfo(outer) : this.buildStageInfo(outer),
                subgroups,
                isEmpty: !subgroups.length
            };
        }).filter(group => !group.isEmpty || !this.hasFilter);
        const openByDefault = groups.length <= 3;
        return groups.map(group => ({ ...group, ...this.buildToggle(openByDefault !== this.toggledGroupKeys.includes(group.key)) }));
    }

    get hasGroups() {
        return this.groups.length > 0;
    }

    buildToggle(isOpen) {
        return { isOpen, toggleIcon: isOpen ? 'utility:chevrondown' : 'utility:chevronright', ariaExpanded: String(isOpen) };
    }

    matchesLine(line) {
        return (!this.teamFilter || line.team === this.teamFilter)
            && (!this.stageFilter || line.stage === this.stageFilter)
            && (!this.requirementFilter || line.requirement === this.requirementFilter)
            && (!this.activeFilter || String(line.isActive) === this.activeFilter);
    }

    buildOptions(allLabel, values) {
        return [{ label: allLabel, value: '' }, ...values.map(value => ({ label: value, value }))];
    }

    buildStatus(status) {
        return { ...STATUSES[status], className: `status status_${status.toLowerCase()}` };
    }

    buildMatrixRow(field, stages) {
        const expanded = this.expandedFieldIds.includes(field.id);
        return {
            key: field.id,
            detailKey: `${field.id}-detail`,
            label: field.label,
            apiName: field.apiName,
            developerName: field.developerName,
            setupUrl: SETUP_URL + field.id,
            isMissing: !field.existsOnObject,
            modifiableLabel: field.isModifiable ? 'Yes' : 'No',
            dependentFields: field.dependentFields.map(dependent => ({ ...dependent, key: dependent.apiName, isMissing: !dependent.existsOnObject })),
            noDependentFields: !field.dependentFields.length,
            status: this.buildStatus(field.sharingStatus),
            rowClass: `row row_${field.sharingStatus.toLowerCase()}`,
            cells: stages.map(stage => ({
                key: `${field.id}-${stage.name}`,
                chips: field.lines.filter(line => line.stage === stage.name).map(line => this.buildChip(field, line, line.team))
            })),
            expanded,
            expandIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright',
            details: expanded ? field.lines.map(line => this.buildDetailLine(line)) : []
        };
    }

    buildChip(field, line, label) {
        const classes = ['chip', `chip_${field.sharingStatus.toLowerCase()}`, `chip_${line.requirement.toLowerCase()}`];
        if (this.hasLineFilter && !this.matchesLine(line)) classes.push('chip_dimmed');
        if (line.conditionError || line.requiredConditionError) classes.push('chip_error');
        const title = [
            `${line.team} · ${line.stage} · ${line.requirement}`,
            line.condition && `Condition: ${line.condition}`,
            line.requiredCondition && `Required when: ${line.requiredCondition}`,
            line.conditionError && `Error: ${line.conditionError}`,
            line.requiredConditionError && `Error: ${line.requiredConditionError}`
        ];
        return {
            key: line.id,
            label,
            className: classes.join(' '),
            title: title.filter(Boolean).join('\n'),
            hasCondition: !!line.condition,
            hasError: !!(line.conditionError || line.requiredConditionError)
        };
    }

    buildDetailLine(line) {
        return { ...line, key: line.id, setupUrl: SETUP_URL + line.id, isInactive: !line.isActive };
    }

    buildGroupRow(field, line, teamGroups) {
        return {
            key: line.id,
            label: field.label,
            apiName: field.apiName,
            level: field.level,
            isModifiable: field.isModifiable,
            requirement: line.requirement,
            requirementClass: `requirement requirement_${line.requirement.toLowerCase()}`,
            condition: line.condition,
            conditionError: line.conditionError,
            requiredCondition: line.requiredCondition,
            requiredConditionError: line.requiredConditionError,
            setupUrl: SETUP_URL + line.id,
            isInactive: !line.isActive,
            status: this.buildStatus(field.sharingStatus),
            otherLines: field.lines.filter(other => other.id !== line.id).map(other => this.buildChip(field, other, teamGroups ? `${other.team} · ${other.stage}` : other.team))
        };
    }

    buildTeamInfo(team) {
        const ownerRules = this.model.ownerRules.filter(rule => rule.team === team.name).map(rule => ({
            key: rule.id,
            owner: this.formatOwner(rule.ownerName, rule.ownerFederationId),
            condition: rule.condition || 'Always',
            conditionError: rule.conditionError,
            setupUrl: SETUP_URL + rule.id
        }));
        return {
            items: [
                { key: 'scope', label: 'Scope', value: team.scope || 'All projects' },
                { key: 'validation', label: 'Validation team', value: team.isValidationTeam ? 'Yes' : 'No' },
                { key: 'owner', label: 'Default owner', value: this.formatOwner(team.ownerName, team.ownerFederationId) }
            ],
            setupUrl: SETUP_URL + team.id,
            ownerRules,
            hasOwnerRules: ownerRules.length > 0
        };
    }

    buildStageInfo(stage) {
        return {
            items: [
                { key: 'order', label: 'Order', value: stage.sortOrder },
                { key: 'duration', label: 'Duration', value: stage.durationDays != null ? `${stage.durationDays} days` : 'None' }
            ],
            setupUrl: SETUP_URL + stage.id,
            ownerRules: [],
            hasOwnerRules: false
        };
    }

    formatOwner(name, federationId) {
        if (name) return name;
        return federationId ? `${federationId} (no user found)` : 'None';
    }

    handleViewChange(event) {
        this.view = event.detail.value;
    }

    handleFilterChange(event) {
        this[event.target.dataset.filter] = event.detail.value;
    }

    handleLegendToggle(event) {
        event.stopPropagation();
        this.isLegendOpen = !this.isLegendOpen;
    }

    handleLegendClick(event) {
        event.stopPropagation();
    }

    // A team or stage section (data-kind="group") or one of its inner tables (data-kind="subgroup")
    handleToggleGroup(event) {
        const { key, kind } = event.currentTarget.dataset;
        const property = kind === 'group' ? 'toggledGroupKeys' : 'toggledSubgroupKeys';
        this[property] = this[property].includes(key) ? this[property].filter(item => item !== key) : [...this[property], key];
    }

    handleReset() {
        Object.assign(this, DEFAULT_FILTERS);
    }

    handleToggleField(event) {
        const fieldId = event.currentTarget.dataset.id;
        this.expandedFieldIds = this.expandedFieldIds.includes(fieldId) ? this.expandedFieldIds.filter(id => id !== fieldId) : [...this.expandedFieldIds, fieldId];
    }

    // US-20194 V1.6: create prefilled with the team, stage and level filters
    handleNewLine() {
        const team = this.model.teams.find(item => item.name === this.teamFilter);
        const stage = this.model.stages.find(item => item.name === this.stageFilter);
        const levelField = this.fields.find(field => field.level === this.levelFilter);
        this.openEditor(null, { team: team?.developerName, stage: stage?.developerName, objectName: levelField?.objectName });
    }

    handleEditLine(event) {
        this.openEditor(this.buildEditorLine(event.currentTarget.dataset.id), null);
    }

    // The editor closes with the job Id of the deployment it started, or asks to edit the existing line it would have duplicated
    async openEditor(line, defaults) {
        const result = await PmtRuleLineEditor.open({ size: 'medium', label: line ? 'Edit rule line' : 'New rule line', editorModel: this.buildEditorModel(), line, defaults });
        if (result?.editLineId) {
            this.openEditor(this.buildEditorLine(result.editLineId), null);
        }
        else if (result?.jobId) {
            this.pendingJobIds = [...this.pendingJobIds, result.jobId.substring(0, 15)];
            this.showToast('Saving', 'The PMT configuration is being deployed, the explorer refreshes when it is done.', 'info');
        }
    }

    buildEditorModel() {
        return {
            teamOptions: this.model.teams.map(team => ({ label: team.name, value: team.developerName })),
            stageOptions: this.model.stages.map(stage => ({ label: stage.name, value: stage.developerName })),
            levelOptions: this.model.levelOptions,
            requirementOptions: this.model.requirementOptions,
            fieldOptionsByLevel: this.model.fieldOptionsByLevel,
            helpTextByField: this.model.helpTextByField
        };
    }

    buildEditorLine(lineId) {
        const field = this.fields.find(item => item.lines.some(line => line.id === lineId));
        const line = field.lines.find(item => item.id === lineId);
        return {
            lineId,
            developerName: line.developerName,
            team: line.teamDeveloperName,
            stage: line.stageDeveloperName,
            objectName: field.objectName,
            fieldApiName: field.apiName,
            isModifiable: field.isModifiable,
            dependentFields: field.dependentFields.map(dependent => dependent.apiName),
            requirement: line.requirement,
            condition: line.condition,
            requiredCondition: line.requiredCondition,
            isActive: line.isActive
        };
    }

    handleDeployEvent(payload) {
        const jobId = payload.JobId__c?.substring(0, 15);
        if (!this.pendingJobIds.includes(jobId)) return;
        this.pendingJobIds = this.pendingJobIds.filter(id => id !== jobId);
        if (payload.IsSuccess__c) {
            this.showToast('Saved', 'The PMT configuration is deployed.', 'success');
            refreshApex(this.wiredModelResult);
        }
        else {
            this.showToast('Deployment failed', payload.Message__c, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: variant === 'error' ? 'sticky' : 'dismissible' }));
    }
}