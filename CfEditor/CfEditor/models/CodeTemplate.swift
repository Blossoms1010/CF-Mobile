//
//  CodeTemplate.swift
//  CfEditor
//
//  Created by AI on 2025-10-10.
//

import Foundation

// MARK: - Programming Language
enum ProgrammingLanguage: String, CaseIterable, Identifiable, Codable {
    case cpp = "C++"
    case python = "Python"
    case java = "Java"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .cpp:
            return "cpp"
        case .python:
            return "py"
        case .java:
            return "java"
        }
    }
    
    var icon: String {
        switch self {
        case .cpp:
            return "chevron.left.forwardslash.chevron.right"
        case .python:
            return "p.square"
        case .java:
            return "j.square"
        }
    }
    
    var defaultTemplate: String {
        switch self {
        case .cpp:
            return """
#include <bits/stdc++.h>
using namespace std;

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    
    // Your code here
    
    return 0;
}
"""
        case .python:
            return """
def main():
    # Your code here
    pass

if __name__ == "__main__":
    main()
"""
        case .java:
            return """
import java.util.*;
import java.io.*;

public class Main {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        
        // Your code here
        
        sc.close();
    }
}
"""
        }
    }
}

// MARK: - Code Template Model
struct CodeTemplate: Codable, Identifiable {
    var id = UUID()
    var language: ProgrammingLanguage
    var code: String
    
    init(language: ProgrammingLanguage, code: String? = nil) {
        self.language = language
        self.code = code ?? language.defaultTemplate
    }
}

// MARK: - Code Template Manager
class CodeTemplateManager: ObservableObject {
    static let shared = CodeTemplateManager()
    
    @Published var templates: [ProgrammingLanguage: String] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let templatesKey = "codeTemplates"
    
    private init() {
        loadTemplates()
    }
    
    func loadTemplates() {
        if let data = userDefaults.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([ProgrammingLanguage: String].self, from: data) {
            templates = decoded
        } else {
            // Initialize with default templates
            for language in ProgrammingLanguage.allCases {
                templates[language] = language.defaultTemplate
            }
        }
    }
    
    func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            userDefaults.set(encoded, forKey: templatesKey)
        }
    }
    
    func updateTemplate(for language: ProgrammingLanguage, code: String) {
        templates[language] = code
        saveTemplates()
    }
    
    func getTemplate(for language: ProgrammingLanguage) -> String {
        return templates[language] ?? language.defaultTemplate
    }
    
    func resetTemplate(for language: ProgrammingLanguage) {
        templates[language] = language.defaultTemplate
        saveTemplates()
    }
}

