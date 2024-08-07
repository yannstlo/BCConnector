import SwiftUI
import MapKit

struct MapView: View {
    let address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.33233141, longitude: -122.03121860),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var annotations: [MKPointAnnotation] = []

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapMarker(coordinate: annotation.coordinate)
        }
        .onAppear {
            geocodeAddress()
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
                region.center = location.coordinate
                let annotation = MKPointAnnotation()
                annotation.coordinate = location.coordinate
                annotations = [annotation]
            }
        }
    }
}
