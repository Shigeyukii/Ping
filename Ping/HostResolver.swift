import Foundation
import Darwin

struct HostResolver {

    /// ホスト名をIPアドレスに解決する（既にIPなら即返す）
    static func resolve(_ host: String) async -> String? {
        if isIPAddress(host) { return host }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_socktype = SOCK_STREAM
                var res: UnsafeMutablePointer<addrinfo>? = nil

                guard getaddrinfo(host, nil, &hints, &res) == 0,
                      let info = res else {
                    continuation.resume(returning: nil)
                    return
                }
                defer { freeaddrinfo(res) }

                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                var addr = info.pointee.ai_addr.pointee

                if addr.sa_family == sa_family_t(AF_INET) {
                    var sin = withUnsafeBytes(of: &addr) { $0.load(as: sockaddr_in.self) }
                    inet_ntop(AF_INET, &sin.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                } else {
                    var sin6 = withUnsafeBytes(of: &addr) { $0.load(as: sockaddr_in6.self) }
                    inet_ntop(AF_INET6, &sin6.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
                }
                continuation.resume(returning: String(cString: buffer))
            }
        }
    }

    static func isIPAddress(_ s: String) -> Bool {
        var a4 = in_addr()
        var a6 = in6_addr()
        return inet_pton(AF_INET, s, &a4) == 1 || inet_pton(AF_INET6, s, &a6) == 1
    }
}