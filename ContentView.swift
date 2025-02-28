import SwiftUI
import Auth0
import JWTDecode
import UserNotifications

struct ContentView: View {
    @StateObject private var auth0Manager = Auth0Manager()
    @State private var selectedTab = 0
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var userState = UserState()
    @State private var isTimerRunning = false
    @State private var timeRemaining = 25 * 60 // 25 minutes in seconds

    var body: some View {
        Group {
            if auth0Manager.isAuthenticated {
                TabView(selection: $selectedTab) {
                    DashboardView(isDarkMode: $isDarkMode, userState: userState, isTimerRunning: $isTimerRunning, timeRemaining: $timeRemaining)
                        .tabItem {
                            Image(systemName: "house")
                            Text("Dashboard")
                        }
                        .tag(0)
                    
                    TimerView(isDarkMode: $isDarkMode, userState: userState, isTimerRunning: $isTimerRunning, timeRemaining: $timeRemaining)
                        .tabItem {
                            Image(systemName: "clock")
                            Text("Timer")
                        }
                        .tag(1)
                    
                    CalendarView(isDarkMode: $isDarkMode, userState: userState)
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("Calendar")
                        }
                        .tag(2)
                    
                    AssistantView(isDarkMode: $isDarkMode, userState: userState)
                        .tabItem {
                            Image(systemName: "person.circle")
                            Text("Assistant")
                        }
                        .tag(3)
                    
                    GamesView(isDarkMode: $isDarkMode, userState: userState)
                        .tabItem {
                            Image(systemName: "gamecontroller")
                            Text("Games")
                        }
                        .tag(4)
                    
                    SettingsView(isDarkMode: $isDarkMode, auth0Manager: auth0Manager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(5)
                }
                .accentColor(.purple)
                .preferredColorScheme(isDarkMode ? .dark : .light)
            } else {
                LoginView(auth0Manager: auth0Manager)
            }
        }
        .environmentObject(auth0Manager)
        .environmentObject(userState)
    }
}
struct AppTask: Identifiable, Codable {
    let id: UUID
    var text: String
    var completed: Bool
    
    init(id: UUID = UUID(), text: String, completed: Bool) {
        self.id = id
        self.text = text
        self.completed = completed
    }
}

struct Event: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
}
struct LoginView: View {
    @ObservedObject var auth0Manager: Auth0Manager
    
    var body: some View {
        VStack {
            Text("Welcome to StudyApp")
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                auth0Manager.login()
            }) {
                Text("Login with Auth0")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
            }
        }
    }
}

class UserState: ObservableObject {
    @Published var points: Int {
        didSet {
            UserDefaults.standard.set(points, forKey: "userPoints")
        }
    }
    @Published var level: Int {
        didSet {
            UserDefaults.standard.set(level, forKey: "userLevel")
        }
    }
    @Published var tasks: [AppTask] {
        didSet {
            if let encoded = try? JSONEncoder().encode(tasks) {
                UserDefaults.standard.set(encoded, forKey: "userTasks")
            }
        }
    }
    @Published var events: [Event] {
        didSet {
            if let encoded = try? JSONEncoder().encode(events) {
                UserDefaults.standard.set(encoded, forKey: "userEvents")
            }
        }
    }
    @Published var unlockedGames: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(unlockedGames), forKey: "unlockedGames")
        }
    }

    init() {
        self.points = UserDefaults.standard.integer(forKey: "userPoints")
        self.level = UserDefaults.standard.integer(forKey: "userLevel")
        if let savedTasks = UserDefaults.standard.data(forKey: "userTasks"),
           let decodedTasks = try? JSONDecoder().decode([AppTask].self, from: savedTasks) {
            self.tasks = decodedTasks
        } else {
            self.tasks = []
        }
        if let savedEvents = UserDefaults.standard.data(forKey: "userEvents"),
           let decodedEvents = try? JSONDecoder().decode([Event].self, from: savedEvents) {
            self.events = decodedEvents
        } else {
            self.events = []
        }
        if let savedGames = UserDefaults.standard.stringArray(forKey: "unlockedGames") {
            self.unlockedGames = Set(savedGames)
        } else {
            self.unlockedGames = ["Tic-Tac-Toe"] // Always unlock the first game
        }
    }

    func addPoints(_ amount: Int) {
        points += amount
        if points >= level * 100 {
            levelUp()
        }
    }

    private func levelUp() {
        level += 1
        unlockedGames.insert(Game.allCases[min(level - 1, Game.allCases.count - 1)].rawValue)
    }
}

