export function getData(data, months, mapData) {
    
    let map1 = JSON.parse(data);
    var arr = []
    for (var key1 in map1) {

        months.push(key1)

        var map2 = map1[key1]
        for (var key2 in map2) {
            buildChart(map2, arr, key2);
            if (getOccurrence(arr, key2) == 1) {
                mapData.push({
                    key: key2,
                    value: map2[key2]
                })
            }
        }
    }
    months.reverse()
    mapData.reverse()
}


function buildChart(map2, arr, key2) {
    const v = { "v": map2[key2] }
    v["backgroundcolor"] = colorGen()

    arr.push(key2);
    if (getOccurrence(arr, key2) == 1) {
        map2[key2] = v;
    }
}

function getOccurrence(array, value) {
    var count = 0;
    array.forEach((v) => (v === value && count++))
    return count;

}

function colorGen() {
    const r = Math.floor(Math.random() * 256)
    const g = Math.floor(Math.random() * 256)
    const b = Math.floor(Math.random() * 256)
    return "\"rgb(" + r + "," + g + "," + b + "," + "0.2)\""//"\"rgb(" + r + "," + g + "," + b + "," + "0.2)\"" /// "\"rgb(" + r + "," + g + "," + b + ")\""
}