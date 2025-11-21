import Foundation
import AppKit

class CursorPaster {
    private static let pasteCompletionDelay: TimeInterval = 0.3
    
    static func pasteAtCursor(_ text: String) {
        print("🔍 DEBUG: pasteAtCursor called with text: '\(text.prefix(50))...'")
        
        guard AXIsProcessTrusted() else {
            print("❌ DEBUG: AXIsProcessTrusted() returned false - accessibility permission denied")
            return
        }
        print("✅ DEBUG: Accessibility permission confirmed")
        
        let pasteboard = NSPasteboard.general
        
        var savedContents: [(NSPasteboard.PasteboardType, Data)] = []
        
        let preserveTranscript = UserDefaults.standard.bool(forKey: "preserveTranscriptInClipboard")
        
        // Only save clipboard contents if we plan to restore them
        if !preserveTranscript {
            let currentItems = pasteboard.pasteboardItems ?? []
            print("🔍 DEBUG: Saving \(currentItems.count) clipboard items")
            
            for item in currentItems {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        savedContents.append((type, data))
                    }
                }
            }
        }
        
        pasteboard.clearContents()
        let clipboardSuccess = pasteboard.setString(text, forType: .string)
        print("🔍 DEBUG: Clipboard set success: \(clipboardSuccess)")

        if !preserveTranscript {
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        }

        let useAppleScript = UserDefaults.standard.bool(forKey: "UseAppleScriptPaste")
        print("🔍 DEBUG: Using AppleScript paste: \(useAppleScript)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if UserDefaults.standard.bool(forKey: "UseAppleScriptPaste") {
                let appleScriptResult = pasteUsingAppleScript()
                print("🔍 DEBUG: AppleScript paste result: \(appleScriptResult)")
            } else {
                print("🔍 DEBUG: Using Command+V paste method")
                pasteUsingCommandV()
            }
        }

        if !preserveTranscript {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if !savedContents.isEmpty {
                    pasteboard.clearContents()
                    for (type, data) in savedContents {
                        pasteboard.setData(data, forType: type)
                    }
                    print("✅ DEBUG: Clipboard restored")
                }
            }
        }
    }
    
    private static func pasteUsingAppleScript() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }
    
    private static func pasteUsingCommandV() {
        print("🔍 DEBUG: Creating CGEvent source...")
        let source = CGEventSource(stateID: .hidSystemState)
        
        print("🔍 DEBUG: Creating keyboard events...")
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        guard cmdDown != nil, vDown != nil, vUp != nil, cmdUp != nil else {
            print("❌ DEBUG: Failed to create one or more CGEvents")
            return
        }
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        print("🔍 DEBUG: Posting keyboard events...")
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        print("✅ DEBUG: Command+V events posted")
    }
}
