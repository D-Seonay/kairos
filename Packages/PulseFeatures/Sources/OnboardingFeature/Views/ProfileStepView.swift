import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Écran 3, `profil-init` : prénom, morphologie, unités et niveaux. Rien n'est obligatoire, « Continuer » n'est jamais bloqué.
struct ProfileStepView: View {
    /// Les champs numériques : le clavier décimal n'a pas de touche Retour, « OK » le referme.
    private enum MeasureField: Hashable {
        case height, weight
    }

    @Bindable var model: OnboardingModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: MeasureField?

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            OnboardingTitle(
                title: String(localized: "Quelques repères sur toi", bundle: .module),
                subtitle: String(
                    localized: "Ils servent aux zones cardiaques et aux estimations de charge, rien d'autre.", bundle: .module))
            VStack(spacing: 14) {
                nameField
                sexField
                pair {
                    birthDateField
                } second: {
                    heightField
                }
                pair {
                    weightField
                } second: {
                    unitField
                }
                levelField(
                    title: String(localized: "Expérience en musculation", bundle: .module),
                    selection: model.optionalBinding(\.strengthLevel),
                    labels: [
                        String(localized: "Moins d'un an", bundle: .module),
                        String(localized: "1 à 3 ans", bundle: .module),
                        String(localized: "Plus de 3 ans", bundle: .module)
                    ])
                levelField(
                    title: String(localized: "Expérience en course à pied", bundle: .module),
                    selection: model.optionalBinding(\.runningLevel),
                    labels: [
                        String(localized: "Je débute", bundle: .module),
                        String(localized: "Je cours régulièrement", bundle: .module),
                        String(localized: "Je prépare des courses", bundle: .module)
                    ])
            }
        } footer: {
            OnboardingButton(
                title: String(localized: "Continuer", bundle: .module), identifier: OnboardingIdentifiers.profileContinue,
                style: PrimaryButtonStyle()
            ) { await continueFromProfile() }
        }
    }

    /// Un champ numérique en cours de saisie ne valide sa valeur qu'en perdant le focus : on le lui retire d'abord, et on laisse
    /// le formulaire l'écrire dans le profil avant d'enregistrer.
    private func continueFromProfile() async {
        if focusedField != nil {
            focusedField = nil
            try? await Task.sleep(for: .milliseconds(100))
        }
        await model.continueFromProfile()
    }

    // MARK: - Champs

    /// Deux champs côte à côte ; l'un sous l'autre aux tailles d'accessibilité, où leurs valeurs se couperaient.
    private func pair<First: View, Second: View>(
        @ViewBuilder _ first: () -> First, @ViewBuilder second: () -> Second
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            first()
            second()
        }
    }

    private var nameField: some View {
        OnboardingField(title: String(localized: "Prénom affiché", bundle: .module)) {
            TextField(
                String(localized: "Prénom affiché", bundle: .module), text: firstNameBinding,
                prompt: Text(String(localized: "Facultatif", bundle: .module)))
                .pulseGivenNameField()
                .onboardingInput()
        }
    }

    private var sexField: some View {
        OnboardingField(title: String(localized: "Sexe", bundle: .module)) {
            Picker(String(localized: "Sexe", bundle: .module), selection: $model.profile.sex) {
                Text(String(localized: "Femme", bundle: .module)).tag(Sex.female)
                Text(String(localized: "Homme", bundle: .module)).tag(Sex.male)
                Text(String(localized: "Autre", bundle: .module)).tag(Sex.unspecified)
            }
            .adaptiveSegmentedPicker()
            .labelsHidden()
        }
    }

    private var birthDateField: some View {
        OnboardingField(title: String(localized: "Date de naissance", bundle: .module)) {
            Group {
                if model.profile.birthDate == nil {
                    Button {
                        model.profile.birthDate = model.suggestedBirthDate
                    } label: {
                        Text(String(localized: "Renseigner", bundle: .module))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityLabel(String(localized: "Renseigner la date de naissance", bundle: .module))
                } else {
                    DatePicker(
                        String(localized: "Date de naissance", bundle: .module), selection: birthDateBinding,
                        in: ...model.latestBirthDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .onboardingInput()
        }
    }

    private var heightField: some View {
        OnboardingField(title: String(localized: "Taille", bundle: .module)) {
            measureInput(
                title: String(localized: "Taille", bundle: .module), value: $model.profile.heightCm,
                unit: String(localized: "cm", bundle: .module), spokenUnit: .centimeters, field: .height)
        }
    }

    private var weightField: some View {
        OnboardingField(title: String(localized: "Poids actuel", bundle: .module)) {
            measureInput(
                title: String(localized: "Poids actuel", bundle: .module), value: weightBinding,
                unit: model.profile.weightUnit.rawValue, spokenUnit: OnboardingCopy.MeasureUnit(model.profile.weightUnit),
                field: .weight)
        }
    }

    private var unitField: some View {
        OnboardingField(title: String(localized: "Unités", bundle: .module)) {
            Picker(String(localized: "Unités", bundle: .module), selection: $model.profile.weightUnit) {
                Text(String(localized: "kg", bundle: .module))
                    .accessibilityLabel(OnboardingCopy.MeasureUnit.kilograms.spokenName)
                    .tag(WeightUnit.kg)
                Text(String(localized: "lb", bundle: .module))
                    .accessibilityLabel(OnboardingCopy.MeasureUnit.pounds.spokenName)
                    .tag(WeightUnit.lb)
            }
            .adaptiveSegmentedPicker()
            .labelsHidden()
            .frame(minHeight: 48)
        }
    }

    /// La saisie d'une mesure : l'unité visible à côté est masquée, le champ la dit dans son étiquette. Le clavier décimal n'a pas
    /// de touche Retour : « OK », au-dessus du clavier, le referme et valide la valeur.
    private func measureInput(
        title: String, value: Binding<Double?>, unit: String, spokenUnit: OnboardingCopy.MeasureUnit, field: MeasureField
    ) -> some View {
        HStack(spacing: 6) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .pulseNumericKeyboard()
                .focused($focusedField, equals: field)
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        if focusedField == field {
                            Spacer()
                            Button(String(localized: "OK", bundle: .module)) { focusedField = nil }
                        }
                    }
                    #endif
                }
                .accessibilityLabel(OnboardingCopy.measureLabel(title: title, unit: spokenUnit))
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.muted)
                .accessibilityHidden(true)
        }
        .onboardingInput()
    }

    private func levelField(title: String, selection: Binding<TrainingLevel?>, labels: [String]) -> some View {
        OnboardingField(title: title) {
            ChoicePills(
                options: Array(zip(TrainingLevel.allCases, labels)).map { (value: $0.0, label: $0.1) }, selection: selection,
                groupLabel: title)
        }
    }

    // MARK: - Liens

    /// Un prénom vide est l'absence de prénom.
    private var firstNameBinding: Binding<String> {
        Binding(
            get: { model.profile.firstName ?? "" },
            set: { model.profile.firstName = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        )
    }

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { model.profile.birthDate ?? model.suggestedBirthDate },
            set: { model.profile.birthDate = $0 }
        )
    }

    /// Le poids est enregistré en kg ; il se lit et se saisit dans l'unité du profil.
    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                model.profile.weightKg.map { WeightUnits.displayValue(kilograms: $0, unit: model.profile.weightUnit) }
            },
            set: { newValue in
                model.profile.weightKg = newValue.map { WeightUnits.kilograms(fromDisplay: $0, unit: model.profile.weightUnit) }
            }
        )
    }
}

#if DEBUG
#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .profile))
}

#Preview("Profil, accessibilité XL") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .profile))
        .dynamicTypeSize(.accessibility3)
}
#endif
