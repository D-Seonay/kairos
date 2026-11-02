import PulseContent
import Testing

@Test func searchTextFoldsAccentsCaseAndPunctuation() {
    #expect(SearchText.fold("  Développé Couché (Barre) ") == "developpe couche barre")
    #expect(SearchText.fold("Tirage Poitrine - Prise Serrée") == "tirage poitrine prise serree")
}

@Test func searchTextCollapsesSpacesAndKeepsDigits() {
    #expect(SearchText.fold("Curl   à  l'EZ-bar\t45°") == "curl a l ez bar 45")
    #expect(SearchText.fold("   ") == "")
    #expect(SearchText.fold("") == "")
}
