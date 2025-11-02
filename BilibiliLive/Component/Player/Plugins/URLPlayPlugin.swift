import AVKit
import Foundation

class URLPlayPlugin: NSObject {
    var onPlayFail: (() -> Void)?

    private weak var playerVC: AVPlayerViewController?
    private let referer: String
    private let isLive: Bool
    private var currentUrl: String?

    // ✅ 记住 observer，避免重复 add
    private var accessLogObserver: NSObjectProtocol?

    init(referer: String = "", isLive: Bool = false) {
        self.referer = referer
        self.isLive = isLive
    }

    func play(urlString: String) {
        currentUrl = urlString
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": referer,
        ]

        let asset = AVURLAsset(
            url: URL(string: urlString)!,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let playerItem = AVPlayerItem(asset: asset)

        // ✅ 千兆：不限制，交给 AVPlayer 自己挑最高
        playerItem.preferredPeakBitRate = 0

        let player = AVPlayer(playerItem: playerItem)

        // ✅ 点播别太积极降码率
        if !isLive {
            player.automaticallyWaitsToMinimizeStalling = false
        }

        playerVC?.player = player

        // ✅ 先把旧的观察者移掉，避免多次添加
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
            self.accessLogObserver = nil
        }

        // ✅ 放到下一个 runloop，确保 currentItem 已经挂好了
        DispatchQueue.main.async { [weak self, weak player] in
            guard let self = self, let player = player else { return }

            self.accessLogObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewAccessLogEntry,
                object: player.currentItem,
                queue: .main
            ) { _ in
                if let log = player.currentItem?.accessLog()?.events.last {
                    print("🎥 bitrate(indicated): \(log.indicatedBitrate)  observed: \(log.observedBitrate)")
                } else {
                    print("🎥 no access log yet")
                }
            }
        }
    }
}

extension URLPlayPlugin: CommonPlayerPlugin {
    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.requiresLinearPlayback = isLive
        playerVC.player = nil
        if let currentUrl {
            play(urlString: currentUrl)
        }
    }

    func playerDidFail(player: AVPlayer) {
        onPlayFail?()
    }

    func playerDidPause(player: AVPlayer) {
        if isLive {
            onPlayFail?()
        }
    }
}
