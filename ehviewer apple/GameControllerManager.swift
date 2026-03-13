import SwiftUI
import GameController

// MARK: - GameController Manager for Bluetooth Page Turners
/// Handles Bluetooth page turners that use GameController API instead of keyboard emulation
/// Most consumer page turners emulate keyboard (arrow keys/space), so this is for advanced controllers

@MainActor
class GameControllerManager: NSObject, ObservableObject {
    @Published var isConnected = false
    
    /// Callback for page turner actions
    var onPageTurnerButton: ((PageTurnerAction) -> Void)?
    
    enum PageTurnerAction {
        case nextPage
        case previousPage
        case toggleUI
    }
    
    override init() {
        super.init()
        setupGameControllerNotifications()
        
        // Check for already-connected controllers
        Task { @MainActor in
            for controller in GCController.controllers() {
                setupController(controller)
            }
        }
    }
    
    private func setupGameControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerConnected),
            name: NSNotification.Name.GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDisconnected),
            name: NSNotification.Name.GCControllerDidDisconnect,
            object: nil
        )
    }
    
    @objc private func handleControllerConnected(_ notification: NSNotification) {
        guard let controller = notification.object as? GCController else { return }
        Task { @MainActor in
            self.isConnected = true
            setupController(controller)
        }
    }
    
    @objc private func handleControllerDisconnected(_ notification: NSNotification) {
        Task { @MainActor in
            self.isConnected = !GCController.controllers().isEmpty
        }
    }
    
    private func setupController(_ controller: GCController) {
        // Try different controller types in order of specificity
        if let extendedGamepad = controller.extendedGamepad {
            setupExtendedGamepad(extendedGamepad)
        } else if let gamepad = controller.gamepad {
            setupGamepad(gamepad)
        } else if let microGamepad = controller.microGamepad {
            setupMicroGamepad(microGamepad)
        }
    }
    
    // MARK: - Extended Gamepad (full controller support)
    private func setupExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        // Primary action buttons (A/B or Cross/Circle)
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
        
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        // Shoulder buttons (L1/R1 or LB/RB)
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
        
        // D-pad for navigation
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
        
        // Menu button to toggle UI
        gamepad.buttonMenu?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.toggleUI)
                }
            }
        }
    }
    
    // MARK: - Standard Gamepad
    private func setupGamepad(_ gamepad: GCGamepad) {
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
        
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
    }
    
    // MARK: - Micro Gamepad (minimal controller like Apple TV Remote)
    private func setupMicroGamepad(_ microGamepad: GCMicroGamepad) {
        microGamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
        
        microGamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        microGamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.previousPage)
                }
            }
        }
        
        microGamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.onPageTurnerButton?(.nextPage)
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
