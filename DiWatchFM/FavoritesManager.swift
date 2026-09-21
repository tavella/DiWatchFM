import Foundation

@Observable
final class FavoritesManager {
    static let shared = FavoritesManager()
    
    private let favoritesKey = "com.di.watchfm.favoriteChannelIds"
    
    var favoriteIds: Set<Int> = []
    
    init() {
        if let saved = UserDefaults.standard.array(forKey: favoritesKey) as? [Int] {
            self.favoriteIds = Set(saved)
        } else {
            // Seed with user's DI.FM account favorite channel IDs
            let seedIds: [Int] = [174, 66, 125, 290, 70, 8, 1, 286, 215, 424, 57, 15, 289, 2]
            self.favoriteIds = Set(seedIds)
            save()
        }
    }
    
    func isFavorite(channelId: Int) -> Bool {
        favoriteIds.contains(channelId)
    }
    
    func toggleFavorite(channelId: Int) {
        if favoriteIds.contains(channelId) {
            favoriteIds.remove(channelId)
        } else {
            favoriteIds.insert(channelId)
        }
        save()
    }
    
    func favoriteChannels(from allChannels: [Channel]) -> [Channel] {
        allChannels.filter { favoriteIds.contains($0.id) }
    }
    
    private func save() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: favoritesKey)
    }
}
