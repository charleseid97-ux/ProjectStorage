global class DataExportCompanyPolicyBDPolicyCondition implements TxnSecurity.PolicyCondition {

 public boolean evaluate(TxnSecurity.Event e) {
  if(e.data.get('NumberOfRecords') == '500'){
   return true;
 }

 return false; 
}
 }