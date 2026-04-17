public class JSONAssessmentsUME2Apex {

	public class PhoneNumbers {
		public String numberType;
		public String phoneNo;
	}

	public String guid;
	public String assessmentDate;
	public String expirationDate;
	public AssessingUser assessingUser;
	public String summary;
	public Double scoringFactor;
	public Integer assessmentScore;
	public Integer assessmentStatus;

	public class AssessingUser {
		public String guid;
		public String firstName;
		public String lastName;
		public String email;
		public List<PhoneNumbers> phoneNumbers;
		public Integer userStatus;
	}

	
	public static JSONAssessmentsUME2Apex parse(String json) {
		return (JSONAssessmentsUME2Apex) System.JSON.deserialize(json, JSONAssessmentsUME2Apex.class);
	}
}