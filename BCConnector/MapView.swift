import SwiftUI
import MapKit

struct MapView: View {
    let address: String
    @State private var position: MapCameraPosition = .automatic
    @State private var annotation: MKPointAnnotation?
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
                    Marker("Location", coordinate: annotation.coordinate)
                }
            }
            .gesture(DragGesture().onEnded { _ in
                // Dismiss the sheet when dragged down
                self.presentationMode.wrappedValue.dismiss()
            })
        }
        .edgesIgnoringSafeArea(.bottom)
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
