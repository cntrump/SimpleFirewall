/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the NEFilterDataProvider sub-class.
*/

import NetworkExtension
import os.log

/**
    The FilterDataProvider class handles connections that match the installed rules by prompting
    the user to allow or deny the connections.
 */
class FilterDataProvider: NEFilterDataProvider {

    // MARK: Properties

    // The TCP port which the filter is interested in.
	static let localPort = "8888"

    // MARK: NEFilterDataProvider

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {

        // Filter incoming TCP connections on port 8888
        let filterRules = ["0.0.0.0", "::"].map { address -> NEFilterRule in
            let localNetwork = NWHostEndpoint(hostname: address, port: FilterDataProvider.localPort)
            let inboundNetworkRule = NENetworkRule(remoteNetwork: nil,
                                                   remotePrefix: 0,
                                                   localNetwork: localNetwork,
                                                   localPrefix: 0,
                                                   protocol: .TCP,
                                                   direction: .inbound)
            return NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
        }

        // Allow all flows that do not match the filter rules.
        let filterSettings = NEFilterSettings(rules: filterRules, defaultAction: .allow)

        apply(filterSettings) { error in
            if let applyError = error {
                os_log("Failed to apply filter settings: %@", applyError.localizedDescription)
            }
            completionHandler(error)
        }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {

        completionHandler()
    }
    
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {

        guard let socketFlow = flow as? NEFilterSocketFlow,
            let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint,
            let localEndpoint = socketFlow.localEndpoint as? NWHostEndpoint else {
                return .allow()
        }

        os_log("Got a new flow with local endpoint %@, remote endpoint %@", localEndpoint, remoteEndpoint)

        let flowInfo = [
            FlowInfoKey.localPort.rawValue: localEndpoint.port,
            FlowInfoKey.remoteAddress.rawValue: remoteEndpoint.hostname
        ]

        // Ask the app to prompt the user
        let prompted = IPCConnection.shared.promptUser(aboutFlow: flowInfo) { allow in
            let userVerdict: NEFilterNewFlowVerdict = allow ? .allow() : .drop()
            self.resumeFlow(flow, with: userVerdict)
        }

        guard prompted else {
            return .allow()
        }

        return .pause()
    }
}
