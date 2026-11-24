#if DEBUG
import Foundation
import PulseDomain
import PulseServices
import SwiftUI

/// Le code de l'iPhone des aperçus : `available` (un code existe) et `succeeds` (Face ID réussit) sont fixes.
struct PreviewOwnerAuthentication: DeviceOwnerAuthenticating {
    var available = true
    var succeeds = true

    func isAvailable() async -> Bool {
        available
    }

    func authenticate(reason: String) async -> Bool {
        succeeds
    }
}

/// Des photos de corps pour les aperçus : trois jours de prise (trois poses il y a 110 jours, face et dos il y a 55 jours, trois
/// poses il y a 27 jours) en images unies, et une pesée tous les trois jours qui descend doucement.
@MainActor
enum BodyPhotosPreviewSupport {
    static func service() async -> BodyPhotoService {
        let calendar = Calendar.current
        let measurements = InMemoryBodyMeasurementRepository()
        let service = BodyPhotoService(store: InMemoryBodyPhotoStore(), measurements: measurements, calendar: calendar,
                                       now: { Date() })
        let today = Date()
        let shots: [(offset: Int, poses: [BodyPose])] = [(-110, BodyPose.allCases), (-55, [.front, .back]), (-27, BodyPose.allCases)]
        for (dayIndex, shot) in shots.enumerated() {
            let day = calendar.date(byAdding: .day, value: shot.offset, to: today) ?? today
            for (poseIndex, pose) in shot.poses.enumerated() {
                let hue = Double(dayIndex * 3 + poseIndex) / 9
                if let processed = try? await service.process(PhotosPreviewSupport.jpeg(hue: hue, width: 90, height: 120)) {
                    _ = try? await service.save(processed, pose: pose, takenAt: day)
                }
            }
        }
        for back in stride(from: 115, through: 0, by: -3) {
            let date = calendar.date(byAdding: .day, value: -back, to: today) ?? today
            try? await measurements.save(BodyMeasurement(date: date, weightKg: 77 + Double(back) / 50, source: .manual,
                                                         createdAt: date, updatedAt: date))
        }
        return service
    }

    /// Un modèle sur le service garni ; sans verrou par défaut, pour voir la liste tout de suite.
    static func model(lockEnabled: Bool = false,
                      authentication: PreviewOwnerAuthentication = PreviewOwnerAuthentication()) async -> BodyPhotosModel {
        BodyPhotosModel(service: await service(), authentication: authentication,
                        lock: InMemoryBodyPhotoLockStore(isLockEnabled: lockEnabled), calendar: .current, now: { Date() })
    }
}
#endif
