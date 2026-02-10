//
//  BrokeBreakerWidgetLiveActivity.swift
//  BrokeBreakerWidget
//
//  Created by кαяєи ʝαи∂ιяα💖 on 10/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BrokeBreakerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BrokeBreakerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrokeBreakerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BrokeBreakerWidgetAttributes {
    fileprivate static var preview: BrokeBreakerWidgetAttributes {
        BrokeBreakerWidgetAttributes(name: "World")
    }
}

extension BrokeBreakerWidgetAttributes.ContentState {
    fileprivate static var smiley: BrokeBreakerWidgetAttributes.ContentState {
        BrokeBreakerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BrokeBreakerWidgetAttributes.ContentState {
         BrokeBreakerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BrokeBreakerWidgetAttributes.preview) {
   BrokeBreakerWidgetLiveActivity()
} contentStates: {
    BrokeBreakerWidgetAttributes.ContentState.smiley
    BrokeBreakerWidgetAttributes.ContentState.starEyes
}
