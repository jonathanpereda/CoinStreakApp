//
//  ContentView.swift
//  CoinStreak IOS
//
//  Created by Jonathan Pereda on 10/3/25.
//

import SwiftUI

struct ContentView: View {
    
    @State private var streak = 0;
    @State private var curState = "";
    
    var body: some View {
        VStack {
            
            Text("Streak: \(streak)");
            Text("COIN: \(curState)");
            
            Button("Flip") {
                flipCoin()
            }
        }
        .padding()
    }
    
    func flipCoin() {
        let flip = Bool.random() ? "Heads" : "Tails"
        if flip == curState {
            streak += 1
        } else {
            streak = 1
        }
        curState = flip
    }
    
    
    
}

#Preview {
    ContentView()
}
