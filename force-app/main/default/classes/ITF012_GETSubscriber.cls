/** 
* @author: Adolphe Sonko
* @date : Creation 27/03/2017
* @date : Modification 27/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF012_GETSubscriber {
    
	HttpResponse getListSubscriber(HttpRequest request,  String responseType);
	HttpResponse getSubscriber(HttpRequest request,  String responseType);
}