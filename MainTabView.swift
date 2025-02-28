import SwiftUI

struct MainTabView: View {
    @Binding var isDarkMode: Bool
    @StateObject private var userState = UserState()
    @State private var isTimerRunning = false
    @State private var timeRemaining = 25 * 60 // 25 minutes in seconds

    var body: some View {
        TabView {
            DashboardView(isDarkMode: $isDarkMode, userState: userState, isTimerRunning: $isTimerRunning, timeRemaining: $timeRemaining)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
            
            TimerView(isDarkMode: $isDarkMode, userState: userState, isTimerRunning: $isTimerRunning, timeRemaining: $timeRemaining)
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
            
            CalendarView(isDarkMode: $isDarkMode, userState: userState)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            
            AssistantView(isDarkMode: $isDarkMode, userState: userState)
                .tabItem {
                    Label("Assistant", systemImage: "person.circle")
                }
            
            GamesView(isDarkMode: $isDarkMode, userState: userState)
                .tabItem {
                    Label("Games", systemImage: "gamecontroller")
                }
        }
    }
}
