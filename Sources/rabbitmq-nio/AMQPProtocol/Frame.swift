import NIOCore

public typealias ChannelID = UInt16

public typealias Table = [String:Any]

protocol PayloadDecodable {
    static func decode(from buffer: inout ByteBuffer) throws -> Self
}

protocol PayloadEncodable {
    func encode(into buffer: inout ByteBuffer) throws
}

public enum Frame: PayloadDecodable, PayloadEncodable {
    case method(ChannelID, Method)
    case heartbeat(ChannelID)
    case body(ChannelID, body: [UInt8])

    enum `Type` {
        case method
        case body
        case heartbeat

        init?(rawValue: UInt8)
        {
            switch rawValue {
            case 1:
                self = .method
            case 3:
                self = .body
            case 8:
                self = .heartbeat
            default:
                return nil
            }
        }

        var rawValue: UInt8 {
            switch self {
                case .method:
                    return 1
                case .body:
                    return 3
                case .heartbeat:
                    return 8
            }
        }
    }

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let rawType = buffer.readInteger(as: UInt8.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        guard let channelId = buffer.readInteger(as: ChannelID.self) else {
            throw DecodeError.value(type: ChannelID.self)
        }

        // TODO(funcmike): use this later for Body frame
        guard let size = buffer.readInteger(as: UInt32.self) else {
            throw DecodeError.value(type: UInt32.self)
        }

        let frame: Frame
        
        switch Type(rawValue: rawType) {
        case .method:
            frame = Self.method(channelId, try! Method.decode(from: &buffer))
        case .heartbeat:
            frame = Self.heartbeat(channelId)
        case .body:
            guard let body = buffer.readBytes(length: Int(size)) else {
                throw DecodeError.value(type: [UInt8].self)
            }
            frame = Self.body(channelId, body: body)
        default:
            throw DecodeError.unsupported(value: rawType)
        }

        guard let endFrame = buffer.readInteger(as: UInt8.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        guard endFrame == 206 else {
            throw DecodeError.unsupported(value: endFrame)
        }

        return frame
    }

    func encode(into buffer: inout ByteBuffer) throws {
        switch self {
            case .method(let channelID, let method):
                buffer.writeInteger(`Type`.method.rawValue)
                buffer.writeInteger(channelID)
                
                let startIndex = buffer.writerIndex
                buffer.writeInteger(UInt32(0)) // placeholder for size
                                
                try! method.encode(into: &buffer)

                let size = UInt32(buffer.writerIndex - startIndex - 4)
                buffer.setInteger(size, at: startIndex)

                buffer.writeInteger(UInt8(206)) // endMarker
            case .body(let channelID, let body):
                buffer.writeInteger(`Type`.body.rawValue)
                buffer.writeInteger(channelID)
                buffer.writeInteger(body.count)
                buffer.writeBytes(body)
                buffer.writeInteger(UInt8(206)) // endMarker
            case .heartbeat(let channelID):
                buffer.writeInteger(`Type`.heartbeat.rawValue)
                buffer.writeInteger(channelID)
                buffer.writeInteger(UInt32(0))
                buffer.writeInteger(UInt8(206)) // endMarker
            }
    }
}

public enum Method: PayloadDecodable, PayloadEncodable {
    case connection(Connection)

    enum ID {
        case connection

        init?(rawValue: UInt16)
        {
            switch rawValue {
            case 10:
                self = .connection
            default:
                return nil
            }
        }

        var rawValue: UInt16 {
            switch self {
                case .connection:
                    return 10
            }
        }
    }

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let rawID = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }
    
        switch ID(rawValue: rawID) {
            case .connection:
                return .connection(try! Connection.decode(from: &buffer))
            default:
                throw DecodeError.unsupported(value: rawID)
        }
    }

    func encode(into buffer: inout ByteBuffer) throws {
        switch self {
            case .connection(let connection):
                buffer.writeInteger(ID.connection.rawValue)
                try! connection.encode(into: &buffer)
                return
        }
    }
}

public enum Connection: PayloadDecodable, PayloadEncodable {
    case start(ConnectionStart)
    case startOk(ConnnectionStartOk)
    case tune(Tune)
    case tuneOk(TuneOk)
    case open(Open)
    case openOk(OpenOk)
    case close(Close)
    case closeOk
    case blocked(Blocked)
    case unblocked


    public enum ID {
        case start
        case startOk
        case tune
        case tuneOk
        case open
        case openOk
        case close
        case closeOk
        case blocked
        case unblocked

        init?(rawValue: UInt16)
        {
            switch rawValue {
            case 10:
                self = .start
            case 11:
                self = .startOk
            case 30:
                self = .tune
            case 31:
                self = .tuneOk
            case 40:
                self = .open
            case 41:
                self = .openOk
            case 50:
                self = .close
            case 51:
                self = .closeOk
            case 60:
                self = .blocked
            case 61:
                self = .unblocked
            default:
                return nil
            }
        }

