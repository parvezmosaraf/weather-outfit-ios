import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case noDataWithMessage(String)
}

class WeatherService {
    private let apiKey = "d56eb0a58844a74ed810eebdf3f9a5f4"
    private let baseURL = "https://api.weatherstack.com/current"
    
    func getWeather(for location: String) async throws -> WeatherResponse {
        guard let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?access_key=\(apiKey)&query=\(encodedLocation)") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.noDataWithMessage(errorResponse.error.info)
            }
            throw NetworkError.noData
        }
        
        guard let weatherResponse = try? JSONDecoder().decode(WeatherResponse.self, from: data) else {
            throw NetworkError.decodingError
        }
        
        return weatherResponse
    }
}

struct WeatherResponse: Codable {
    let current: CurrentWeather
    let location: Location
    
    struct CurrentWeather: Codable {
        let temperature: Int
        let feelslike: Int
        let humidity: Int
        let weather_descriptions: [String]
    }
    
    struct Location: Codable {
        let name: String
    }
}

struct APIErrorResponse: Codable {
    let error: APIError
    struct APIError: Codable {
        let info: String
    }
} 