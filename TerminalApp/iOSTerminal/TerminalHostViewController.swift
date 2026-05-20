//
//  TerminalHostViewController.swift
//  iOSTerminal
//
//  Created by Codex on 1/15/25.
//

import UIKit

final class TerminalHostViewController: UIViewController {
    private let terminalView = SshTerminalView(frame: .zero)
    private var connectionInfo: SSHConnectionInfo?
    private var lastTerminalSize: CGSize = .zero
    private var didApplyInitialConnection = false
    private var pendingLayoutWorkItem: DispatchWorkItem?
    private let layoutSettleDelay: TimeInterval = 0.12

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.isOpaque = true
        terminalView.isOpaque = true
        terminalView.backgroundColor = .black
        terminalView.nativeBackgroundColor = .black
        terminalView.contentInsetAdjustmentBehavior = .never
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(terminalView)

        terminalView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        terminalView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        terminalView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        if #available(iOS 15.0, *) {
            view.keyboardLayoutGuide.topAnchor.constraint(equalTo: terminalView.bottomAnchor).isActive = true
        } else {
            terminalView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }

        applySettings()

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let currentSize = terminalView.bounds.size
        guard currentSize.width > 0, currentSize.height > 0 else {
            return
        }

        if currentSize != lastTerminalSize {
            lastTerminalSize = currentSize
            print("[TerminalHostVC] Layout changed: \(currentSize)")
        }

        scheduleTerminalSetup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        terminalView.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _ = terminalView.resignFirstResponder()
    }

    func updateConnectionInfo(_ info: SSHConnectionInfo) {
        if connectionInfo == info {
            return
        }
        connectionInfo = info
        if isViewLoaded {
            didApplyInitialConnection = false
            scheduleTerminalSetup()
        }
    }
    
    private func applySettings() {
        SettingsStore.shared.apply(to: terminalView)
    }

    private func scheduleTerminalSetup() {
        guard isViewLoaded,
              lastTerminalSize.width > 0,
              lastTerminalSize.height > 0 else {
            return
        }

        pendingLayoutWorkItem?.cancel()

        let expectedSize = lastTerminalSize
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.lastTerminalSize == expectedSize else { return }

            if !self.didApplyInitialConnection, let info = self.connectionInfo {
                self.didApplyInitialConnection = true
                self.terminalView.configure(connectionInfo: info)
            }

            self.terminalView.updateConnectionSize()
        }

        pendingLayoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + layoutSettleDelay, execute: workItem)
    }
}
