import Foundation
import Network

class NetworkConnectivityService: ObservableObject {
    @Published var isConnected: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    static let shared = NetworkConnectivityService()
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func isNetworkAvailable() -> Bool {
        return isConnected
    }
}