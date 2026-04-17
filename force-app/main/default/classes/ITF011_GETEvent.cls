/** 
* @author: Briag GUEMARD
* @date : Creation 22/03/2017
* @date : Modification 22/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF011_GETEvent {
    
	HttpResponse getListEvent(HttpRequest request,  String responseType);
	HttpResponse getEvent(HttpRequest request,  String responseType);
	HttpResponse getListMailingList(HttpRequest request,  String responseType);
    
}