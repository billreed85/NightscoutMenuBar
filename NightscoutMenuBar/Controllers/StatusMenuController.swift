//
//  StatusMenuController.swift
//  NightscoutMenuBar
//
//  Created by Michael Pangburn on 7/28/17.
//  Copyright © 2017 Michael Pangburn. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    @IBOutlet private weak var statusMenu: NSMenu!
    @IBOutlet private weak var lastUpdatedMenuItem: NSMenuItem!
    @IBOutlet private weak var showBGDeltaMenuItem: NSMenuItem!
    @IBOutlet private weak var showBGTimeAgoMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var entryMenuItems: [NSMenuItem] = []

    private var nightscoutURL: URL? {
        didSet { UserDefaults.standard.nightscoutURL = nightscoutURL }
    }

    private var fetchedEntries: [NightscoutEntry] = []
    private var shouldFetchEntries = true

    private var lastUpdated = Date() {
        didSet {
            let format = NSLocalizedString("Updated %@", comment: "Time of last successful fetch")
            lastUpdatedMenuItem.title = String(format: format, lastUpdatedDateFormatter.string(from: lastUpdated))
        }
    }

    private let lastUpdatedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EE h:mm a"
        return f
    }()

    private let defaultStatusItemTitle = "Nightscout"

    // MARK: - Lifecycle

    override func awakeFromNib() {
        statusItem.button?.title = defaultStatusItemTitle
        statusItem.menu = statusMenu
        showBGDeltaMenuItem.state = UserDefaults.standard.showBGDeltaMenuItemState ?? .on
        showBGTimeAgoMenuItem.state = UserDefaults.standard.showBGTimeMenuItemState ?? .on

        if let url = UserDefaults.standard.nightscoutURL {
            nightscoutURL = url
            fetchEntries()
        } else {
            setNightscoutURL()
        }

        setupRefreshTimer()
        setupRefreshOnWakeNotification()
    }

    private func setupRefreshTimer() {
        Timer.scheduledTimer(withTimeInterval: .minutes(1), repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastUpdated) > .minutes(10) {
                URLCache.shared.removeAllCachedResponses()
            }
            self.fetchEntries()
        }
    }

    private func setupRefreshOnWakeNotification() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { [weak self] _ in
            self?.shouldFetchEntries = false
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.shouldFetchEntries = true
            self?.fetchEntries()
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Nightscout Configuration

    private func setNightscoutURL() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Nightscout Configuration",
            comment: "Title for the Nightscout URL configuration window")
        alert.informativeText = NSLocalizedString("Enter your Nightscout URL below.",
            comment: "Subtitle for the Nightscout URL configuration window")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        textField.placeholderString = "https://YOUR-NIGHTSCOUT-SITE.com"
        textField.stringValue = nightscoutURL?.absoluteString ?? ""
        alert.accessoryView = textField

        alert.addButton(withTitle: NSLocalizedString("OK", comment: "Confirm button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            showError(NSLocalizedString("Invalid URL", comment: "Invalid URL error"),
                      detail: NSLocalizedString("Please enter a valid Nightscout URL.", comment: "Invalid URL detail"))
            setNightscoutURL()
            return
        }

        nightscoutURL = url
        fetchEntries()
    }

    // MARK: - Fetching

    private func fetchEntries() {
        guard shouldFetchEntries, let baseURL = nightscoutURL else { return }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/entries.json"
        components.queryItems = [URLQueryItem(name: "count", value: "10")]
        guard let url = components.url else { return }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                if let urlError = error as? URLError,
                   urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                    return
                }
                DispatchQueue.main.async {
                    self.showError(NSLocalizedString("Network Error", comment: "Network error title"),
                                   detail: error.localizedDescription)
                }
                return
            }

            guard let data else { return }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                DispatchQueue.main.async {
                    self.showError(
                        NSLocalizedString("Unauthorized", comment: "Unauthorized error title"),
                        detail: NSLocalizedString("Your Nightscout site requires authentication. Check your URL or site settings.", comment: "Unauthorized error detail")
                    )
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                var entries = try decoder.decode([NightscoutEntry].self, from: data)
                // If the API didn't supply delta, compute it from consecutive readings
                if entries.count >= 2 && entries[0].delta == nil,
                   let a = entries[0].sgv, let b = entries[1].sgv {
                    entries[0] = NightscoutEntry(copying: entries[0], delta: a - b)
                }
                DispatchQueue.main.async {
                    self.fetchedEntries = entries
                    self.lastUpdated = Date()
                    self.updateUI()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(
                        NSLocalizedString("Data Error", comment: "Parsing error title"),
                        detail: error.localizedDescription
                    )
                }
            }
        }.resume()
    }

    // MARK: - UI

    private func updateUI() {
        entryMenuItems.forEach(statusMenu.removeItem)
        entryMenuItems.removeAll()

        guard let mostRecent = fetchedEntries.first else {
            statusItem.button?.title = defaultStatusItemTitle
            statusItem.button?.attributedTitle = NSAttributedString(string: defaultStatusItemTitle)
            return
        }

        let showDelta = showBGDeltaMenuItem.isOn
        let showTimeAgo = showBGTimeAgoMenuItem.isOn

        statusItem.button?.attributedTitle = mostRecent.menuBarAttributedString(
            delta: mostRecent.delta,
            includingDelta: showDelta,
            includingTimeAgo: showTimeAgo
        )

        let remaining = fetchedEntries.dropFirst()
        guard !remaining.isEmpty else { return }

        statusMenu.insertItem(.separator(), at: 0)
        // Compute delta for each history entry from the one after it
        let remainingArray = Array(remaining)
        for (i, entry) in remainingArray.prefix(5).enumerated().reversed() {
            let nextSgv = i + 1 < remainingArray.count ? remainingArray[i + 1].sgv : nil
            let entryDelta: Double? = entry.delta ?? {
                guard let a = entry.sgv, let b = nextSgv else { return nil }
                return a - b
            }()
            let item = NSMenuItem(title: entry.menuItemString(delta: entryDelta, includingDelta: showDelta), action: nil, keyEquivalent: "")
            item.isEnabled = false
            statusMenu.insertItem(item, at: 0)
            entryMenuItems.append(item)
        }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }

    // MARK: - Actions

    @IBAction private func toggleShowBGDelta(_ sender: NSMenuItem) {
        sender.isOn.toggle()
        UserDefaults.standard.showBGDeltaMenuItemState = sender.state
        updateUI()
    }

    @IBAction private func toggleShowBGTimeAgo(_ sender: NSMenuItem) {
        sender.isOn.toggle()
        UserDefaults.standard.showBGTimeMenuItemState = sender.state
        updateUI()
    }

    @IBAction private func refreshNowClicked(_ sender: NSMenuItem) {
        URLCache.shared.removeAllCachedResponses()
        fetchEntries()
    }

    @IBAction private func setNightscoutURLClicked(_ sender: NSMenuItem) {
        setNightscoutURL()
    }

    @IBAction private func quitClicked(sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
}