        var rawValue: UInt16 {
            switch self {
                case .start:
                    return 10
                case .startOk:
                    return 11
                case .tune:
                    return 30
                case .tuneOk:
                    return 31
                case .open:
                    return 40
                case .openOk:
                    return 41
                case .blocked: 
                    return 50
                case .unblocked: 
                    return 51
                case .close: 
                    return 60
                case .closeOk: 
                    return 61
                }
        }
    }

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let rawID = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }
    
        switch ID(rawValue: rawID) {
            case .start:
                return .start(try! ConnectionStart.decode(from: &buffer))
            case .startOk:
                return .startOk(try! ConnnectionStartOk.decode(from: &buffer))
            case .tune:
                return .tune(try! Tune.decode(from: &buffer))
            case .tuneOk:
                return .tuneOk(try! TuneOk.decode(from: &buffer))
            case .open:
                return .open(try! Open.decode(from: &buffer))
            case .openOk:
                return .openOk(try! OpenOk.decode(from: &buffer))
            case .close:
                return .close(try! Close.decode(from: &buffer))
            case .closeOk:
                return .closeOk
            case .blocked:
                return .blocked(try! Blocked.decode(from: &buffer))
            case .unblocked:
                return .unblocked
            default:
                throw DecodeError.unsupported(value: rawID)
        }
    }

    func encode(into buffer: inout ByteBuffer) throws {
        switch self {
            case .start(let connectionStart):
                buffer.writeInteger(ID.start.rawValue)
                try! connectionStart.encode(into: &buffer)
            case .startOk(let connectionStartOk):
                buffer.writeInteger(ID.startOk.rawValue)
                try! connectionStartOk.encode(into: &buffer)
            case .tune(let tune):
                buffer.writeInteger(ID.tune.rawValue)
                try! tune.encode(into: &buffer)
            case .tuneOk(let tuneOk):
                buffer.writeInteger(ID.tuneOk.rawValue)
                try! tuneOk.encode(into: &buffer)
            case .open(let open): 
                buffer.writeInteger(ID.open.rawValue)
                try! open.encode(into: &buffer)
            case .openOk(let openOk): 
                buffer.writeInteger(ID.openOk.rawValue)
                try! openOk.encode(into: &buffer)
            case .close(let close):
                buffer.writeInteger(ID.close.rawValue)
                try! close.encode(into: &buffer)
            case .closeOk: 
                buffer.writeInteger(ID.closeOk.rawValue)
            case .blocked(let blocked):
                buffer.writeInteger(ID.blocked.rawValue)
                try! blocked.encode(into: &buffer)
            case .unblocked:
                buffer.writeInteger(ID.unblocked.rawValue)
        }
    }
}

public struct ConnectionStart: PayloadDecodable {
    let versionMajor: UInt8
    let versionMinor: UInt8
    let serverProperties: Table
    let mechanisms: String
    let locales: String

    init(versionMajor: UInt8 = 0, versionMinor: UInt8 = 9, serverProperties: Table = [
                           "capabilities": [
                             "publisher_confirms":           true,
                             "exchange_exchange_bindings":   true,
                             "basic.nack":                   true,
                             "per_consumer_qos":             true,
                             "authentication_failure_close": true,
                             "consumer_cancel_notify":       true,
                             "connection.blocked":           true,
                           ]
                        ], mechanisms: String = "AMQPLAIN PLAIN", locales: String = "en_US")
    {
        self.versionMajor = versionMajor
        self.versionMinor = versionMinor
        self.serverProperties = serverProperties 
        self.mechanisms = mechanisms
        self.locales = locales
    }

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let versionMajor = buffer.readInteger(as: UInt8.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        guard let versionMinor = buffer.readInteger(as: UInt8.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        let serverProperties: Table

        do {
            (serverProperties, _) = try readDictionary(from: &buffer)
        } catch let error as DecodeError {
            throw DecodeError.value(type: Table.self, inner: error)
        }

        guard let (mechanisms, _) = readLongStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        guard  let (locales, _) = readLongStr(from: &buffer)  else {
            throw DecodeError.value(type: String.self)
        }

        return ConnectionStart(versionMajor: versionMajor, versionMinor: versionMinor, serverProperties: serverProperties, mechanisms: mechanisms, locales: locales)
    }

    func encode(into buffer: inout ByteBuffer) throws {
        buffer.writeInteger(versionMajor)
        buffer.writeInteger(versionMinor)

        do {
            try writeDictionary(values: serverProperties, into: &buffer)
        } catch let error as EncodeError {
            throw EncodeError.value(type: Table.self, inner: error)
        }
        
        writeLongStr(value: mechanisms, into: &buffer)
        writeLongStr(value: locales, into: &buffer)
    }
}

public struct ConnnectionStartOk: PayloadDecodable, PayloadEncodable {
    let clientProperties: Table
    let mechanism: String
    let response: String
    let locale: String

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        let clientProperties: Table
 
        do {
            (clientProperties, _) = try readDictionary(from: &buffer)
        } catch let error as DecodeError {
            throw DecodeError.value(type: Table.self, inner: error)
        }

