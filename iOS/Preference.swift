struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://192.168.50.248:1935/stream"
    var streamName: String? = "test3"
    
    var captureMode: String? = "0"
    
    var encodeScale: String? = "2"

    let configFileDir: String = "/Documents/config.txt" //this is the file. we will write to and read from it
}
