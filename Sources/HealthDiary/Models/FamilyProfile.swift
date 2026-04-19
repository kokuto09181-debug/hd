import Foundation
import SwiftData

@Model
final class FamilyProfile {
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var members: [FamilyMember]

    init() {
        self.createdAt = Date()
        self.members = []
    }
}

@Model
final class FamilyMember {
    var name: String
    var ageGroup: AgeGroup
    var allergies: [String]
    var preferences: [String]
    var dislikes: [String]
    var isMainUser: Bool

    init(name: String, ageGroup: AgeGroup, isMainUser: Bool = false) {
        self.name = name
        self.ageGroup = ageGroup
        self.allergies = []
        self.preferences = []
        self.dislikes = []
        self.isMainUser = isMainUser
    }
}
