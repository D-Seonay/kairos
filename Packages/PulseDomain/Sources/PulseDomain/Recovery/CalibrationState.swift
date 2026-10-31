/// État de la ligne de base VFC : en calibration tant que moins de 14 nuits sont disponibles (spec §6.3).
public enum CalibrationState: Sendable, Equatable, Codable {
    case calibrating(nights: Int)
    case ready
}
