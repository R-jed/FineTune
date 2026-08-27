// FineTune/Audio/Monitors/BluetoothConnectionError.swift

/// FineTune-owned connection failure state. Presentation layers decide how to localize it.
nonisolated enum BluetoothConnectionError: Equatable, Sendable {
    case couldNotConnect
    case timedOut
}
