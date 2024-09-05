//
//  main.swift
//  myLisp
//
//  Created by Francisco Gorina Vanrell on 30/7/24.
//
import Darwin
import Foundation

func isCompleted(s : String) -> Bool {
    let open = s.ranges(of: "(").count
    let close = s.ranges(of: ")").count
    return open == close
}


/// Local environment for locally defined functions

/// Globals and cia
///

let version = "0.0.1"
var buffer : String = ""

// Load standard functions written in LISP
Lisp.shared.initContext()
Lisp.shared.createClasses()

for ff in swFunctions {
    //fputs("Processing \n\(ff)", stderr)
    let _ = Lisp.shared.eval(s: ff)
    
}
fputs("myLisp v. \(version)\n", stderr)
fputs("Current directory is \(FileManager.default.currentDirectoryPath)\n", stderr)



// Get parameters

let params = CommandLine.arguments

params.forEach { p in
    fputs("\(p)\n", stderr)
}

    let path = FileManager.default.currentDirectoryPath + "/init.lisp"
    do {
        let data = try String(contentsOfFile: path, encoding: .utf8)
        let myStrings = data.components(separatedBy: .newlines)
        Lisp.shared.process(lines: myStrings)
        fputs("Loaded \(path)\n", stderr)
    } catch {
        fputs(error.localizedDescription, stderr)
    }

for param in params.dropFirst(){
    let path = FileManager.default.currentDirectoryPath + "/" + param
    
    do {
        let data = try String(contentsOfFile: path, encoding: .utf8)
        let myStrings = data.components(separatedBy: .newlines)
        Lisp.shared.process(lines: myStrings)
        fputs("Loaded \(path)\n", stderr)
    } catch {
        print(error)
    }
}
fputs("\n: ", stderr)
while(true){
    if let s = readLine(){
        if(s.replacingOccurrences(of: " ", with: "")) == "(quit)"{
            break
        }else if(s.replacingOccurrences(of: " ", with: "")) == "(clear)"{
            buffer = ""
        }else if s.hasPrefix(";"){
            
            // It is a comment
            
        }else{
            buffer += s
            
            if isCompleted(s: buffer) && !buffer.isEmpty{
                let answer = Lisp.shared.eval(s: buffer)!
                fputs("\(answer.prettyPrint(prefix: "   "))\n: ", stderr)
                buffer = ""
            }
        }
    }
}

