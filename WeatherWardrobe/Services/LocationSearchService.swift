import MapKit

class LocationSearchService: NSObject, ObservableObject {
    @Published var searchResults = [MKLocalSearchCompletion]()
    private let searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }
    
    func updateSearch(query: String) {
        searchCompleter.queryFragment = query
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
    }
} 