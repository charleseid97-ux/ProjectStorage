/** 
* @author: Adolphe SONKO
* @date : Creation 14/03/2017
* @date : Modification 14/03/2017
* @description : This Class allows to declare the webservices methodes.
*/

public interface ITF007_POSTCreateMailingListWS {
    
    HttpResponse postCreateMailinglist(HttpRequest request,  String responseType);
}