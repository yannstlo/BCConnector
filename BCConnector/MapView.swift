import SwiftUI
import MapKit

struct MapView: View {
    let address: String
    @State private var position: MapCameraPosition = .automatic
    @State private var annotation: MKPointAnnotation?

    var body: some View {
        Map(position: $position) {
            if let annotation = annotation {
                Marker("Location", coordinate: annotation.coordinate)
            }
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
                let newAnnotation = MKPointAnnotation()
                newAnnotation.coordinate = location.coordinate
                annotation = newAnnotation
                position = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                ))
            }
        }
    }
}
