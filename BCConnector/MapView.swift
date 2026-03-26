import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct MapView: View {
    let address: String
    @State private var position: MapCameraPosition = .automatic
    @State private var annotation: MKPointAnnotation?
    @StateObject private var locationManager = LocationManager()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Dismissal handle
            Rectangle()
                .fill(Color.secondary)
                .frame(width: 40, height: 5)
                .cornerRadius(2.5)
                .padding(.top, 10)
                .padding(.bottom, 5)
            
            // Map
            Map(position: $position) {
                if let annotation = annotation {
                    Marker("Destination", coordinate: annotation.coordinate)
                        .tint(.red)
                }
                if let user = locationManager.userLocation?.coordinate {
                    Marker("You", coordinate: user)
                        .tint(.blue)
                }
            }
            .frame(minHeight: 320)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    Button(action: fitBothIfPossible) {
                        Label("Fit", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    Button(action: openDirections) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding()
            }
            .gesture(DragGesture().onEnded { _ in
                // Dismiss the sheet when dragged down
                self.presentationMode.wrappedValue.dismiss()
            })
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            locationManager.request()
            geocodeAddress()
        }
        .onChange(of: locationManager.userLocation) { _, _ in
            fitBothIfPossible()
        }
    }

    private func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let location = placemarks?.first?.location {
                let newAnnotation = MKPointAnnotation()
                newAnnotation.coordinate = location.coordinate
                annotation = newAnnotation
                fitBothIfPossible()
            }
        }
    }

    private func fitBothIfPossible() {
        guard let dest = annotation?.coordinate else { return }
        if let user = locationManager.userLocation?.coordinate {
            // Compute region to fit both coords with padding
            let minLat = min(user.latitude, dest.latitude)
            let maxLat = max(user.latitude, dest.latitude)
            let minLon = min(user.longitude, dest.longitude)
            let maxLon = max(user.longitude, dest.longitude)
            var span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.6 + 0.02,
                                        longitudeDelta: (maxLon - minLon) * 1.6 + 0.02)
            span.latitudeDelta = max(span.latitudeDelta, 0.02)
            span.longitudeDelta = max(span.longitudeDelta, 0.02)
            let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0,
                                                longitude: (minLon + maxLon) / 2.0)
            position = .region(MKCoordinateRegion(center: center, span: span))
        } else {
            position = .region(MKCoordinateRegion(center: dest, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)))
        }
    }

    private func openDirections() {
        guard let dest = annotation?.coordinate else { return }
        let url = URL(string: "http://maps.apple.com/?daddr=\(dest.latitude),\(dest.longitude)&dirflg=d")!
        UIApplication.shared.open(url)
    }
}

// MARK: - Location Manager
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?
    private let mgr = CLLocationManager()

    override init() {
        super.init()
        mgr.delegate = self
        mgr.distanceFilter = kCLDistanceFilterNone
        mgr.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            mgr.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            mgr.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            mgr.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            DispatchQueue.main.async { self.userLocation = loc }
        }
    }
}
