public class JSONScoreUME2Apex {

	public Double yellowThreshold;
	public Double redThreshold;

	
	public static JSONScoreUME2Apex parse(String json) {
		return (JSONScoreUME2Apex) System.JSON.deserialize(json, JSONScoreUME2Apex.class);
	}
}