import { LightningElement, wire } from 'lwc';
import getModel from '@salesforce/apex/PMTMatrixExplorerController.getModel';

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
const SETUP_URL = '/lightning/setup/CustomMetadata/page?address=%2F';
const DEFAULT_FILTERS = { searchText: '', teamFilter: '', stageFilter: '', levelFilter: '', requirementFilter: '', modifiableFilter: '', statusFilter: '', conditionOnly: false };

export default class PmtMatrixExplorer extends LightningElement {
    model;
    fields = [];
    error;
    isLoading = true;
    view = 'matrix';
    viewOptions = VIEW_OPTIONS;
    modifiableOptions = MODIFIABLE_OPTIONS;
    expandedFieldIds = [];
    searchText = '';
    teamFilter = '';
    stageFilter = '';
    levelFilter = '';
    requirementFilter = '';
    modifiableFilter = '';
    statusFilter = '';
    conditionOnly = false;

    @wire(getModel)
    wiredModel({ data, error }) {
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

    get statusButtons() {
        return Object.entries(STATUSES).map(([key, status]) => ({
            key,
            ...status,
            count: this.fields.filter(field => field.sharingStatus === key).length,
            className: `status status_${key.toLowerCase()}${this.statusFilter === key ? ' status_selected' : ''}`
        })).filter(status => status.count);
    }

    get teamOptions() {
        return this.buildOptions('All teams', this.model.teams.map(team => team.name));
    }

    get stageOptions() {
        return this.buildOptions('All stages', this.usedStages.map(stage => stage.name));
    }

    get levelOptions() {
        return this.buildOptions('All levels', [...new Set(this.fields.map(field => field.level))]);
    }

    get requirementOptions() {
        return this.buildOptions('All', [...new Set(this.allLines.map(line => line.requirement))]);
    }

    get hasLineFilter() {
        return !!(this.teamFilter || this.stageFilter || this.requirementFilter || this.conditionOnly);
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
        return outerItems.map(outer => {
            const outerEntries = entries.filter(entry => entry.line[this.view] === outer.name);
            const subgroups = innerItems.map(inner => {
                const rows = outerEntries.filter(entry => entry.line[teamGroups ? 'stage' : 'team'] === inner.name).map(entry => this.buildGroupRow(entry.field, entry.line, teamGroups));
                return { key: `${outer.name}-${inner.name}`, label: `${inner.name} (${rows.length})`, rows };
            }).filter(subgroup => subgroup.rows.length);
            const requiredCount = outerEntries.filter(entry => entry.line.isRequired).length;
            const conditionalCount = outerEntries.filter(entry => entry.line.isConditional).length;
            return {
                key: outer.name,
                label: `${outer.name} · ${outerEntries.length} fields · ${requiredCount} required · ${conditionalCount} conditional`,
                info: teamGroups ? this.buildTeamInfo(outer) : this.buildStageInfo(outer),
                subgroups,
                isEmpty: !subgroups.length
            };
        }).filter(group => !group.isEmpty || !this.hasFilter);
    }

    get hasGroups() {
        return this.groups.length > 0;
    }

    // A few groups left (e.g. one team filtered): opened right away
    get openSections() {
        const groups = this.groups;
        return groups.length <= 3 ? groups.map(group => group.key) : [];
    }

    matchesLine(line) {
        return (!this.teamFilter || line.team === this.teamFilter)
            && (!this.stageFilter || line.stage === this.stageFilter)
            && (!this.requirementFilter || line.requirement === this.requirementFilter)
            && (!this.conditionOnly || !!(line.condition || line.requiredCondition));
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

    handleConditionChange(event) {
        this.conditionOnly = event.target.checked;
    }

    handleStatusClick(event) {
        const status = event.currentTarget.dataset.status;
        this.statusFilter = this.statusFilter === status ? '' : status;
    }

    handleReset() {
        Object.assign(this, DEFAULT_FILTERS);
    }

    handleToggleField(event) {
        const fieldId = event.currentTarget.dataset.id;
        this.expandedFieldIds = this.expandedFieldIds.includes(fieldId) ? this.expandedFieldIds.filter(id => id !== fieldId) : [...this.expandedFieldIds, fieldId];
    }
}
