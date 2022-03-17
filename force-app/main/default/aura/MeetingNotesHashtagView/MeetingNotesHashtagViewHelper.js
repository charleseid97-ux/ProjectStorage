({
	buildHtml : function (c, fieldData) {
        let regex = /#[a-zA-Z]+/gm;
        let match;
        let tags = [];
        
        while (match = regex.exec(fieldData)) {
            if (match.index === regex.lastIndex)
                regex.lastIndex++;
            tags.push(match[0]);
        }
        
        tags = this.deDuplicate(tags);
        
        while (tags[0])
            fieldData = this.replaceAll(fieldData, tags[0], '<span class="slds-badge">'+tags.shift()+'</span>');
        
        return fieldData;
    },
    
    escapeRegExp : function (str) {
        return str.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
    },
    
    replaceAll : function (str, find, replace) {
        return str.replace(new RegExp(this.escapeRegExp(find), 'g'), replace);
    },
    
    deDuplicate : function (arr) {
        let seen = {};
        return arr.filter(function(item) {
            return seen.hasOwnProperty(item) ? false : (seen[item] = true);
        });
    }
})