struct DashboardView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var userState: UserState
    @Binding var isTimerRunning: Bool
    @Binding var timeRemaining: Int
    @State private var newTask = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    PointsView(userState: userState)
                    TaskListView(tasks: $userState.tasks, newTask: $newTask, userState: userState)
                    TimerCardView(userState: userState, isTimerRunning: $isTimerRunning, timeRemaining: $timeRemaining)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .background(Color(.systemBackground))
        }
    }
}

struct PointsView: View {
    @ObservedObject var userState: UserState

    var body: some View {
        VStack {
            Text("Level \(userState.level)")
                .font(.title)
                .fontWeight(.bold)
            Text("\(userState.points) Points")
                .font(.headline)
            ProgressView(value: Float(userState.points % 100), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct TimerView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var userState: UserState
    @Binding var isTimerRunning: Bool
    @Binding var timeRemaining: Int
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text(timeString(time: timeRemaining))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                
                Button(action: {
                    if !isTimerRunning {
                        userState.addPoints(10) // Award points when starting the timer
                    }
                    self.isTimerRunning.toggle()
                    if !isTimerRunning && timeRemaining == 0 {
                        userState.addPoints(50) // Award more points on timer completion
                        timeRemaining = 25 * 60
                    }
                }) {
                    Text(isTimerRunning ? "Pause" : (timeRemaining == 0 ? "Claim Points" : "Start"))
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(30)
                }
            }
            .navigationTitle("Study Timer")
            .background(Color(.systemBackground))
        }
        .onReceive(timer) { _ in
            if self.isTimerRunning && self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else if self.timeRemaining == 0 {
                self.isTimerRunning = false
            }
        }
    }
    
    func timeString(time: Int) -> String {
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
}

struct CalendarView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var userState: UserState
    @State private var selectedDate = Date()
    @State private var showingEventForm = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                List {
                    ForEach(userState.events.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) { event in
                        HStack {
                            Text(event.title)
                            Spacer()
                            Text(dateFormatter.string(from: event.date))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: deleteEvent)
                }
                
                Button("Add Event") {
                    showingEventForm = true
                }
                .padding()
            }
            .navigationTitle("Calendar")
            .background(Color(.systemBackground))
            .sheet(isPresented: $showingEventForm) {
                EventFormView(events: $userState.events, isPresented: $showingEventForm, userState: userState)
            }
        }
    }
    
    func deleteEvent(at offsets: IndexSet) {
        userState.events.remove(atOffsets: offsets)
    }
}

