/** 
* @author: Adolphe Sonko
* @date : Creation 29/03/2017
* @date : Modification 29/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF013_GETAttendee {
	HttpResponse getListAttendee(HttpRequest request,  String responseType);
	HttpResponse getAttendee(HttpRequest request,  String responseType);
}