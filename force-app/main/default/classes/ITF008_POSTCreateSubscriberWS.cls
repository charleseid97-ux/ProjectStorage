/** 
* @author: Adolphe SONKO
* @date : Creation 14/03/2017
* @date : Modification 14/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF008_POSTCreateSubscriberWS {
    
	HttpResponse postCreateSubscriber(HttpRequest request,  String responseType);
	HttpResponse putUpdateSubscriber(HttpRequest request,  String responseType);
}