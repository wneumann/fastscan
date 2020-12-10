import NIO
import Network

let host = "scanme.nmap.org"
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
  var promise: EventLoopPromise<UInt16>
  
  init(port: UInt16, eLoop: EventLoop) {
    self.port = NWEndpoint.Port(rawValue: port)!
    self.promise = eLoop.makePromise(of: UInt16.self)
  }
  
  func setupNWConnection() -> EventLoopFuture<UInt16> {
//    print("Setting up nwConnection")
    
    let hostEndpoint = NWEndpoint.Host.init(host)
    connection = NWConnection(host: hostEndpoint, port: port, using: .tcp)
    connection!.stateUpdateHandler = self.stateDidChange(to:)
  //    self.setupReceive(on: nwConnection)
    print("Scanning \(host):\(port.rawValue)")
    connection!.start(queue: DispatchQueue.global())
    return promise.futureResult
  }
  
  private func stateDidChange(to state: NWConnection.State) {
      switch state {
      case .ready:
        print("Port \(port.rawValue) is way open")
        connection?.cancel()
        promise.succeed(port.rawValue)
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

}

// Async code
@available(OSX 10.14, *)
func scan(port: UInt16) -> EventLoopFuture<UInt16> {
  let conn = Connection(port: port, eLoop: evGroup.next())
  return conn.setupNWConnection()
}

//func asyncPrint(on eLoop: EventLoop, delayInSecond: UInt32, string: String) -> EventLoopFuture<Int> {
//    // Do the async work
//    let promise = eLoop.submit {
//      return sleepAndPrint(delayInSecond: delayInSecond, string: string)
//    }
//
//    // Return the promise
//    return promise
//}
//
//func sleepAndPrint(delayInSecond: UInt32, string: String) -> Int {
//    sleep(delayInSecond)
//    print(string)
//  return(2 * Int(delayInSecond))
//}

// ===========================
// Main program

//let future = asyncPrint(on: ev, delayInSecond: 3, string: "Hello, ")

if #available(OSX 10.14, *) {
  let futures: [EventLoopFuture<UInt16>] = (UInt16(20)...80).map {
//  let futures: [EventLoopFuture<UInt16>] = [UInt16(20), 22, 25, 80].map {
    scan(port: $0)
  }

  print("Scanning...")
  let scanResult = try EventLoopFuture.whenAllComplete(futures, on: evGroup.next()).wait()
  let found = scanResult.filter { res in switch res { case .success: return true case .failure: return false} }.map { try! $0.get() }
  print("\n\n")
  for port in found.sorted() { print("Port \(port) is open.") }
//for res in zoop {
//  switch res {
//  case .success(let dub): print("dub: \(dub)")
//  case .failure: print("dunno. borked.")
//  }
//}
//let _ = try future.wait()

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
