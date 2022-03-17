/**************************************************************************************
*  @Author Ragnar Rahuoja
*  
*  	Date 13/01/2018
*  
*	Account Hierarchy Lightning Component Renderer class
*
*	First build
*
**************************************************************************************/

({
	//render function
	render : function(component, helper){
		var ret = this.superRender();
		return ret;
	},

	//re-renderes component after navigation 
	rerender : function(component, helper){
	    this.superRerender();
	    helper.buildList();
	}
})