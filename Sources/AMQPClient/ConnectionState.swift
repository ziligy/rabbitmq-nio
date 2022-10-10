//===----------------------------------------------------------------------===//
//
// This source file is part of the RabbitMQNIO project
//
// Copyright (c) 2022 Krzysztof Majk
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AMQPProtocol

internal enum ConnectionState {
    case connecting

    enum ConnectionAction {
        case start(channelID: Frame.ChannelID, user: String, pass: String)
        case tuneOpen(channelMax: UInt16, frameMax: UInt32, heartbeat: UInt16, vhost: String)
        case heartbeat(channelID: Frame.ChannelID)
        case channel(Frame.ChannelID, Frame)
        case connected
        case close
        case none
    }

    func errorHappened(_ error: ProtocolError) -> ConnectionAction {
        return .close
    }
}
