import SwiftUI
import MapKit

struct LocationPickerSheet: View {
    @Bindable var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if locationService.isLocating {
                    Spacer()
                    ProgressView("正在获取位置...")
                    Spacer()
                } else if let loc = locationService.pendingLocation {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )
                    )) {
                        Marker(loc.name, coordinate: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude))
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.orange)
                        Text(loc.name)
                            .font(.yuantiSubheadline)
                            .lineLimit(2)
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("添加位置")
                            .font(.yuantiHeadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                } else if let error = locationService.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.yuantiSubheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    Spacer()
                    ProgressView("正在获取位置...")
                    Spacer()
                }
            }
            .navigationTitle("位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        locationService.clearPending()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await locationService.attachLocation()
        }
    }
}
