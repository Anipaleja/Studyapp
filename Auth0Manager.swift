import Auth0
import SwiftUI

class Auth0Manager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userProfile: [String: Any]? = nil
    
    private let clientId: String
    private let domain: String
    private let callbackURL: URL
    
    init() {
        // Replace these values with your actual Auth0 credentials
        self.clientId = "o0bjrO7FYqtugRFgoFDSZEdQ9R1wXvSR"
        self.domain = "dev-7am0z2r53ujmc2ph.us.auth0.com"
        self.callbackURL = URL(string: "com.yellowbranch.Study-://dev-7am0z2r53ujmc2ph.us.auth0.com/ios/com.yellowbranch.Study-/callback")!
    }
    
    func login() {
        Auth0
            .webAuth(clientId: clientId, domain: domain)
            .scope("openid profile email")
            .audience("https://\(domain)/userinfo")
            .redirectURL(callbackURL)
            .start { result in
                switch result {
                case .success(let credentials):
                    print("Login successful")
                    self.isAuthenticated = true
                    self.fetchUserProfile(accessToken: credentials.accessToken)
                case .failure(let error):
                    print("Login failed: \(error)")
                }
            }
    }
    
    private func fetchUserProfile(accessToken: String) {
        Auth0
            .authentication(clientId: clientId, domain: domain)
            .userInfo(withAccessToken: accessToken)
            .start { result in
                switch result {
                case .success(let profile):
                    DispatchQueue.main.async {
                        self.userProfile = [
                            "sub": profile.sub,
                            "name": profile.name ?? "",
                            "given_name": profile.givenName ?? "",
                            "family_name": profile.familyName ?? "",
                            "email": profile.email ?? "",
                            "picture": profile.picture ?? ""
                        ]
                    }
                case .failure(let error):
                    print("Failed to fetch profile: \(error)")
                }
            }
    }
    
    func logout() {
        Auth0
            .webAuth()
            .clearSession { result in
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.userProfile = nil
                }
            }
    }
}
