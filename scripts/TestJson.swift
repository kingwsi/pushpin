import Foundation

let inputs = [
    // This represents a string containing literal backslashes
    // Content: [{"activityId":"..."}]  <-- This works direct
    // Content: [{\"activityId\":\"...\"}] <-- This contains backslashes
    #"[{\"activityId\":\"88f2564500714520b1f1a99c75da0001\",\"actualPrice\":40,\"addPrice\":10.0,\"dep\":\"2025-12-14\"}]"#,
    #"[{\"a\":1}]"#
]

func isJSON(_ content: String) -> Bool {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    print("Testing (Raw): \(trimmed)")
    
    // 1. Direct
    if let data = trimmed.data(using: .utf8) {
        if (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
             print("  -> Direct: true")
             return true
        } else {
             print("  -> Direct: false")
        }
    }

    // 2. Unescape Quoted
    if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
         print("  -> Checking Quoted")
         if let data = trimmed.data(using: .utf8),
            let unescaped = try? JSONSerialization.jsonObject(with: data, options: []) as? String {
             let unescapedTrimmed = unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
             if let innerData = unescapedTrimmed.data(using: .utf8),
                (try? JSONSerialization.jsonObject(with: innerData, options: [])) != nil {
                 print("  -> Quoted Unescape: true")
                 return true
             }
         }
    }

    // 3. Raw Escaped
    let wrapped = "\"\(trimmed)\""
    print("  -> Wrapped: \(wrapped)")
    if let data = wrapped.data(using: .utf8) {
        do {
            // Note: asking JSONSerialization to parse " [{\"a\":1}] "
            // It expects standard escapes. \" is ".
            // So result is string: [{"a":1}]
            // String is a fragment!
           if let unescaped = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String {
                print("  -> Unescaped: \(unescaped)")
                let unescapedTrimmed = unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
                if let innerData = unescapedTrimmed.data(using: .utf8),
                   (try? JSONSerialization.jsonObject(with: innerData, options: [])) != nil {
                    print("  -> Raw Unescape: true")
                    return true
                }
           }
        } catch {
            print("  -> Raw Unescape Error: \(error)")
        }
    }

    return false
}

for input in inputs {
    print("Result: \(isJSON(input))")
    print("---")
}
