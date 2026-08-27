struct PopupExpansionState: Equatable {
    private(set) var appID: String?
    private(set) var deviceUID: String?

    @discardableResult
    mutating func toggleApp(_ appID: String) -> Bool {
        if self.appID == appID {
            self.appID = nil
            return false
        }

        self.appID = appID
        deviceUID = nil
        return true
    }

    @discardableResult
    mutating func toggleDevice(_ deviceUID: String) -> Bool {
        if self.deviceUID == deviceUID {
            self.deviceUID = nil
            return false
        }

        self.deviceUID = deviceUID
        appID = nil
        return true
    }

    mutating func collapseApp() {
        appID = nil
    }

    mutating func collapseDevice() {
        deviceUID = nil
    }

    mutating func reset() {
        appID = nil
        deviceUID = nil
    }
}
