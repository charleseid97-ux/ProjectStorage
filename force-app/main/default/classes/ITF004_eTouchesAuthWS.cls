/** 
* @author: Briag GUEMARD
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface  ITF004_eTouchesAuthWS {
	
    //HttpResponse getAuthEtouches(HttpRequest request,  String responseType);
    HttpResponse createAuthEtouches(HttpRequest request,  String responseType);
	//HttpResponse updateContact(HttpRequest request,  String responseType);
    //HttpResponse deactivateContact(HttpRequest request,  String responseType);
	//HttpResponse deleteContact(HttpRequest request,  String responseType);
}