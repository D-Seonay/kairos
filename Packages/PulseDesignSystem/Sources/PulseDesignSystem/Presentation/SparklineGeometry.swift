import CoreGraphics

/// La géométrie d'une sparkline : les valeurs, avec trous, converties en points dans un rectangle.
public enum SparklineGeometry {
    /// Un point par valeur, `nil` pour un trou. x est réparti de `minX + inset` à `maxX − inset` (une seule valeur : `midX`).
    /// y place le maximum en `minY + inset` et le minimum en `maxY − inset` ; des valeurs toutes égales sont à `midY`.
    /// Une valeur non finie compte pour un trou.
    public static func points(values: [Double?], in rect: CGRect, inset: CGFloat) -> [CGPoint?] {
        let finite = values.map { value in value.flatMap { $0.isFinite ? $0 : nil } }
        let present = finite.compactMap { $0 }
        guard let low = present.min(), let high = present.max() else { return finite.map { _ in nil } }
        let left = rect.minX + inset
        let span = max(0, rect.width - 2 * inset)
        let top = rect.minY + inset
        let height = max(0, rect.height - 2 * inset)
        return finite.enumerated().map { index, value in
            guard let value else { return nil }
            let x = finite.count == 1 ? rect.midX : left + span * CGFloat(index) / CGFloat(finite.count - 1)
            let y = high == low ? rect.midY : top + height * CGFloat((high - value) / (high - low))
            return CGPoint(x: x, y: y)
        }
    }
}
