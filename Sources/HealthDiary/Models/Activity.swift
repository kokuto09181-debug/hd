import Foundation
import SwiftData

@Model
final class ActivityGoal {
    var dailySteps: Int
    var dailyActiveCalories: Double
    var updatedAt: Date

    init(dailySteps: Int = 8000, dailyActiveCalories: Double = 500) {
        self.dailySteps = dailySteps
        self.dailyActiveCalories = dailyActiveCalories
        self.updatedAt = Date()
    }
}

@Model
final class ManualWorkout {
    var workoutType: WorkoutType
    var durationMinutes: Int
    var estimatedCalories: Double
    var performedAt: Date
    var notes: String

    init(workoutType: WorkoutType, durationMinutes: Int, estimatedCalories: Double) {
        self.workoutType = workoutType
        self.durationMinutes = durationMinutes
        self.estimatedCalories = estimatedCalories
        self.performedAt = Date()
        self.notes = ""
    }
}
