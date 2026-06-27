import Foundation
import Combine

struct Weather: Equatable {
    var tempC: Int
    var code: Int      // WMO weather code
    var city: String
}

/// Fetches current weather with no API key: IP geolocation (ipapi.co) →
/// Open-Meteo current conditions. Refreshes every 30 minutes.
final class WeatherManager: ObservableObject {
    @Published private(set) var weather: Weather?

    private var timer: Timer?

    func start() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    private func fetch() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self,
                  let loc = self.get(IPLocation.self, "https://ipapi.co/json/") else { return }
            let url = "https://api.open-meteo.com/v1/forecast?latitude=\(loc.latitude)"
                + "&longitude=\(loc.longitude)&current=temperature_2m,weather_code"
            guard let m = self.get(MeteoResponse.self, url) else { return }
            let w = Weather(
                tempC: Int(m.current.temperature_2m.rounded()),
                code: m.current.weather_code,
                city: loc.city
            )
            DispatchQueue.main.async { self.weather = w }
        }
    }

    private func get<T: Decodable>(_ type: T.Type, _ urlString: String) -> T? {
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private struct IPLocation: Decodable {
        let latitude: Double
        let longitude: Double
        let city: String
    }

    private struct MeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        let current: Current
    }
}

/// Map a WMO weather code to an SF Symbol.
func weatherSymbol(_ code: Int) -> String {
    switch code {
    case 0: return "sun.max.fill"
    case 1, 2: return "cloud.sun.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51...57: return "cloud.drizzle.fill"
    case 61...67, 80...82: return "cloud.rain.fill"
    case 71...77, 85, 86: return "cloud.snow.fill"
    case 95...99: return "cloud.bolt.rain.fill"
    default: return "cloud.fill"
    }
}
