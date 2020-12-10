import NIO
import Network
import Foundation

let host = "scanme.nmap.org"
let port: UInt16 = 80

print("System cores: \(System.coreCount)\n")
let evGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

let ev = evGroup.next()


enum ScanError: Error {
  case noConn(String)
}

@available(OSX 10.14, *)
class Connection {
  let port: NWEndpoint.Port
  var connection: NWConnection?
  var promise: EventLoopPromise<Int>
  var id: Int
  
  init(port: UInt16, eLoop: EventLoop, id: Int) {
    self.port = NWEndpoint.Port(rawValue: port)!
    self.promise = eLoop.makePromise(of: Int.self)
    self.id = id
  }
  
  func setupNWConnection() -> EventLoopFuture<Int> {
//    print("Setting up nwConnection")
    
    let hostEndpoint = NWEndpoint.Host.init(host)
    connection = NWConnection(host: hostEndpoint, port: port, using: .tcp)
    connection!.stateUpdateHandler = self.stateDidChange(to:)
    self.setupReceive()
    print("Scanning \(host):\(port.rawValue)")
    connection!.start(queue: DispatchQueue.global())
    return promise.futureResult
  }
  
  private func stateDidChange(to state: NWConnection.State) {
      switch state {
      case .ready:
        print("connection #\(id) connected to \(connection!.endpoint) - sending message")
        connection!.send(content: Data([0x04, 0, 0, 0x17, 0, 0, 0, 0, 0x12, 0, 0, 0, 0, 0, 0, 0]), completion: .idempotent)
//        connection?.cancel()
//        promise.succeed(port.rawValue)
      case .failed(let error):
        print("Port \(port.rawValue) is totes closed")
        let errorMessage = "Error: \(error.localizedDescription)"
        connection?.cancel()
        promise.fail(ScanError.noConn(errorMessage))
      case .waiting(let error):
        print("Port \(port.rawValue) is totes closed")
        let errorMessage = "Error: \(error.localizedDescription)"
        promise.fail(ScanError.noConn(errorMessage))
      default:
//        print("Port \(port) is now in state \(state)")
        break
      }
  }
  
  private func setupReceive() {
    self.connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, isComplete, error) in
      if let data = data, !data.isEmpty {
          let message = String(data: data, encoding: .utf8)
        print("connection #\(self.id) did receive, data: \(data.map { String(format: "%02x", $0) }) string: \(message ?? "-" )")
        self.promise.succeed(self.id)
      }
      if isComplete {
        print("connection \(self.id) completed")
      } else if let error = error {
        print("connection \(self.id) error: \(error)")
        self.promise.fail(error)
      } else {
        self.connection!.cancel()
      }
    }
  }

}

// Async code
@available(OSX 10.14, *)
func scan(port: UInt16, id: Int) -> EventLoopFuture<Int> {
  let conn = Connection(port: port, eLoop: evGroup.next(), id: id)
  return conn.setupNWConnection()
}

if #available(OSX 10.14, *) {
//  let futures: [EventLoopFuture<UInt16>] = (UInt16(20)...80).map {
//  let futures: [EventLoopFuture<UInt16>] = [UInt16(20), 22, 25, 80].map {
  let futures: [EventLoopFuture<Int>] = (0..<32).map {
    scan(port: port, id: $0)
  }

  print("Scanning...")
  let scanResult = try EventLoopFuture.whenAllComplete(futures, on: evGroup.next()).wait()
  let found = scanResult.filter { res in switch res { case .success: return true case .failure: return false} }.map { try! $0.get() }
  print("\n\n")
  for id in found.sorted() { print("Send #\(id) worked.") }

print("Scan done!")

try evGroup.syncShutdownGracefully()
} else {
  print("Upgrade your OS, bro.")
}
//import Foundation
//
//// =============================================================================
//// MARK: Helpers
//
//struct CustomError: LocalizedError, CustomStringConvertible {
//    var title: String
//    var code: Int
//    var description: String { errorDescription() }
//
//    init(title: String?, code: Int) {
//        self.title = title ?? "Error"
//        self.code = code
//    }
//
//    func errorDescription() -> String {
//        "\(title) (\(code))"
//    }
//}
//
//// MARK: Async code
//func asyncDownload(on ev: EventLoop, urlString: String) -> EventLoopFuture<String> {
//    // Prepare the promise
//    let promise = ev.makePromise(of: String.self)
//
//    // Do the async work
//    let url = URL(string: urlString)!
//
//    let task = URLSession.shared.dataTask(with: url) { data, response, error in
//        print("Task done")
//        if let error = error {
//            promise.fail(error)
//            return
//        }
//        if let httpResponse = response as? HTTPURLResponse {
//            if (200...299).contains(httpResponse.statusCode) {
//                if let mimeType = httpResponse.mimeType, mimeType == "text/html",
//                    let data = data,
//                    let string = String(data: data, encoding: .utf8) {
//                    promise.succeed(string)
//                    return
//                }
//            } else {
//                // TODO: Analyse response for better error handling
//                let httpError = CustomError(title: "HTTP error", code: httpResponse.statusCode)
//                promise.fail(httpError)
//                return
//            }
//        }
//        let err = CustomError(title: "no or invalid data returned", code: 0)
//        promise.fail(err)
//    }
//    task.resume()
//
//    // Return the promise of a future result
//    return promise.futureResult
//}
//
//// =============================================================================
//// MARK: Main
//
//print("System cores: \(System.coreCount)\n")
//let evGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
//
//let ev = evGroup.next()
//
//print("Waiting...")
//
//let future = asyncDownload(on: ev, urlString: "https://www.process-one.net/en/")
//future.whenSuccess { page in
//    print("Page received")
//}
//future.whenFailure { error in
//    print("Error: \(error)")
//}
//
//// Timeout: As processing is async, we can handle timeout by just waiting in
//// main thread before quitting.
//// => Waiting 10 seconds for completion
//sleep(10)
//
//try evGroup.syncShutdownGracefully()
