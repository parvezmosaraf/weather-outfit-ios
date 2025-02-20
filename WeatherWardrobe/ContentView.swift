//
//  ContentView.swift
//  WeatherWardrobe
//
//  Created by Parvez Al Muqtadir on 2/20/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = LocationSearchService()
    @State private var showSuggestions = false
    @State private var location = ""
    @State private var weather: WeatherResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let weatherService = WeatherService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background based on weather condition
                weatherBackground
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Updated Search Section
                        VStack(spacing: 0) {
                            HStack {
                                TextField("Search Location", text: $location)
                                    .font(.system(size: 18, weight: .medium))
                                    .padding(12)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(14)
                                    .onChange(of: location) { newValue in
                                        showSuggestions = !newValue.isEmpty
                                        searchService.updateSearch(query: newValue)
                                    }
                                
                                Button {
                                    locationManager.requestLocation()
                                    if let currentLocation = locationManager.currentLocation {
                                        reverseGeocode(location: currentLocation)
                                    } else {
                                        errorMessage = "Please enable location access in Settings"
                                    }
                                } label: {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                        .padding(10)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                            
                            if showSuggestions && !searchService.searchResults.isEmpty {
                                VStack(alignment: .leading) {
                                    ForEach(searchService.searchResults.prefix(5), id: \.self) { result in
                                        Button(action: {
                                            selectLocation(result)
                                            showSuggestions = false
                                        }) {
                                            HStack {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(.blue)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(result.title)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    
                                                    if !result.subtitle.isEmpty {
                                                        Text(result.subtitle)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                            }
                        }
                        
                        // Main Weather Card
                        if let weather = weather {
                            WeatherCardView(weather: weather)
                                .transition(.opacity.combined(with: .scale))
                        }
                        
                        // Additional Weather Metrics
                        if let weather = weather {
                            WeatherInfoGrid(feelsLike: weather.current.feelslike,
                                            humidity: weather.current.humidity,
                                            condition: weather.current.weather_descriptions.first ?? "")
                        }
                        
                        // Outfit Recommendations
                        if let weather = weather {
                            OutfitRecommendationView(
                                temperature: weather.current.temperature,
                                description: weather.current.weather_descriptions.first ?? ""
                            )
                            .padding(.top, 10)
                        }
                        
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Weather Wardrobe")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            }
        }
        .accentColor(.white)
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            if status == .denied {
                errorMessage = "Location access required. Please enable in Settings."
            }
        }
    }
    
    private var weatherBackground: some View {
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)]),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        showSuggestions = false // Hide suggestions immediately
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                if let item = response?.mapItems.first {
                    let city = item.placemark.locality ?? ""
                    let country = item.placemark.country ?? ""
                    self.location = "\(city), \(country)"
                    self.fetchWeather()
                }
            }
        }
    }
    
    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Location lookup failed: \(error.localizedDescription)"
                }
                return
            }
            
            if let placemark = placemarks?.first {
                let city = placemark.locality ?? ""
                let country = placemark.country ?? ""
                DispatchQueue.main.async {
                    self.location = "\(city), \(country)"
                    self.fetchWeather()
                }
            }
        }
    }
    
    private func fetchWeather() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                weather = try await weatherService.getWeather(for: location)
            } catch {
                errorMessage = handleError(error: error)
            }
            isLoading = false
        }
    }
    
    private func handleError(error: Error) -> String {
        switch error {
        case NetworkError.invalidURL:
            return "Invalid location format"
        case NetworkError.noData:
            return "No weather data found"
        case NetworkError.decodingError:
            return "Failed to parse weather data"
        case NetworkError.noDataWithMessage(let message):
            return message
        default:
            return "Unknown error occurred: \(error.localizedDescription)"
        }
    }
}

struct WeatherCardView: View {
    let weather: WeatherResponse
    
    var body: some View {
        VStack(spacing: 0) {
            Text(weather.location.name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
            
            HStack(alignment: .top, spacing: 5) {
                Text("\(weather.current.temperature)")
                    .font(.system(size: 84, weight: .thin))
                Text("°C")
                    .font(.system(size: 32, weight: .bold))
            }
            .foregroundColor(.blue.opacity(0.8))
            .padding(.top, 8)
            
            Text(weather.current.weather_descriptions.joined(separator: ", "))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue.opacity(0.7))
                .padding(.bottom, 20)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.9))
        .cornerRadius(20)
        .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct WeatherInfoGrid: View {
    let feelsLike: Int
    let humidity: Int
    let condition: String
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            WeatherInfoItem(icon: "thermometer.sun.fill", title: "FEELS LIKE", value: "\(feelsLike)°C")
            WeatherInfoItem(icon: "drop.fill", title: "HUMIDITY", value: "\(humidity)%")
            WeatherInfoItem(icon: "cloud.sun.fill", title: "CONDITION", value: condition)
            WeatherInfoItem(icon: "umbrella.fill", title: "RAIN", value: "0%")
        }
        .padding(.horizontal)
    }
}

struct WeatherInfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 30)
                    .symbolRenderingMode(.multicolor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
    }
}

struct OutfitRecommendationView: View {
    let temperature: Int
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text("Recommended Outfit")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(generateRecommendation(), id: \.self) { item in
                    HStack(spacing: 12) {
                        Image(systemName: iconForItem(item))
                            .frame(width: 24)
                            .foregroundColor(.blue.opacity(0.8))
                        
                        Text(item)
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.white.opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private func generateRecommendation() -> [String] {
        var items = [String]()
        
        // Upper body
        if temperature < 10 {
            items.append(contentsOf: ["Thermal Wear", "Puffer Jacket", "Wool Sweater"])
        } else if temperature < 20 {
            items.append(contentsOf: ["Light Jacket", "Hoodie", "Long-sleeve Shirt"])
        } else {
            items.append(contentsOf: ["Cotton T-shirt", "Polo Shirt", "Tank Top"])
        }
        
        // Lower body
        if temperature < 15 {
            items.append(contentsOf: ["Jeans", "Thermal Leggings"])
        } else {
            items.append(contentsOf: ["Shorts", "Chino Pants"])
        }
        
        // Accessories
        if description.lowercased().contains("rain") {
            items.append(contentsOf: ["Waterproof Boots", "Compact Umbrella"])
        }
        
        if description.lowercased().contains("sun") {
            items.append(contentsOf: ["UV Protection Glasses", "Baseball Cap"])
        }
        
        return items
    }
    
    private func iconForItem(_ item: String) -> String {
        switch item {
        case "Thermal Wear": return "thermometer.snowflake"
        case "Puffer Jacket": return "coat.fill"
        case "Wool Sweater": return "heart.fill"
        case "Light Jacket": return "jacket.fill"
        case "Hoodie": return "tshirt"
        case "Long-sleeve Shirt": return "tshirt.fill"
        case "Cotton T-shirt": return "tshirt"
        case "Polo Shirt": return "figure.arms.open"
        case "Tank Top": return "figure.pool.swim"
        case "Jeans": return "figure.walk"
        case "Thermal Leggings": return "figure.mind.and.body"
        case "Shorts": return "figure.run"
        case "Chino Pants": return "figure.step.training"
        case "Waterproof Boots": return "shoe.fill"
        case "Compact Umbrella": return "umbrella.fill"
        case "UV Protection Glasses": return "glasses"
        case "Baseball Cap": return "baseball"
        default: return "questionmark.circle"
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 16, weight: .medium))
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
