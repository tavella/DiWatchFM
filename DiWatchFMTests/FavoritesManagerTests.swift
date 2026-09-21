import XCTest
@testable import DiWatchApp

final class FavoritesManagerTests: XCTestCase {

    private let favoritesKey = "com.di.watchfm.favoriteChannelIds"
    private var originalFavorites: [Int]?

    override func setUp() {
        super.setUp()
        originalFavorites = UserDefaults.standard.array(forKey: favoritesKey) as? [Int]
    }

    override func tearDown() {
        if let original = originalFavorites {
            UserDefaults.standard.set(original, forKey: favoritesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: favoritesKey)
        }
        super.tearDown()
    }

    func testInitialFavoritesLoaded() {
        let manager = FavoritesManager.shared
        XCTAssertFalse(manager.favoriteIds.isEmpty, "FavoritesManager should have initial favorite channel IDs")
    }

    func testToggleFavoriteAddsAndRemoves() {
        let manager = FavoritesManager.shared
        let testChannelId = 999999

        // Ensure it starts unfavorited
        if manager.isFavorite(channelId: testChannelId) {
            manager.toggleFavorite(channelId: testChannelId)
        }
        XCTAssertFalse(manager.isFavorite(channelId: testChannelId))

        // Toggle on
        manager.toggleFavorite(channelId: testChannelId)
        XCTAssertTrue(manager.isFavorite(channelId: testChannelId))
        let savedAfterAdd = UserDefaults.standard.array(forKey: favoritesKey) as? [Int] ?? []
        XCTAssertTrue(savedAfterAdd.contains(testChannelId), "UserDefaults should persist the newly added favorite")

        // Toggle off
        manager.toggleFavorite(channelId: testChannelId)
        XCTAssertFalse(manager.isFavorite(channelId: testChannelId))
        let savedAfterRemove = UserDefaults.standard.array(forKey: favoritesKey) as? [Int] ?? []
        XCTAssertFalse(savedAfterRemove.contains(testChannelId), "UserDefaults should reflect removal of favorite")
    }

    func testFavoriteChannelsFiltering() {
        let manager = FavoritesManager.shared
        let ch1 = Channel(id: 101, key: "c1", name: "C1", description: "", assetUrl: nil, channelFilterIds: nil)
        let ch2 = Channel(id: 102, key: "c2", name: "C2", description: "", assetUrl: nil, channelFilterIds: nil)
        let ch3 = Channel(id: 103, key: "c3", name: "C3", description: "", assetUrl: nil, channelFilterIds: nil)

        // Make sure only 101 and 103 are favorites
        if !manager.isFavorite(channelId: 101) { manager.toggleFavorite(channelId: 101) }
        if manager.isFavorite(channelId: 102) { manager.toggleFavorite(channelId: 102) }
        if !manager.isFavorite(channelId: 103) { manager.toggleFavorite(channelId: 103) }

        let filtered = manager.favoriteChannels(from: [ch1, ch2, ch3])
        let filteredIds = filtered.map { $0.id }

        XCTAssertTrue(filteredIds.contains(101))
        XCTAssertFalse(filteredIds.contains(102))
        XCTAssertTrue(filteredIds.contains(103))
        XCTAssertEqual(filtered.count, 2)

        // Clean up
        if manager.isFavorite(channelId: 101) { manager.toggleFavorite(channelId: 101) }
        if manager.isFavorite(channelId: 103) { manager.toggleFavorite(channelId: 103) }
    }
}