struct GamesView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var userState: UserState
    @State private var selectedGame: Game?
    
    enum Game: String, CaseIterable, Identifiable {
        case tictactoe = "Tic-Tac-Toe"
        case pong = "Pong"
        case flappyBird = "Flappy Bird"
        case memoryMatch = "Memory Match"
        case mathChallenge = "Math Challenge"
        case wordScramble = "Word Scramble"
        case quizMaster = "Quiz Master"
        
        var id: String { self.rawValue }
        
        var requiredLevel: Int {
            switch self {
            case .tictactoe: return 1
            case .pong: return 5
            case .flappyBird: return 10
            case .memoryMatch: return 15
            case .mathChallenge: return 20
            case .wordScramble: return 25
            case .quizMaster: return 30
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(Game.allCases) { game in
                        Button(action: {
                            if userState.unlockedGames.contains(game.rawValue) {
                                selectedGame = game
                            }
                        }) {
                            HStack {
                                Image(systemName: gameIcon(for: game))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                
                                Text(game.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if !userState.unlockedGames.contains(game.rawValue) {
                                    Text("Unlock at level \(game.requiredLevel)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(gradient: Gradient(colors: userState.unlockedGames.contains(game.rawValue) ? [.purple, .pink] : [.gray]), startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(10)
                            .opacity(userState.unlockedGames.contains(game.rawValue) ? 1 : 0.7)
                        }
                        .disabled(!userState.unlockedGames.contains(game.rawValue))
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Games")
            .background(Color(.systemBackground))
            .sheet(item: $selectedGame) { game in
                gameView(for: game)
            }
        }
    }
    
}
    
func gameIcon(for game: Game) -> String {
       switch game {
       case .tictactoe: return "number"
       case .pong: return "circle.fill"
       case .flappyBird: return "bird.fill"
       case .memoryMatch: return "brain"
       case .mathChallenge: return "sum"
       case .wordScramble: return "textformat.abc"
       case .quizMaster: return "questionmark.circle"
       }
   }
   
   @ViewBuilder
   func gameView(for game: Game) -> some View {
       switch game {
       case .tictactoe:
           TicTacToeView(UserManager: UserManager)
       case .pong:
           PongView(UserManager: UserManager)
       case .flappyBird:
           FlappyBirdView(UserManager: UserManager)
       case .memoryMatch:
           MemoryMatchView(UserManager: UserManager)
       case .mathChallenge:
           MathChallengeView(UserManager: UserManager)
       case .wordScramble:
           WordScrambleView(UserManager: UserManager)
       case .quizMaster:
           QuizMasterView(UserManager: UserManager)
       }
   }

struct TicTacToeView: View {
   @ObservedObject var UserManager: UserManager
   @State private var board = Array(repeating: "", count: 9)
   @State private var currentPlayer = "X"
   @State private var gameOver = false
   @State private var winner: String?
   
   var body: some View {
       VStack {
           Text("Tic-Tac-Toe")
               .font(.largeTitle)
               .padding()
           
           LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
               ForEach(0..<9) { index in
                   Button(action: {
                       if board[index].isEmpty && !gameOver {
                           board[index] = currentPlayer
                           checkWinner()
                           currentPlayer = currentPlayer == "X" ? "O" : "X"
                           if currentPlayer == "O" {
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                   computerMove()
                               }
                           }
                       }
                   }) {
                       Text(board[index])
                           .font(.system(size: 60))
                           .frame(width: 80, height: 80)
                           .background(Color(.secondarySystemBackground))
                           .cornerRadius(10)
                   }
               }
           }
           .padding()
           
           if gameOver {
               Text(winner == nil ? "It's a draw!" : "Winner: \(winner!)")
                   .font(.title)
                   .padding()
               
               Button("Play Again") {
                   resetGame()
               }
               .padding()
               .background(Color.purple)
               .foregroundColor(.white)
               .cornerRadius(10)
           }
       }
       .background(Color(.systemBackground))
   }
   
   func checkWinner() {
       let winningCombos = [
           [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
           [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
           [0, 4, 8], [2, 4, 6] // Diagonals
       ]
       
       for combo in winningCombos {
           if board[combo[0]] == board[combo[1]] && board[combo[1]] == board[combo[2]] && !board[combo[0]].isEmpty {
               gameOver = true
               winner = board[combo[0]]
               if winner == "X" {
                   UserManager.addPoints(20)
               }
               return
           }
       }
       
       if !board.contains("") {
           gameOver = true
       }
   }
   
   func computerMove() {
       var availableMoves = [Int]()
       for (index, value) in board.enumerated() {
           if value.isEmpty {
               availableMoves.append(index)
           }
       }
       
       if let move = availableMoves.randomElement() {
           board[move] = "O"
           checkWinner()
           currentPlayer = "X"
       }
   }
   
   func resetGame() {
       board = Array(repeating: "", count: 9)
       currentPlayer = "X"
       gameOver = false
       winner = nil
   }
}
struct PongView: View {
   @ObservedObject var UserManager: UserManager
   @State private var paddlePosition: CGFloat = 200
   @State private var ballPosition = CGPoint(x: 200, y: 300)
   @State private var ballVelocity = CGPoint(x: 5, y: 5)
   @State private var score = 0
   @State private var gameOver = false
   
   let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
   
   var body: some View {
       GeometryReader { geometry in
           ZStack {
               Color.black.edgesIgnoringSafeArea(.all)
               
               // Paddle
               Rectangle()
                   .fill(Color.white)
                   .frame(width: 100, height: 20)
                   .position(x: paddlePosition, y: geometry.size.height - 30)
               
               // Ball
               Circle()
                   .fill(Color.white)
                   .frame(width: 20, height: 20)
                   .position(ballPosition)
               
               // Score
               Text("Score: \(score)")
                   .foregroundColor(.white)
                   .font(.largeTitle)
                   .position(x: geometry.size.width / 2, y: 50)
               
               if gameOver {
                   VStack {
                       Text("Game Over")
                           .font(.largeTitle)
                           .foregroundColor(.white)
                       
                       Button("Play Again") {
                           resetGame()
                       }
                       .padding()
                       .background(Color.white)
                       .foregroundColor(.black)
                       .cornerRadius(10)
                   }
               }
           }
       }
       .gesture(
           DragGesture()
               .onChanged { value in
                   paddlePosition = value.location.x
               }
       )
       .onReceive(timer) { _ in
           if !gameOver {
               updateBallPosition()
           }
       }
   }
   
   func updateBallPosition() {
       ballPosition.x += ballVelocity.x
       ballPosition.y += ballVelocity.y
       
       // Bounce off walls
       if ballPosition.x <= 10 || ballPosition.x >= UIScreen.main.bounds.width - 10 {
           ballVelocity.x *= -1
       }
       
       // Bounce off ceiling
       if ballPosition.y <= 10 {
           ballVelocity.y *= -1
       }
       
       // Check for paddle hit
       if ballPosition.y >= UIScreen.main.bounds.height - 50 &&
          ballPosition.x >= paddlePosition - 50 &&
          ballPosition.x <= paddlePosition + 50 {
           ballVelocity.y *= -1
           score += 1
       }
       
       // Check for game over
       if ballPosition.y >= UIScreen.main.bounds.height {
           gameOver = true
           UserManager.addPoints(score)
       }
   }
   
   func resetGame() {
       ballPosition = CGPoint(x: 200, y: 300)
       ballVelocity = CGPoint(x: 5, y: 5)
       score = 0
       gameOver = false
   }
}
struct FlappyBirdView: View {
   @ObservedObject var UserManager: UserManager
   @State private var birdPosition = CGPoint(x: 100, y: 300)
   @State private var birdVelocity: CGFloat = 0
   @State private var pipes = [Pipe]()
   @State private var score = 0
   @State private var gameOver = false
   
   let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
   
   struct Pipe: Identifiable {
       let id = UUID()
       var x: CGFloat
       let gapY: CGFloat
       let gapHeight: CGFloat = 200
   }
   
   var body: some View {
       GeometryReader { geometry in
           ZStack {
               Color.cyan.edgesIgnoringSafeArea(.all)
               
               // Bird
               Circle()
                   .fill(Color.yellow)
                   .frame(width: 40, height: 40)
                   .position(birdPosition)
               
               // Pipes
               ForEach(pipes) { pipe in
                   Group {
                       Rectangle()
                           .fill(Color.green)
                           .frame(width: 60, height: pipe.gapY)
                           .position(x: pipe.x, y: pipe.gapY / 2)
                       
                       Rectangle()
                           .fill(Color.green)
                           .frame(width: 60, height: geometry.size.height - pipe.gapY - pipe.gapHeight)
                           .position(x: pipe.x, y: geometry.size.height - (geometry.size.height - pipe.gapY - pipe.gapHeight) / 2)
                   }
               }
               
               // Score
               Text("Score: \(score)")
                   .font(.largeTitle)
                   .position(x: geometry.size.width / 2, y: 50)
               
               if gameOver {
                   VStack {
                       Text("Game Over")
                           .font(.largeTitle)
                       
                       Button("Play Again") {
                           resetGame()
                       }
                       .padding()
                       .background(Color.white)
                       .foregroundColor(.black)
                       .cornerRadius(10)
                   }
               }
           }
       }
       .onReceive(timer) { _ in
           if !gameOver {
               updateGame()
           }
       }
       .onTapGesture {
           if !gameOver {
               birdVelocity = -10
           }
       }
   }
   
   func updateGame() {
       // Update bird position
       birdVelocity += 0.5
       birdPosition.y += birdVelocity
       
       // Update pipes
       for i in 0..<pipes.count {
           pipes[i].x -= 2
       }
       
       // Remove off-screen pipes
       pipes = pipes.filter { $0.x > -30 }
       
       // Add new pipes
       if pipes.isEmpty || pipes.last!.x < UIScreen.main.bounds.width - 200 {
           let newPipe = Pipe(x: UIScreen.main.bounds.width + 30, gapY: CGFloat.random(in: 100...500))
           pipes.append(newPipe)
       }
       
       // Check for collisions
       for pipe in pipes {
           if abs(pipe.x - birdPosition.x) < 50 {
               if birdPosition.y < pipe.gapY || birdPosition.y > pipe.gapY + pipe.gapHeight {
                   gameOver = true
                   UserManager.addPoints(score)
               }
           }
       }
       
       // Update score
       if let firstPipe = pipes.first, firstPipe.x < 100 && firstPipe.x > 98 {
           score += 1
       }
       
       // Check for out of bounds
       if birdPosition.y > UIScreen.main.bounds.height || birdPosition.y < 0 {
           gameOver = true
           UserManager.addPoints(score)
       }
   }
   
   func resetGame() {
       birdPosition = CGPoint(x: 100, y: 300)
       birdVelocity = 0
       pipes = []
       score = 0
       gameOver = false
   }
}
struct MemoryMatchView: View {
   @ObservedObject var UserManager: UserManager
   @State private var emojis = ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐸"].shuffled()
   @State private var flippedIndices: Set<Int> = []
   @State private var matchedIndices: Set<Int> = []
   @State private var score = 0
   @State private var moves = 0
   
   let columns = [
       GridItem(.flexible()),
       GridItem(.flexible()),
       GridItem(.flexible()),
       GridItem(.flexible())
   ]
   
   var body: some View {
       VStack {
           Text("Memory Match")
               .font(.largeTitle)
               .padding()
           
           Text("Score: \(score)")
               .font(.title)
           
           Text("Moves: \(moves)")
               .font(.title)
           
           LazyVGrid(columns: columns, spacing: 10) {
               ForEach(0..<12) { index in
                   CardView(emoji: emojis[index % 6], isFlipped: flippedIndices.contains(index) || matchedIndices.contains(index))
                       .onTapGesture {
                           withAnimation {
                               flipCard(at: index)
                           }
                       }
               }
           }
           .padding()
           
           if matchedIndices.count == 12 {
               Text("Congratulations! You won!")
                   .font(.title)
                   .padding()
               
               Button("Play Again") {
                   resetGame()
               }
               .padding()
               .background(Color.purple)
               .foregroundColor(.white)
               .cornerRadius(10)
           }
       }
   }
   
   func flipCard(at index: Int) {
       if flippedIndices.count == 2 || matchedIndices.contains(index) || flippedIndices.contains(index) {
           return
       }
       
       flippedIndices.insert(index)
       moves += 1
       
       if flippedIndices.count == 2 {
           let flippedCards = Array(flippedIndices)
           if emojis[flippedCards[0] % 6] == emojis[flippedCards[1] % 6] {
               matchedIndices.formUnion(flippedIndices)
               score += 2
               UserManager.addPoints(10)
           }
           
           DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
               flippedIndices.removeAll()
           }
       }
   }
   
   func resetGame() {
       emojis.shuffle()
       flippedIndices.removeAll()
       matchedIndices.removeAll()
       score = 0
       moves = 0
   }
}
struct CardView: View {
   let emoji: String
   let isFlipped: Bool
   
   var body: some View {
       ZStack {
           if isFlipped {
               RoundedRectangle(cornerRadius: 10)
                   .fill(Color.white)
                   .frame(width: 60, height: 80)
                   .overlay(
                       Text(emoji)
                           .font(.system(size: 40))
                   )
           } else {
               RoundedRectangle(cornerRadius: 10)
                   .fill(Color.purple)
                   .frame(width: 60, height: 80)
           }
       }
   }
}
struct MathChallengeView: View {
   @ObservedObject var UserManager: UserManager
   @State private var currentQuestion: MathQuestion?
   @State private var userAnswer = ""
   @State private var score = 0
   @State private var questionsAnswered = 0
   @State private var showingResult = false
   @State private var isCorrect = false
   
   var body: some View {
       VStack {
           Text("Math Challenge")
               .font(.largeTitle)
               .padding()
           
           Text("Score: \(score)")
               .font(.title)
           
           if let question = currentQuestion {
               Text(question.text)
                   .font(.title)
                   .padding()
               
               TextField("Your answer", text: $userAnswer)
                   .textFieldStyle(RoundedBorderTextFieldStyle())
                   .keyboardType(.numberPad)
                   .padding()
               
               Button("Submit") {
                   checkAnswer()
               }
               .padding()
               .background(Color.purple)
               .foregroundColor(.white)
               .cornerRadius(10)
           }
           
           if showingResult {
               Text(isCorrect ? "Correct!" : "Wrong!")
                   .font(.title)
                   .foregroundColor(isCorrect ? .green : .red)
                   .padding()
           }
       }
       .onAppear(perform: generateQuestion)
       .alert(isPresented: $showingResult) {
           Alert(
               title: Text(isCorrect ? "Correct!" : "Wrong!"),
               message: Text(isCorrect ? "Great job!" : "The correct answer was \(currentQuestion?.answer ?? 0)"),
               dismissButton: .default(Text("Next Question")) {
                   if questionsAnswered < 10 {
                       generateQuestion()
                   } else {
                       endGame()
                   }
               }
           )
       }
   }
   
   func generateQuestion() {
       let operations = ["+", "-", "*"]
       let operation = operations.randomElement()!
       let num1 = Int.random(in: 1...20)
       let num2 = Int.random(in: 1...20)
       
       var answer: Int
       var text: String
       
       switch operation {
       case "+":
           answer = num1 + num2
           text = "\(num1) + \(num2)"
       case "-":
           answer = num1 - num2
           text = "\(num1) - \(num2)"
       case "*":
           answer = num1 * num2
           text = "\(num1) × \(num2)"
       default:
           answer = 0
           text = ""
       }
       
       currentQuestion = MathQuestion(text: text, answer: answer)
       userAnswer = ""
       showingResult = false
   }
   
   func checkAnswer() {
       guard let question = currentQuestion, let userAnswerInt = Int(userAnswer) else { return }
       
       isCorrect = userAnswerInt == question.answer
       if isCorrect {
           score += 1
           UserManager.addPoints(5)
       }
       
       questionsAnswered += 1
       showingResult = true
   }
   
   func endGame() {
       UserManager.addPoints(score * 10)
       // Reset the game or show final score
       score = 0
       questionsAnswered = 0
       generateQuestion()
   }
}
struct MathQuestion {
   let text: String
   let answer: Int
}
struct WordScrambleView: View {
   @ObservedObject var UserManager: UserManager
   @State private var currentWord = ""
   @State private var scrambledWord = ""
   @State private var userGuess = ""
   @State private var score = 0
   @State private var wordsGuessed = 0
   @State private var showingResult = false
   @State private var isCorrect = false
   
   let words = ["biology", "chemistry", "physics", "math", "programming", "homework", "pencil", "computer", "eraser", "notebook"]
   
   var body: some View {
       VStack {
           Text("Word Scramble")
               .font(.largeTitle)
               .padding()
           
           Text("Score: \(score)")
               .font(.title)
           
           Text(scrambledWord)
               .font(.title)
               .padding()
           
           TextField("Your guess", text: $userGuess)
               .textFieldStyle(RoundedBorderTextFieldStyle())
               .padding()
           
           Button("Submit") {
               checkGuess()
           }
           .padding()
           .background(Color.purple)
           .foregroundColor(.white)
           .cornerRadius(10)
           
           if showingResult {
               Text(isCorrect ? "Correct!" : "Wrong!")
                   .font(.title)
                   .foregroundColor(isCorrect ? .green : .red)
                   .padding()
           }
       }
       .onAppear(perform: newWord)
       .alert(isPresented: $showingResult) {
           Alert(
               title: Text(isCorrect ? "Correct!" : "Wrong!"),
               message: Text(isCorrect ? "Great job!" : "The correct word was \(currentWord)"),
               dismissButton: .default(Text("Next Word")) {
                   if wordsGuessed < 10 {
                       newWord()
                   } else {
                       endGame()
                   }
               }
           )
       }
   }
   
   func newWord() {
       currentWord = words.randomElement() ?? "swift"
       scrambledWord = String(currentWord.shuffled())
       userGuess = ""
       showingResult = false
   }
   
   func checkGuess() {
       isCorrect = userGuess.lowercased() == currentWord
       if isCorrect {
           score += 1
           UserManager.addPoints(5)
       }
       
       wordsGuessed += 1
       showingResult = true
   }
   
   func endGame() {
       UserManager.addPoints(score * 10)
       // Reset the game or show final score
       score = 0
       wordsGuessed = 0
       newWord()
   }
}
struct QuizMasterView: View {
   @ObservedObject var UserManager: UserManager
   @State private var currentQuestion: QuizQuestion?
   @State private var score = 0
   @State private var questionsAnswered = 0
   @State private var showingResult = false
   @State private var selectedAnswer: String?
   
   let questions = [
       QuizQuestion(
           text: "What is the capital of France?",
           answers: ["London", "Berlin", "Paris", "Madrid"],
           correctAnswer: "Paris"
       ),
       QuizQuestion(
           text: "Which planet is known as the Red Planet?",
           answers: ["Mars", "Venus", "Jupiter", "Saturn"],
           correctAnswer: "Mars"
       ),
       QuizQuestion(
           text: "Who painted the Mona Lisa?",
           answers: ["Vincent van Gogh", "Leonardo da Vinci", "Pablo Picasso", "Claude Monet"],
           correctAnswer: "Leonardo da Vinci"
       ),
       QuizQuestion(
           text: "What is the largest ocean on Earth?",
           answers: ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean", "Pacific Ocean"],
           correctAnswer: "Pacific Ocean"
       ),
       QuizQuestion(
           text: "Which element has the chemical symbol 'O'?",
           answers: ["Gold", "Silver", "Oxygen", "Iron"],
           correctAnswer: "Oxygen"
       )
   ]
   
   var body: some View {
       VStack {
           Text("Quiz Master")
               .font(.largeTitle)
               .padding()
           
           Text("Score: \(score)")
               .font(.title)
           
           if let question = currentQuestion {
               Text(question.text)
                   .font(.title2)
                   .padding()
               
               ForEach(question.answers, id: \.self) { answer in
                   Button(action: {
                       selectedAnswer = answer
                   }) {
                       Text(answer)
                           .padding()
                           .frame(maxWidth: .infinity)
                           .background(selectedAnswer == answer ? Color.purple : Color.gray)
                           .foregroundColor(.white)
                           .cornerRadius(10)
                   }
                   .padding(.horizontal)
               }
               
               Button("Submit") {
                   checkAnswer()
               }
               .padding()
               .background(Color.green)
               .foregroundColor(.white)
               .cornerRadius(10)
               .disabled(selectedAnswer == nil)
           }
       }
       .onAppear(perform: newQuestion)
       .alert(isPresented: $showingResult) {
           Alert(
               title: Text(selectedAnswer == currentQuestion?.correctAnswer ? "Correct!" : "Wrong!"),
               message: Text("The correct answer was \(currentQuestion?.correctAnswer ?? "")"),
               dismissButton: .default(Text("Next Question")) {
                   if questionsAnswered < 5 {
                       newQuestion()
                   } else {
                       endGame()
                   }
               }
           )
       }
   }
   
   func newQuestion() {
       currentQuestion = questions.randomElement()
       selectedAnswer = nil
       showingResult = false
   }
   
   func checkAnswer() {
       guard let question = currentQuestion, let selected = selectedAnswer else { return }
       
       if selected == question.correctAnswer {
           score += 1
           UserManager.addPoints(10)
       }
       
       questionsAnswered += 1
       showingResult = true
   }
   
   func endGame() {
       UserManager.addPoints(score * 20)
       // Reset the game or show final score
       score = 0
       questionsAnswered = 0
       newQuestion()
   }
}
struct QuizQuestion {
   let text: String
   let answers: [String]
   let correctAnswer: String
}

struct SettingsView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var auth0Manager: Auth0Manager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Study Reminders", isOn: .constant(true))
                    Toggle("Progress Updates", isOn: .constant(false))
                }
                
                Section(header: Text("Account")) {
                    Button("Log Out") {
                        auth0Manager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct TaskListView: View {
    @Binding var tasks: [AppTask]
    @Binding var newTask: String
    @ObservedObject var userState: UserState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Tasks")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            HStack {
                TextField("Add a new task", text: $newTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            
            ForEach(tasks) { task in
                TaskRow(apptask: task, toggleAction: {
                    toggleTask(task)
                })
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    func addTask() {
        guard !newTask.isEmpty else { return }
        tasks.append(AppTask(text: newTask, completed: false))
        userState.addPoints(5)
        newTask = ""
    }
    
    func toggleTask(_ task: AppTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].completed.toggle()
            if tasks[index].completed {
                userState.addPoints(15)
            }
        }
    }
}

struct TimerCardView: View {
    @ObservedObject var userState: UserState
    @Binding var isTimerRunning: Bool
    @Binding var timeRemaining: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Timer")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Button(action: {
                if !isTimerRunning {
                    userState.addPoints(10) // Award points when starting the timer
                    isTimerRunning = true
                    timeRemaining = 25 * 60 // Set to 25 minutes
                }
            }) {
                Text(isTimerRunning ? "Focus Session in Progress" : "Start 25-min Focus Session")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
            }
            .disabled(isTimerRunning)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct AppTask: Identifiable {
    let id = UUID()
    var text: String
    var completed: Bool
}

struct Event: Identifiable {
    let id: UUID
    let title: String
    let date: Date
}

struct TaskRow: View {
    let apptask: AppTask
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: apptask.completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(apptask.completed ? .green : .gray)
            Text(apptask.text)
                .strikethrough(apptask.completed)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleAction()
        }
    }
}

struct EventFormView: View {
    @Binding var events: [Event]
    @Binding var isPresented: Bool
    @ObservedObject var userState: UserState
    @State private var eventTitle = ""
    @State private var eventDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Event Title", text: $eventTitle)
                DatePicker("Event Date", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Add New Event")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    let newEvent = Event(id: UUID(), title: eventTitle, date: eventDate)
                    events.append(newEvent)
                    userState.addPoints(10)
                    isPresented = false
                }
                .disabled(eventTitle.isEmpty)
            )
        }
    }
}