        guard let (mechanism, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        guard  let (response, _) = readLongStr(from: &buffer)  else {
            throw DecodeError.value(type: String.self)
        }

        guard  let (locale, _) = readShortStr(from: &buffer)  else {
            throw DecodeError.value(type: String.self)
        }

        return ConnnectionStartOk(clientProperties: clientProperties, mechanism: mechanism, response: response, locale: locale)
    }

    func encode(into buffer: inout ByteBuffer) throws {
        do {
            try writeDictionary(values: clientProperties, into: &buffer)
        } catch let error as EncodeError {
            throw EncodeError.value(type: Table.self, inner: error)
        }

        writeShortStr(value: mechanism, into: &buffer)
        writeLongStr(value: response, into: &buffer)
        writeShortStr(value: locale, into: &buffer)
    }
}

public struct Tune: PayloadDecodable, PayloadEncodable {
    let channelMax: UInt16
    let frameMax: UInt32
    let heartbeat: UInt16

    init(channelMax: UInt16 = 0, frameMax: UInt32 = 131072, heartbeat: UInt16 = 0)
    {
        self.channelMax = channelMax
        self.frameMax = frameMax
        self.heartbeat = heartbeat
    }
    
    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let channelMax = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }

        guard let frameMax = buffer.readInteger(as: UInt32.self) else {
            throw DecodeError.value(type: UInt32.self)
        }

        guard let heartbeat = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }

        return Tune(channelMax: channelMax, frameMax: frameMax, heartbeat: heartbeat)       
    }

    func encode(into buffer: inout ByteBuffer) throws {
        buffer.writeInteger(channelMax)
        buffer.writeInteger(frameMax)
        buffer.writeInteger(heartbeat)
    }
}


public struct TuneOk: PayloadDecodable, PayloadEncodable {
    let channelMax: UInt16
    let frameMax: UInt32
    let heartbeat: UInt16

    init(channelMax: UInt16 = 0, frameMax: UInt32 = 131072, heartbeat: UInt16 = 60)
    {
        self.channelMax = channelMax
        self.frameMax = frameMax
        self.heartbeat = heartbeat
    }
    
    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let channelMax = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }

        guard let frameMax = buffer.readInteger(as: UInt32.self) else {
            throw DecodeError.value(type: UInt32.self)
        }

        guard let heartbeat = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt16.self)
        }

        return TuneOk(channelMax: channelMax, frameMax: frameMax, heartbeat: heartbeat)       
    }

    func encode(into buffer: inout ByteBuffer) throws {
        buffer.writeInteger(channelMax)
        buffer.writeInteger(frameMax)
        buffer.writeInteger(heartbeat)
    }
}


public struct Open: PayloadDecodable, PayloadEncodable {
    let vhost: String
    let reserved1: String
    let reserved2: Bool

    init(vhost: String = "/", reserved1: String = "", reserved2: Bool = false)
    {
        self.vhost = vhost
        self.reserved1 = reserved1
        self.reserved2 = reserved2
    }
    
    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let (vhost, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        guard let (reserved1, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        guard let reserved2 = buffer.readInteger(as: UInt8.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        return Open(vhost: vhost, reserved1: reserved1, reserved2: reserved2 > 0 ? true : false)       
    }

    func encode(into buffer: inout ByteBuffer) throws {
        writeShortStr(value: vhost, into: &buffer)
        writeShortStr(value: reserved1, into: &buffer)
        buffer.writeInteger(reserved2 ? UInt8(1) : UInt8(0))
    }
}


public struct OpenOk: PayloadDecodable, PayloadEncodable {
    let reserved1: String

    init(reserved1: String = "")
    {
        self.reserved1 = reserved1
    }
    
    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let (reserved1, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        return OpenOk(reserved1: reserved1)       
    }

    func encode(into buffer: inout ByteBuffer) throws {
        writeShortStr(value: reserved1, into: &buffer)
    }
}


public struct Close: PayloadDecodable, PayloadEncodable {
    let replyCode: UInt16
    let replyText: String
    let failingClassID: UInt16
    let failingMethodID:  UInt16

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let replyCode = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        guard let (replyText, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        guard let failingClassID = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        guard let failingMethodID = buffer.readInteger(as: UInt16.self) else {
            throw DecodeError.value(type: UInt8.self)
        }

        return Close(replyCode: replyCode, replyText: replyText, failingClassID: failingClassID, failingMethodID: failingMethodID)
    }

    func encode(into buffer: inout ByteBuffer) throws {
        buffer.writeInteger(replyCode)
        writeShortStr(value: replyText, into: &buffer)
        buffer.writeInteger(failingClassID)
        buffer.writeInteger(failingMethodID)        
    }
}

public struct Blocked: PayloadDecodable, PayloadEncodable {
    let reason: String

    static func decode(from buffer: inout ByteBuffer) throws -> Self {
        guard let (reason, _) = readShortStr(from: &buffer) else {
            throw DecodeError.value(type: String.self)
        }

        return Blocked(reason: reason)        
    }

    func encode(into buffer: inout ByteBuffer) throws {
        writeShortStr(value: reason, into: &buffer)
    }
}
