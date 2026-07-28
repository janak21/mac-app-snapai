import Foundation

struct PromptTemplate: Identifiable {
    let id: String
    let title: String
    let category: String
    let prompt: String
    let style: String?
    let summary: String
}

enum PromptTemplateCatalog {
    static let all: [PromptTemplate] = [
        PromptTemplate(
            id: "weather",
            title: "Weather",
            category: "App concepts",
            prompt: "weather app with simple sun and cloud shapes",
            style: "minimalism",
            summary: "Clear, friendly, and easy to recognize at a glance."
        ),
        PromptTemplate(
            id: "finance",
            title: "Secure finance",
            category: "App concepts",
            prompt: "secure finance app with a bold shield and subtle checkmark",
            style: "material",
            summary: "Trustworthy geometry with restrained depth."
        ),
        PromptTemplate(
            id: "music",
            title: "Music",
            category: "App concepts",
            prompt: "music player app with abstract sound waves and simple shapes",
            style: "gradient",
            summary: "A lively starting point for audio and media products."
        ),
        PromptTemplate(
            id: "notes",
            title: "Notes",
            category: "App concepts",
            prompt: "note-taking app with a pen and paper, minimal and friendly",
            style: "clay",
            summary: "Soft, approachable, and easy to customize."
        ),
        PromptTemplate(
            id: "camera",
            title: "Camera",
            category: "App concepts",
            prompt: "camera app with a lens built from clean concentric circles",
            style: "geometric",
            summary: "A precise base for photography and visual tools."
        ),
        PromptTemplate(
            id: "minimalism",
            title: "Minimalism",
            category: "Visual styles",
            prompt: "a single, unmistakable symbol for a mobile app",
            style: "minimalism",
            summary: "One dominant symbol, few colors, no decorative effects."
        ),
        PromptTemplate(
            id: "glassy",
            title: "Glassy",
            category: "Visual styles",
            prompt: "a floating symbol for a modern app",
            style: "glassy",
            summary: "Translucent layers, soft blur, and controlled reflections."
        ),
        PromptTemplate(
            id: "pixel",
            title: "Pixel",
            category: "Visual styles",
            prompt: "a retro game or utility app symbol",
            style: "pixel",
            summary: "Hard-edged 8-bit clarity on a strict pixel grid."
        ),
        PromptTemplate(
            id: "kawaii",
            title: "Kawaii",
            category: "Visual styles",
            prompt: "a friendly character or object representing an app",
            style: "kawaii",
            summary: "Friendly chibi proportions, pastel color, and expressive warmth."
        ),
        PromptTemplate(
            id: "holographic",
            title: "Holographic",
            category: "Visual styles",
            prompt: "a futuristic symbol for a creative app",
            style: "holographic",
            summary: "Iridescent color shifts with dynamic light response."
        )
    ]

    static var categories: [String] {
        ["App concepts", "Visual styles"]
    }
}
