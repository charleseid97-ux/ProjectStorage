({
    startTag : function (c) {
        $A.util.removeClass(c.find('tagDropdown'), 'cts-hidden');
        c.set('v.currentTag', '');
        c.set('v.writingTag', true);
        this.filterTagList(c);
    },
    
    endTag : function (c) {
        $A.util.addClass(c.find('tagDropdown'), 'cts-hidden');
        c.set('v.currentTag', '');
        c.set('v.writingTag', false);
    },
    
    writeTag : function (c, e) {
        if (e.which === 32)
            this.endTag(c);
        c.set('v.currentTag', c.get('v.currentTag')+String.fromCharCode(e.which));
        this.filterTagList(c);
    },
    
    completeData : function (c, fullTag) {
        let currentTag = c.get('v.currentTag');
        let fieldData = c.get('v.fieldData');
			
        if (fieldData === '<p>#</p>') {
			c.set('v.fieldData', '<p>#'+fullTag+'</p>');            
        } else {
            let index = 1+this.getIndexOfDifference(c.get('v.previousData'), fieldData);
            let newData1 = fieldData.substring(0, index);
            let newData2 = fieldData.substring(index);

            newData1 = newData1.replace(new RegExp('#'+currentTag+'$'), '#'+fullTag+' ');
            c.set('v.fieldData', newData1+newData2);
        }
        
		this.endTag(c);
    },
    
    filterTagList : function (c) {
        let allTags = c.get('v.allTags');
        let currentTag = c.get('v.currentTag').toLowerCase();
        
        if (currentTag === '')
            c.set('v.filteredTags', allTags);
        else {
            let unorderedTags = [];
            let filteredTags = [];
            
            for (let i = 0; i < allTags.length; i++) {
                let indexOf = allTags[i].toLowerCase().indexOf(currentTag);
                if (indexOf != -1) unorderedTags.push({iof: indexOf, tag: allTags[i]});
            }

            unorderedTags.sort(function (a, b) {
                return a.iof - b.iof;
            });

            while (unorderedTags[0])
                filteredTags.push(unorderedTags.shift().tag);
            c.set('v.filteredTags', filteredTags);
        }
    },
    
    getIndexOfDifference : function(a, b) {
        let i = 0;
        let r = 0;
        
        dance:
        while (i < b.length) {
            if (a[i] != b[i]) {
                r = i;
                break dance;
            } else
                i++;
        }

        return r;
    }
})