struct AssistantView: View {
    @Binding var isDarkMode: Bool
    @ObservedObject var userState: UserState
    @State private var query = ""
    @State private var chatHistory: [ChatMessage] = []
    @State private var isThinking = false
    @StateObject private var aiModel = GroqAIModel()

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(chatHistory) { message in
                            ChatBubble(message: message, isDarkMode: isDarkMode)
                        }
                    }
                    .padding()
                }
                
                if isThinking {
                    ProgressView("Thinking...")
                        .padding()
                }
                
                HStack {
                    TextField("Ask a question...", text: $query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        askAssistant(query)
                    }) {
                        Text("Ask")
                    }
                    .disabled(query.isEmpty)
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .background(Color(.systemBackground))
        }
    }
    
    func askAssistant(_ question: String) {
        let userMessage = ChatMessage(id: UUID(), content: question, isUser: true)
        chatHistory.append(userMessage)
        
        isThinking = true
        
        Task {
            do {
                let response = try await aiModel.sendMessage(question)
                DispatchQueue.main.async {
                    let assistantMessage = ChatMessage(id: UUID(), content: response, isUser: false)
                    chatHistory.append(assistantMessage)
                    isThinking = false
                    userState.addPoints(5)
                    query = ""
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = ChatMessage(id: UUID(), content: "Sorry, I couldn't process your request. Error: \(error.localizedDescription)", isUser: false)
                    chatHistory.append(errorMessage)
                    isThinking = false
                }
            }
        }
    }
}

class GroqAIModel: ObservableObject {
    private let apiKey: String
    private let endpoint: String
    
    init() {
        // Replace with your actual Groq Cloud API key
        self.apiKey = "YOUR_GROQ_API_KEY"
        self.endpoint = "https://api.groq.com/openai/v1/chat/completions"
    }
    
    func sendMessage(_ message: String) async throws -> String {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "mixtral-8x7b-32768",
            "messages": [
                ["role": "user", "content": message]
            ],
            "temperature": 0.7,
            "max_tokens": 1024
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GroqResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "I'm sorry, I couldn't generate a response."
    }
}

struct GroqResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}

struct ChatBubble: View {
    let message: ChatMessage
    let isDarkMode: Bool
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            Text(message.content)
                .padding(10)
                .background(message.isUser ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            if !message.isUser { Spacer() }
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
}
