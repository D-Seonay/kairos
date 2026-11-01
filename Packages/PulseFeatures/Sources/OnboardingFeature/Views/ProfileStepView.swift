import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Écran 3, `profil-init` : prénom, morphologie, unités et niveaux. Rien n'est obligatoire, « Continuer » n'est jamais bloqué.
struct ProfileStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            OnboardingTitle(
                title: String(localized: "Quelques repères sur toi", bundle: .module),
                subtitle: String(
                    localized: "Ils servent aux zones cardiaques et aux estimations de charge, rien d'autre.", bundle: .module))
            VStack(spacing: 14) {
                nameField
                sexField
                HStack(alignment: .top, spacing: 8) {
                    birthDateField
                    heightField
                }
                HStack(alignment: .top, spacing: 8) {
                    weightField
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
            ) { await model.continueFromProfile() }
        }
    }

    // MARK: - Champs

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
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var birthDateField: some View {
        OnboardingField(title: String(localized: "Date de naissance", bundle: .module)) {
            Group {
                if model.profile.birthDate == nil {
                    Button(String(localized: "Renseigner", bundle: .module)) {
                        model.profile.birthDate = model.suggestedBirthDate
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PulsePalette.text2)
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
                unit: String(localized: "cm", bundle: .module))
        }
    }

    private var weightField: some View {
        OnboardingField(title: String(localized: "Poids actuel", bundle: .module)) {
            measureInput(
                title: String(localized: "Poids actuel", bundle: .module), value: weightBinding,
                unit: model.profile.weightUnit.rawValue)
        }
    }

    private var unitField: some View {
        OnboardingField(title: String(localized: "Unités", bundle: .module)) {
            Picker(String(localized: "Unités", bundle: .module), selection: $model.profile.weightUnit) {
                Text(String(localized: "kg", bundle: .module)).tag(WeightUnit.kg)
                Text(String(localized: "lb", bundle: .module)).tag(WeightUnit.lb)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minHeight: 48)
        }
    }

    private func measureInput(title: String, value: Binding<Double?>, unit: String) -> some View {
        HStack(spacing: 6) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .pulseNumericKeyboard()
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.muted)
        }
        .onboardingInput()
    }

    private func levelField(title: String, selection: Binding<TrainingLevel?>, labels: [String]) -> some View {
        OnboardingField(title: title) {
            ChoicePills(options: Array(zip(TrainingLevel.allCases, labels)).map { (value: $0.0, label: $0.1) }, selection: selection)
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

#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .profile))
}
