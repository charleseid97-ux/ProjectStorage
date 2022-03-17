/** 
* @author: Adolphe SONKO
* @date : Creation 21/03/2017
* @date : Modification 21/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF010_PUTUpdateMailingListWS {
    
	HttpResponse putUpdateMailinglist(HttpRequest request,  String responseType);
}