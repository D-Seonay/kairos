import Foundation
@testable import PhotosFeature
import PulseDomain
import Testing

struct PhotoTextTests {
    private let calendar = PhotosTestClock.calendar

    @Test func sessionPhotoLabelGivesRankAndTime() {
        let label = PhotoText.sessionPhotoLabel(index: 2, count: 4, addedAt: PhotosTestClock.date("2026-08-01T18:42"),
                                                calendar: calendar)
        #expect(label == "Photo 2 sur 4, ajoutée à 18 h 42")
    }

    @Test func sessionPhotoLabelPadsMinutes() {
        let label = PhotoText.sessionPhotoLabel(index: 1, count: 1, addedAt: PhotosTestClock.date("2026-08-01T07:05"),
                                                calendar: calendar)
        #expect(label == "Photo 1 sur 1, ajoutée à 7 h 05")
    }

    @Test func bodyPhotoLabelNamesPoseAndDate() {
        let first = PhotosTestClock.date("2026-08-01T09:00")
        #expect(PhotoText.bodyPhotoLabel(pose: .front, day: first, calendar: calendar) == "Photo de face, 1er août 2026")
        #expect(PhotoText.bodyPhotoLabel(pose: .side, day: first, calendar: calendar) == "Photo de profil, 1er août 2026")
        #expect(PhotoText.bodyPhotoLabel(pose: .back, day: PhotosTestClock.date("2026-10-28T09:00"), calendar: calendar)
            == "Photo de dos, 28 octobre 2026")
    }

    @Test func emptyPoseAndPoseNames() {
        #expect(PhotoText.emptyPoseLabel(.side) == "Ajouter une photo de profil")
        #expect(PhotoText.emptyPoseLabel(.front) == "Ajouter une photo de face")
        #expect(PhotoText.emptyPoseLabel(.back) == "Ajouter une photo de dos")
        #expect(BodyPose.allCases.map(PhotoText.poseName) == ["Face", "Profil", "Dos"])
    }

    @Test func weeksApartCountsWeeksFromTwoWeeksAndDaysBelow() {
        let start = PhotosTestClock.date("2026-08-01T09:00")
        func apart(_ days: Int) -> String {
            let end = calendar.date(byAdding: .day, value: days, to: start) ?? start
            return PhotoText.weeksApart(from: start, to: end, calendar: calendar)
        }
        #expect(apart(91) == "13 semaines d'écart")
        #expect(apart(14) == "2 semaines d'écart")
        #expect(apart(13) == "13 jours d'écart")
        #expect(apart(7) == "7 jours d'écart")
        #expect(apart(9) == "9 jours d'écart")
        #expect(apart(1) == "1 jour d'écart")
    }

    @Test func weeksApartIgnoresDirectionAndTimeOfDay() {
        let early = PhotosTestClock.date("2026-08-01T23:30")
        let late = PhotosTestClock.date("2026-08-10T00:10")
        #expect(PhotoText.weeksApart(from: late, to: early, calendar: calendar) == "9 jours d'écart")
        #expect(PhotoText.weeksApart(from: early, to: late, calendar: calendar) == "9 jours d'écart")
    }

    @Test func lastShotIsRelativeToNow() {
        let now = PhotosTestClock.date("2026-11-24T08:00")
        func last(_ text: String) -> String { PhotoText.lastShot(PhotosTestClock.date(text), now: now, calendar: calendar) }
        #expect(last("2026-11-24T06:00") == "Dernière prise aujourd'hui")
        #expect(last("2026-11-23T23:00") == "Dernière prise hier")
        #expect(last("2026-11-19T10:00") == "Dernière prise il y a 5 jours")
        #expect(last("2026-11-11T10:00") == "Dernière prise il y a 13 jours")
        #expect(last("2026-11-10T10:00") == "Dernière prise il y a 2 semaines")
        #expect(last("2026-10-27T10:00") == "Dernière prise il y a 4 semaines")
    }

    @Test func overLimitMessageCountsTheDroppedPhotos() {
        #expect(PhotoText.overLimit(dropped: 2) == "6 photos au maximum par séance : 2 n'ont pas été ajoutées.")
        #expect(PhotoText.overLimit(dropped: 1) == "6 photos au maximum par séance : 1 n'a pas été ajoutée.")
    }

    @Test func liveButtonLabelCountsPhotos() {
        #expect(PhotoText.liveButtonLabel(count: 0) == "Ajouter une photo")
        #expect(PhotoText.liveButtonLabel(count: 1) == "Ajouter une photo, 1 photo dans la séance")
        #expect(PhotoText.liveButtonLabel(count: 3) == "Ajouter une photo, 3 photos dans la séance")
    }
}
