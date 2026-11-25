import Foundation
import PulseDesignSystem

extension SessionPhotosModel {
    /// Les photos de la séance proposées en fond de la carte de partage, dans l'ordre, celles dont la vignette est lue. L'image
    /// entière n'est lue que si on la choisit.
    public var shareCardPhotos: [ShareCardPhoto] {
        photos.compactMap { photo in
            guard let thumbnail = thumbnails[photo.id] else { return nil }
            let id = photo.id
            return ShareCardPhoto(id: id, thumbnail: thumbnail) { [weak self] in await self?.image(of: id) }
        }
    }
}
