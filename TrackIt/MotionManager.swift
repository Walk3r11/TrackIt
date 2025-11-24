import Foundation
import CoreMotion
import Combine

@MainActor
final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    private var basePitch: Double?
    private var baseRoll: Double?

    init() {
        #if targetEnvironment(simulator)
        #else
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data = data else { return }
                let currentPitch = data.attitude.pitch
                let currentRoll = data.attitude.roll
                if self.basePitch == nil { self.basePitch = currentPitch }
                if self.baseRoll == nil { self.baseRoll = currentRoll }
                self.pitch = currentPitch - (self.basePitch ?? 0)
                self.roll = currentRoll - (self.baseRoll ?? 0)
            }
        }
        #endif
    }

    deinit {
        #if !targetEnvironment(simulator)
        motion.stopDeviceMotionUpdates()
        #endif
    }
}
